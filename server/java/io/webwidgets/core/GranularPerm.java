
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


// Logic for Granular permissions. Key concepts:
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
    // this method is called as part of the update process in the main Callback,
    // to ensure that the Group Allow JSON is properly formed
    @SuppressWarnings("unchecked")
    static Map<String, Boolean> convert2GroupMap(JSONObject perminfo)
    {
        Map<String, Boolean> result = Util.treemap();

        for(Object k : perminfo.keySet())
        {
            Object s = perminfo.get(k);

            boolean isread = "read".equals(s);
            boolean iswrite = "write".equals(s);

            Util.massert(isread || iswrite, "Invalid value %s for group allow, attached to key %s", s, k);
            result.put(k.toString(), iswrite);
        }

        return result;
    }

    public static List<String> getAuxTableRebuildSql(String maintable)
    {
        String auxtable = getAuxGroupTable(maintable);

        var droppor = "DROP TABLE IF EXISTS " + auxtable;

        var creator = String.format(
                "CREATE TABLE %s ( " +
                "record_id  INTEGER NOT NULL, " +
                "group_name TEXT    NOT NULL, " +
                "can_write  INTEGER NOT NULL, " +
                "PRIMARY KEY (record_id, group_name), " +
                "FOREIGN KEY (record_id) REFERENCES %s(id) ON DELETE CASCADE" +
                ")",
                auxtable,               // first %s
                maintable               // second %s
        );

        // NB: using the record_id here is a performance upgrade. We query on just the group_name,
        // but including the record_id in the index means SQLite doesn't have to actually go to the table
        // and read the record!
        var indexor = String.format(
                "CREATE INDEX __aux_index_%s ON %s (group_name, record_id)",
                maintable,  // first %s
                auxtable    // second %s
        );

        return Arrays.asList(droppor, creator, indexor);
    }


    // Full rebuild of the aux group table
    // All data in the aux group is derived from the group allow column in the main table,
    // so doing this is guaranteed not to destroy any data
    public static void rebuildAuxGroupTable(WidgetItem dbitem, String maintable)
    {
        Set<String> tableset = dbitem.getDbTableNameSet();
        Util.massert(tableset.contains(maintable),
            "Main table %s not found in table list for %s, options are %s", maintable, dbitem, tableset);

        List<String> commlist = getAuxTableRebuildSql(maintable);

        for(var comm : commlist)
        {
            CoreDb.execSqlUpdate(comm, dbitem);
        }

        int numrec = fullInsertGroupAllow(dbitem, maintable);
        Util.pf("Updated Aux Table for %d main-table records in %s::%s\n", numrec, dbitem, maintable);
    }


    // Bulk version of method below. Keys of map are record IDs.
    static Map<Integer, Map<String, Boolean>> parseGroupAllowData(Collection<ArgMap> itemlist)
    {
        JSONParser parser = new JSONParser();

        return Util.map2map(
            itemlist,
            amap -> amap.getInt(CoreUtil.STANDARD_ID_COLUMN_NAME),
            amap -> parseGroupAllowData(amap, parser)
        );
    }


    // Pull the group allow data out of the JSON in the given record
    // If you are running this multiple times, it's better to use the bulk operation above, reuse the parser
    static Map<String, Boolean> parseGroupAllowData(ArgMap item, JSONParser parser)
    {
        try {
            JSONObject perminfo = Util.cast(parser.parse(item.getStr(CoreUtil.GROUP_ALLOW_COLUMN)));
            return convert2GroupMap(perminfo);
        } catch (ParseException pex) {
            throw new RuntimeException(pex);
        }
    }

    // Full insert of all group allow data into the aux group table
    // This is called after we blow away or rebuild the aux group
    static int fullInsertGroupAllow(WidgetItem dbitem, String maintable)
    {
        QueryCollector qcol = CoreUtil.fullTableQuery(dbitem, maintable);
        Map<Integer, Map<String, Boolean>> groupallow;


        // TODO: there is a big issue here, which is: what do you do on a full insert if the JSON
        // is improperly formatted?
        groupallow = parseGroupAllowData(qcol.recList());

        shuntGroupAllowSub(dbitem, maintable, groupallow);

        return qcol.getNumRec();
    }




    // Boilerplate
    private static Map<Integer, Map<String, Boolean>> buildWrapMap(int recordid, Map<String, Boolean> groupallow)
    {
        Map<Integer, Map<String, Boolean>> wrapmap = Util.map2map(Util.listify(recordid), rid -> rid, rid -> groupallow);
        return wrapmap;
    }


    // This method shunts the GROUP_ALLOW data, specified in JSON in the given payload,
    // into the aux table
    static boolean shuntGroupAllowData(LiteTableInfo LTI, ArgMap payload)
    {
        if(!LTI.hasGranularPerm())
            { return false; }

        var groupmap = parseGroupAllowData(payload, new JSONParser());
        int recordid = payload.getInt(CoreUtil.STANDARD_ID_COLUMN_NAME);

        shuntGroupAllowSub(LTI.dbTabPair._1, LTI.dbTabPair._2, buildWrapMap(recordid, groupmap));
        return true;
    }


    // Inserts the group allow data into the aux table, for a specific record
    // This deletes all data for the record and recreates it
    private static void shuntGroupAllowSub(WidgetItem dbitem, String coretable, Map<Integer, Map<String, Boolean>> fullAllowMap)
    {
        String auxtable = getAuxGroupTable(coretable);

        try (Connection conn = dbitem.createConnection()) {

            conn.setAutoCommit(false);

            var cleanup = conn.prepareStatement(
                String.format("DELETE FROM %s WHERE record_id = ?", auxtable));

            var insert = conn.prepareStatement(
                String.format("INSERT INTO %s (record_id, group_name, can_write) VALUES (?, ?, ?)", auxtable));

            for (var entry : fullAllowMap.entrySet()) {
                int recordid = entry.getKey();
                Map<String, Boolean> groupallow = entry.getValue();

                // Clear old entries
                cleanup.setInt(1, recordid);
                cleanup.executeUpdate();

                // Add new entries
                for (Map.Entry<String, Boolean> gentry : groupallow.entrySet()) {
                    insert.setInt(1, recordid);
                    insert.setString(2, gentry.getKey());
                    insert.setInt(3, gentry.getValue() ? 1 : 0);
                    insert.addBatch();
                }
            }

            insert.executeBatch();
            conn.commit();

        } catch (Exception ex) {
            throw new RuntimeException(ex);
        }

    }



    // Checks for errors in parsing the JSON data for the GROUP ALLOW column
    static Optional<String> checkGroupAllowJsonError(LiteTableInfo table, ArgMap innmap)
    {
        // Obviously, if it's not a granular perm table, there's no problem
        // Less obviously, if it's a Delete operation (as opposed to upsert),
        // there's no problem, since the payload won't have the record
        if(!table.hasGranularPerm() || !LiteTableInfo.isUpsertAjaxOp(innmap))
            { return Optional.empty(); }


        if(!innmap.containsKey(CoreUtil.GROUP_ALLOW_COLUMN))
        {
            String mssg = String.format(
                "Attempting to update a table with Granular Permissions, but missing the %s column", CoreUtil.GROUP_ALLOW_COLUMN);

            return Optional.of(mssg);
        }

        String groupstr = innmap.getStr(CoreUtil.GROUP_ALLOW_COLUMN);
        if(groupstr == null)
        {
            String mssg = String.format("Error parsing JSON data for %s column. " + 
                "You entered a null value for the column, it must be valid JSON, use empty hash {} if appropriate",
                CoreUtil.GROUP_ALLOW_COLUMN);
            return Optional.of(mssg);
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

        // Looks good!
        return Optional.empty();
    }


    // Check that the given user has granular write permissions to the record designated by the payload,
    // for the given LTI
    // If NO ERROR, respond with a empty optional
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

        // It is not clear if this is the right thing to do here, but it seems consistent with
        // how the rest of the system works
        if(user.get().isAdmin())
        {
            return Optional.empty();
        }

        // These are the groups the user is a member of IN THIS SPACE
        Set<String> usergroup = user.get().lookupGroupSet4AccessTarget(table.dbTabPair._1);

        // For both upsert and delete, we need to check that the logged-in-user has update rights for the record
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
    // May 2025 - instead of doing this process, we will just block uploads of DBs with GROUP ALLOW for time being
    // An alternate approach would be: check for table size, if they're too big, block;
    // Otherwise, blow away all auxrole, and rebuild them all, fail DB upload if the JSON is misformatted
    private static String rectifyAuxRoleSetupUnused(WidgetItem dbitem)
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