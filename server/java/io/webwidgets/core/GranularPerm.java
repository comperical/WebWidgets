
package io.webwidgets.core; 

import java.io.*; 
import java.sql.*; 
import java.util.*; 

import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.CoreDb.QueryCollector;

import io.webwidgets.core.WidgetOrg.*;


// Logic for Granular permissions. Key concepts:
// System-verified auth_owner column. Guaranteed to be the actual owner of the record
// JSON data in group allow column, specified by user code, with help of nice utility methods
// This is just a { group : read / write } data structure
// Group Allow column gets transferred into an auxiliary table, for fast SQL queries
// This is necessary in large user scenarios to avoid full table scans and JSON parsing
// Account-user global group table, listing out username :: group memberships
// Groups are just strings; the system is not going to be persnickety about checking the group names
public class GranularPerm
{
    public static final String AUX_GROUP_PREFIX = "__aux_group";

    public static final String GROUP_INFO_TABLE = "group_info";


    public static List<String> getGroupInfoCreate()
    {
        return Arrays.asList(
            String.format("CREATE TABLE %s (id int, user_name varchar(100), group_name varchar(100), primary key(id))", GROUP_INFO_TABLE),
            String.format("CREATE INDEX __user_group_lookup ON %s (user_name)", GROUP_INFO_TABLE)
        );
    }


    // Name of the aux group table, derived from the main table.
    public static String getAuxGroupTable(String maintable)
    {
        return String.format("%s_%s", AUX_GROUP_PREFIX, maintable);
    }


    // Convert perminfo data, from group_allow field, into standard form of Map<String, Boolean>
    // Is this really necessary?
    @SuppressWarnings("unchecked")
    static Map<String, Boolean> convert2GroupMap(JSONObject perminfo)
    {
        return Util.map2map(perminfo.keySet(), k -> k.toString(), k -> perminfo.get(k).equals("write"));
    }

    // Full rebuild of the aux group table
    // All data in the aux group is derived from the group allow column in the main table,
    // so doing this is guaranteed not to destroy any data
    static void rebuildAuxGroupTable(WidgetItem dbitem, String maintable)
    {
        Set<String> tableset = dbitem.getDbTableNameSet();
        Util.massert(tableset.contains(maintable),
            "Main table %s not found in table list for %s, options are %s", maintable, dbitem, tableset);

        String auxtable = getAuxGroupTable(maintable);

        var droppor = "DROP TABLE IF EXISTS " + auxtable;

        var creator = "CREATE TABLE " + auxtable +
                    "(record_id int, group_name varchar(20), can_write int, PRIMARY KEY(record_id, group_name))";

        var indexor = String.format(
            "CREATE INDEX __aux_index_%s ON %s(group_name)", maintable, auxtable);

        List<String> commlist = Util.listify(droppor, creator, indexor);

        for(var comm : commlist)
        {
            CoreDb.execSqlUpdate(comm, dbitem);
        }

        int numrec = fullInsertGroupAllow(dbitem, maintable);
        Util.pf("Updated Aux Table for %d main-table records in %s::%s\n", numrec, dbitem, maintable);

    }

    static Map<Integer, Map<String, Boolean>> parseGroupAllowData(Collection<ArgMap> itemlist) throws ParseException
    {
        Map<Integer, Map<String, Boolean>> result = Util.treemap();
        JSONParser myparser = new JSONParser();

        for(ArgMap amap : itemlist)
        {
            JSONObject perminfo = Util.cast(myparser.parse(amap.getStr(CoreUtil.GROUP_ALLOW_COLUMN)));
            int recordid = amap.getInt(CoreUtil.STANDARD_ID_COLUMN_NAME);
            var groupmap = GranularPerm.convert2GroupMap(perminfo);
            result.put(recordid, groupmap);
        }

        return result;
    }

    static Map<String, Boolean> parseSingleGroupAllow(String groupstr) throws ParseException
    {
        JSONObject perminfo = Util.cast((new JSONParser()).parse(groupstr));
        return GranularPerm.convert2GroupMap(perminfo);
    }


    // Full insert of all group allow data into the aux group table
    // This is called after we blow away or rebuild the aux group
    static int fullInsertGroupAllow(WidgetItem dbitem, String maintable)
    {
        QueryCollector qcol = CoreUtil.fullTableQuery(dbitem, maintable);
        Map<Integer, Map<String, Boolean>> groupallow;


        // TODO: there is a big issue here, which is: what do you do on a full insert if the JSON
        // is improperly formatted?
        try {
            groupallow = parseGroupAllowData(qcol.recList());
        } catch (ParseException pex) {
            throw new RuntimeException("Error in JSON parsing in Group Allow column", pex);
        }


        Util.foreach(groupallow.entrySet(),
            entry -> transferGroupAllowData(dbitem, maintable, entry.getKey(), entry.getValue())
        );

        return qcol.getNumRec();
    }

    static boolean testModeTransferGroupAllow(WidgetItem dbitem, String coretable, ArgMap payload)
    {
        if(!dbitem.theOwner.toString().equals("dburfoot"))
            { return false; }

        if(!dbitem.theName.equals("systest"))
            { return false; }

        if(!coretable.startsWith("gran_test"))
            { return false; }

        try {
            transferGroupAllowData(dbitem, coretable, payload);
        } catch (ParseException pex) {
            throw new RuntimeException(pex);
        }

        return true;
    }




    // This method shunts the GROUP_ALLOW data, specified in JSON in the given payload,
    // into the aux table
    private static void transferGroupAllowData(WidgetItem dbitem, String coretable, ArgMap payload) throws ParseException
    {
        var groupmap = parseGroupAllowData(Util.listify(payload));
        int recordid = groupmap.keySet().iterator().next();
        transferGroupAllowData(dbitem, coretable, recordid, groupmap.get(recordid));
    }


    // Inserts the group allow data into the aux table, for a specific record
    // This deletes all data for the record and recreates it
    static void transferGroupAllowData(WidgetItem dbitem, String coretable, int recordid, Map<String, Boolean> groupallow)
    {
        String auxtable = getAuxGroupTable(coretable);

        try (Connection conn = dbitem.createConnection()) {

            conn.setAutoCommit(false);

            Statement cleanup = conn.createStatement();
            cleanup.execute(String.format("DELETE FROM %s WHERE record_id = %d", auxtable, recordid));

            PreparedStatement pstmt = conn.prepareStatement(
                String.format("INSERT INTO %s (record_id, group_name, can_write) VALUES (?, ?, ?)", auxtable));

            for(String g : groupallow.keySet())
            {
                pstmt.setInt(1, recordid);
                pstmt.setString(2, g);
                pstmt.setInt(3, groupallow.get(g) ? 1 : 0);
                pstmt.addBatch();
            }

            pstmt.executeBatch();
            conn.commit();
        
        } catch (Exception ex) {
            throw new RuntimeException(ex);
        }
    }



    // Checks for errors in parsing the JSON data for the GROUP ALLOW column
    static Optional<String> checkGroupAllowJsonError(LiteTableInfo table, ArgMap innmap)
    {
        if(table.hasGranularPerm() && LiteTableInfo.isUpsertAjaxOp(innmap))
        {
            if(!innmap.containsKey(CoreUtil.GROUP_ALLOW_COLUMN))
            {
                String mssg = String.format(
                    "Attempting to update a table with Granular Permissions, but missing the %s column", CoreUtil.GROUP_ALLOW_COLUMN);

                return Optional.of(mssg);
            }


            String groupstr = innmap.getStr(CoreUtil.GROUP_ALLOW_COLUMN);
            if(groupstr == null || groupstr.isEmpty())
            {
                return Optional.empty();
            }

            JSONObject jsonob;

            try {

                // This parser is NOT thread-safe. So there's not much we can do that's better than
                // just creating a new one here.
                jsonob = Util.cast(new JSONParser().parse(groupstr));
            } catch (ParseException pex) {

                String mssg = String.format(
                    "Error parsing JSON data for %s column. This column must be valid JSON, you entered %s",
                    CoreUtil.GROUP_ALLOW_COLUMN, groupstr);

                return Optional.of(mssg);
            }

            try {
                var perminfo = convert2GroupMap(jsonob);

            } catch (Exception ex) {

                String mssg = String.format(
                    "Error converting JSON data to group permission map for %s column. " + 
                    " Groups (keys) must be alphanumeric strings, values must be 'read' or 'write', you entered %s, " + 
                    " Exception message is %s",
                    CoreUtil.GROUP_ALLOW_COLUMN, jsonob, ex.getMessage());

                return Optional.of(mssg);
            }
        }

        return Optional.empty();

    }


    // Check that the given user has granular write permissions to the record designated by the payload,
    // for the given LTI
    // If NO ERROR, respond with a empty
    // Otherwise, respond with an error code that can be shown to the user;
    // calling code should block the update
    // The main thing is to check that the user has write permissions as specified in the GROUP ALLOW
    // Note that here we don't need to use the aux table
    // The above method about checking JSON should be called before this; here we assume that the JSON is kosher
    static Optional<String> checkGranularWritePerm(LiteTableInfo table, Optional<WidgetUser> user, ArgMap innmap)
    {
        if(!table.hasGranularPerm())
        {
            return Optional.empty();
        }

        if(!user.isPresent())
        {
            return Optional.of("This table has granular permissions; user must be logged in to update");
        }

        // TODO: implementing this for testing, not sure if this is how I actually want to do it
        if(user.get().isAdmin())
        {
            return Optional.empty();
        }

        // These are the groups the user is a member of IN THIS SPACE
        Set<String> usergroup = user.get().lookupGroupSet4Db(table.dbTabPair._1);

        // For both upsert and delete, we need to check that the logged-in-user has update rights for the record
        // As of v1, this just means "is this the owner?"
        int recordid = innmap.getInt(CoreUtil.STANDARD_ID_COLUMN_NAME);

        // This is a fast lookup, but this does imply that fine-grained permission tables have
        // worse performance than normal tables
        // Note that if the current is not present, it's a create, so we're okay
        Optional<ArgMap> current = table.lookupRecordById(recordid);

        // Note: if it's a delete, and there's no current, there's nothing else to do, since a delete is a no-op
        if(current.isPresent())
        {
            boolean okaywrite = recordHasWriteGroup(usergroup, current.get());

            if(!okaywrite)
            {
                String mssg = String.format("User %s does not have access to record, groups are %s", user.get(), usergroup);
                return Optional.of(mssg);
            }
        }

        // This is a more nit-picky check: the write perms in the PAYLOAD must also allow the user to write
        // In other words, a user cannot voluntarily give up their own write permissions, to avoid "orphaning"
        if(LiteTableInfo.isUpsertAjaxOp(innmap))
        {
            boolean okaywrite = recordHasWriteGroup(usergroup, innmap);

            if(!okaywrite)
            {
                String groupallow = innmap.getStr(CoreUtil.GROUP_ALLOW_COLUMN);
                String mssg = String.format(
                    "Orphan record error: this record would be unwriteable by the user %s after creation. Group allow data is %s",
                    user.get(), groupallow
                );
                return Optional.of(mssg);
            }
        }

        return Optional.empty();
    }



    private static boolean recordHasWriteGroup(Set<String> usergroup, ArgMap item)
    {
        String allowstr = item.getStr(CoreUtil.GROUP_ALLOW_COLUMN);
        var perminfo = convert2GroupMap(parse2Object(allowstr));


        // Number of groups that grant access
        int okaygroup = Util.countPred(usergroup, grp -> perminfo.getOrDefault(grp, false));

        return okaygroup > 0;
    }

    private static JSONObject parse2Object(String input)
    {
        try { return Util.cast(new JSONParser().parse(input)); }
        catch (ParseException pex) { throw new RuntimeException(pex); }

    }


    // Ensure that every table with a GROUP_ALLOW has a corresponding aux role table
    // if a table with granular permissions is present, ensure that an aux-role table is created
    // if an auxrole table is present with no corresponding maintable, drop it
    static String rectifyAuxRoleSetup(WidgetItem dbitem)
    {
        String logmessage = "";

        Set<String> foundaux = Util.treeset();

        // true = get all tables
        Set<String> alltable = CoreUtil.getLiteTableNameSet(dbitem, true);

        for(var main : dbitem.getDbTableNameSet())
        {
            var LTI = new LiteTableInfo(dbitem, main);
            LTI.runSetupQuery();

            if(LTI.hasGranularPerm())
            {
                var auxname = getAuxGroupTable(main);
                if(alltable.contains(auxname))
                {
                    foundaux.add(auxname);
                    continue;
                }

                rebuildAuxGroupTable(dbitem, main);
                logmessage += String.format("Created aux role table %s for main table %s\n", auxname, main);
            }
        }

        // Now we drop aux tables that are no longer necessary
        {
            List<String> badaux = Util.filter2list(alltable,
                probe -> probe.startsWith(AUX_GROUP_PREFIX) && !foundaux.contains(probe));

            for(var bad : badaux)
            {
                String dropper = String.format("DROP TABLE %s", bad);
                CoreDb.execSqlUpdate(dropper, dbitem);
                logmessage += String.format("Dropped unnecessary AUX GROUP table %s\n", bad);
            }
        }

        return logmessage;
    }


    // This method and the one below do the same thing, just from different data sources
    // These are public for testing
    public static Map<Integer, Map<String, Boolean>> slowReadAuxRoleData(WidgetItem dbitem, String maintable)
    {
        String auxtable = getAuxGroupTable(maintable);
        Util.massert(CoreUtil.getLiteTableNameSet(dbitem, true).contains(auxtable),
            "DB %s is missing aux table %s for main table %s",
            dbitem, auxtable, maintable
        );


        QueryCollector qcol = QueryCollector.buildAndRun("SELECT * FROM " + auxtable, dbitem);
        Map<Integer, Map<String, Boolean>> result = Util.treemap();

        for(var amap : qcol.recList())
        {
            String groupname = amap.getStr("group_name");
            int recordid = amap.getInt("record_id");
            int canwrite = amap.getInt("can_write");

            Util.setdefault(result, recordid, Util.treemap());
            result.get(recordid).put(groupname, canwrite == 1);
        }

        return result;
    }


    // Public for testing
    public static Map<Integer, Map<String, Boolean>> slowReadGroupAllowData(WidgetItem dbitem, String maintable)
    {
        QueryCollector qcol = QueryCollector.buildAndRun("SELECT * FROM " + maintable, dbitem);
        Map<Integer, Map<String, Boolean>> result = Util.treemap();

        for(var amap : qcol.recList())
        {
            int recordid = amap.getInt(CoreUtil.STANDARD_ID_COLUMN_NAME);
            JSONObject obdata = parse2Object(amap.getStr(CoreUtil.GROUP_ALLOW_COLUMN));
            var perminfo = convert2GroupMap(obdata);

            Util.setdefault(result, recordid, Util.treemap());
            Util.foreach(perminfo.entrySet(), pr -> result.get(recordid).put(pr.getKey(), pr.getValue()));
        }

        return result;
    }
}