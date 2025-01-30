
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

    // Name of the aux group table, derived from the main table.
    public static String getAuxGroupTable(String maintable)
    {
        return String.format("__aux_group_%s", maintable);
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


    static int fullInsertGroupAllow(WidgetItem dbitem, String maintable)
    {
        QueryCollector qcol = CoreUtil.fullTableQuery(dbitem, maintable);
        Map<Integer, Map<String, Boolean>> groupallow;


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

}