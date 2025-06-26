package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 

import java.sql.*;

import javax.servlet.http.*;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;

import org.json.simple.*;
import org.json.simple.parser.*;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.CoreDb.QueryCollector;


import io.webwidgets.core.AuthLogic.*;
import io.webwidgets.core.CallBack2Me.*;
import io.webwidgets.core.LiteTableInfo.*;

public class BulkOperation
{

    // Bulk Update of widget data
    // Same basic arguments as other endpoints, but here the 
    // @WebServlet(urlPatterns = "*bulkupdate*") 
    // Somehow I was not able to get the urlPatterns trick to work here
    public static class BulkUpdate extends HttpServlet {

        protected void doPost(HttpServletRequest request, HttpServletResponse response)  throws ServletException, IOException 
        {
            ArgMap innmap = WebUtil.getArgMap(request);
            ArgMap outmap = new ArgMap();

            // TODO: see note about caching on the main update servlet
            // Though this operation is going to be called less often
            LiteTableInfo tableInfo = LiteTableInfo.fromArgMap(innmap);
            tableInfo.runSetupQuery();

            boolean haveissue = standardCheckForIssue(request, tableInfo, outmap);


            // June 2025 - FG tables cannot use bulk operations
            if(tableInfo.hasGranularPerm())
            {
                CallBack2Me.placeFailCode(outmap, FailureCode.NoBulkUpdateGranular);
                haveissue = true;
            }

            // This sequence of error checking is shared with CallBack2Me, figure out how to share
            Optional<String> emailissue = MailSystem.checkForEmailError(tableInfo, innmap);
            if(emailissue.isPresent())
            {
                CallBack2Me.placeFailCode(outmap, FailureCode.EmailProblem, emailissue.get());
                haveissue = true;
            }
            

            if(!haveissue)
            {
                String delidstr = innmap.getStr("delete_id_list", null);
                String bulkupstr = innmap.getStr("bulkpayload", null);
                Util.massert(Util.setify(delidstr != null, bulkupstr != null).size() == 2,
                    "Have DELETE code %s, and UPDATE code %s, one or other must be null", delidstr, bulkupstr);

                if(delidstr != null)
                {
                    int delcount = processDelete(tableInfo, delidstr);
                    outmap.put("user_message", Util.sprintf("Bulk delete of %d records successful", delcount));
                } else {
                    boolean supplyid = innmap.getBit("supplyid", false);
                    int upcount = processBulkUpdate(tableInfo, bulkupstr, supplyid);
                    outmap.put("user_message", Util.sprintf("Bulk update of %d records successful", upcount));
                }

                outmap.put("status_code", "okay");
            }
            
            writeJsonResponse(response, outmap);
        }

        public static int processBulkUpdate(LiteTableInfo table, String bulkupstr, boolean supplyid) throws IOException
        {

            List<LinkedHashMap<String, Object>> payloadList;

            try { payloadList = loadPayloadList(table, bulkupstr); }
            catch (ParseException pex) { throw new IOException(pex); }

            // supply=false, the default, this just checks that all the incoming records have IDs
            maybeSupplyId(table, payloadList, supplyid);

            // Need to clear out old IDs first, because we are using INSERT below
            // Alternatively, we could find the IDs that are missing, and create skeleton records for those,
            // then do an UPDATE instead of an insert
            // If we supplied them, we don't need to re-delete
            if(!supplyid)
            {
                List<Integer> delid = Util.map2list(payloadList, payload -> (Integer) payload.get("id"));
                processDelete(table, Util.join(delid, ","));
            }


            SyncController editcontrol = LiteTableInfo.getEditController(table.dbTabPair._1);
            synchronized(editcontrol)
            {

                List<String> clist = new ArrayList<>(table.getColumnNameSet());
                Util.massert(clist.get(0).equals("id"), "Expect the first column of all tables to be 'id', got '%s'", clist.get(0));

                String prepstr = String.format(
                    "INSERT INTO %s (%s) VALUES (%s)",
                    table.dbTabPair._2,
                    Util.join(clist, ","),
                    CoreDb.nQuestionMarkStr(clist.size())
                );


                try (
                    Connection conn = table.dbTabPair._1.createConnection();
                    PreparedStatement pstmt = conn.prepareStatement(prepstr);
                ) {

                    conn.setAutoCommit(false);

                    for(var payload : payloadList)
                    {
                        int position = 1;
                        for(String cname : clist)
                        {
                            // This is a bit of superstition
                            // I think between Java setObject(...) being smart and SQLite type affinity,
                            // this should work okay
                            if(position == 1)
                                { pstmt.setInt(1, Util.cast(payload.get(cname))); }
                            else
                                { pstmt.setObject(position, payload.get(cname)); }

                            position++;
                        }

                        pstmt.addBatch();
                    }

                    pstmt.executeBatch();
                    conn.commit();

                } catch (Exception ex) {
                    // Don't really have anything smart to do here other than throw exception
                    throw new IOException(ex);
                }

                return payloadList.size();
            }
        }

        private static void maybeSupplyId(LiteTableInfo table, List<LinkedHashMap<String, Object>> loadlist, boolean supply)
        {
            // Okay, the id is supplied by the loadPayloadMap, so checking load.containsKey("id") doesn't work
            int misscount = Util.countPred(loadlist, load -> load.get("id") == null);

            if(!supply)
            {
                Util.massert(misscount == 0, "Some records have no id field; call with supplyid=true to request supply");
                return;
            }

            Util.massert(misscount == loadlist.size(),
                "Attempt to supply IDs, but there are some records that already have IDs; you cannot use in mixed mode, supply all or none"
            );

            // IDs already present
            Set<Integer> present = Util.map2set(
                QueryCollector.buildAndRun("SELECT id FROM " + table.dbTabPair._2, table.dbTabPair._1).recList(),
                amap -> amap.getSingleInt()
            );

            TreeSet<Integer> newset = CoreUtil.canonicalRandomIdCreate(
                newid -> !present.contains(newid), new Random(), loadlist.size());

            for(var payload : loadlist)
                { payload.put("id", newset.pollFirst()); }
        }


        private static List<LinkedHashMap<String, Object>> loadPayloadList(LiteTableInfo table, String bulkupstr) throws ParseException
        {
            JSONArray array = Util.cast(new JSONParser().parse(bulkupstr));
            List<?> array2 = Util.cast(array);

            // Have some weird superstition about converting to List<?> here
            return table.bulkConvert(array2);
        }

        private static List<Integer> loadDeleteIdList(String delidstr)
        {
            List<String> tokens = Util.listify(delidstr.split(","));
            return Util.map2list(tokens, tkn -> Integer.valueOf(tkn));
        }

        public static int processDelete(LiteTableInfo table, String delidstr) throws IOException
        {
            SyncController editcontrol = LiteTableInfo.getEditController(table.dbTabPair._1);
            synchronized(editcontrol)
            {
                // We don't actually need to transform back to List<Integer> here! 
                // This is a protection against SQL injection : if this conversion works, 
                // we know the string is just a list of integers
                var deletelist = loadDeleteIdList(delidstr);
                String delcomm = String.format("DELETE FROM %s WHERE id IN (%s)", table.dbTabPair._2, delidstr);
                Util.massert(delcomm.length() < 1_000_000, 
                    "Attempt to bulk-delete too many records %d, this is a limitation of current implementation", deletelist.size());

                return CoreDb.execSqlUpdate(delcomm, table.dbTabPair._1);
            }
        }
    }

    // This sequence of error checking is shared with CallBack2Me, figure out how to share
    static boolean standardCheckForIssue(HttpServletRequest request, LiteTableInfo tableInfo, ArgMap outmap)
    {
        Optional<WidgetUser> optuser = AuthLogic.getLoggedInUser(request);
        if(!optuser.isPresent())
        {
            CallBack2Me.placeFailCode(outmap, FailureCode.UserLoggedOut);
            return true;
        }
        
        AuthChecker myChecker = AuthChecker.build().userFromRequest(request).directDbWidget(tableInfo.getWidget());

        if (!myChecker.allowWrite())
        {
            CallBack2Me.placeFailCode(outmap, FailureCode.AccessDenied);
            return true;
        }
        
        Optional<String> maintmode = AdvancedUtil.maintenanceModeInfo();
        if(maintmode.isPresent())
        {
            CallBack2Me.placeFailCode(outmap, FailureCode.MaintenanceMode, maintmode.get());
            return true;
        }

        return false;
    }

    private static void writeJsonResponse(HttpServletResponse response, ArgMap outmap) throws IOException
    {
        JSONObject jsonout = CallBack2Me.buildJsonResponse(outmap);
        PrintWriter out = response.getWriter();
        out.print(jsonout.toString());
        out.print("\n");
        out.close();
    }
}