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

        @Override
        protected void doPost(HttpServletRequest request, HttpServletResponse response)  throws ServletException, IOException 
        {
            try { doPostSub(request, response); }
            catch (Exception ex) { ex.printStackTrace(); }
        } 


        protected void doPostSub(HttpServletRequest request, HttpServletResponse response)  throws ServletException, IOException 
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

                try {
                    if(delidstr != null)
                    {
                        int delcount = processDelete(tableInfo, delidstr);
                        outmap.put("user_message", Util.sprintf("Bulk delete of %d records successful", delcount));
                    } else {
                        int upcount = processBulkUpdate(tableInfo, bulkupstr);
                        outmap.put("user_message", Util.sprintf("Bulk update of %d records successful", upcount));
                    }

                    outmap.put("status_code", "okay");


                } catch (IOException ioex) {
                    ioex.printStackTrace();
                    CallBack2Me.placeFailCode(outmap, FailureCode.OtherError, ioex.getMessage());
                }

            }
            
            writeJsonResponse(response, outmap);
        }

        public static int processBulkUpdate(LiteTableInfo table, String bulkupstr) throws IOException
        {
            InsertUpdateSplit splitter;

            try { splitter = new InsertUpdateSplit(table, bulkupstr); }
            catch (ParseException pex) { throw new IOException(pex); }

            SyncController editcontrol = LiteTableInfo.getEditController(table.dbTabPair._1);
            synchronized(editcontrol)
            {
                // These are the non-ID columns, need to keep these in proper order
                List<String> nonidlist = splitter.getNonIdList();

                String insertstr = getInsertPrepared(table, nonidlist);
                String updatestr = getUpdatePrepared(table, nonidlist);


                try (
                    Connection conn = table.dbTabPair._1.createConnection();
                    PreparedStatement instmt = conn.prepareStatement(insertstr);
                    PreparedStatement upstmt = conn.prepareStatement(updatestr);
                ) {

                    conn.setAutoCommit(false);

                    for(boolean isupdate : Util.listify(true, false))
                    {
                        var pstmt = isupdate ? upstmt : instmt;
                        var sendlist = splitter.getDesiredSplit(isupdate);
                        if(sendlist.isEmpty())
                            { continue; }

                        for(var payload : sendlist)
                        {
                            for(int idx : Util.range(nonidlist))
                            {
                                String col = nonidlist.get(idx);
                                pstmt.setObject(idx+1, payload.get(col));
                            }

                            int payid = Util.cast(payload.get(CoreUtil.STANDARD_ID_COLUMN_NAME));
                            pstmt.setInt(nonidlist.size()+1, payid);
                            pstmt.addBatch();
                        }

                        pstmt.executeBatch();
                    }

                    conn.commit();

                } catch (Exception ex) {

                    // SQLite guarantees rollback here, even though it's not explicit
                    // And it is annoying to have multiple layers to make it so conn is in scope
                    // conn.rollback();

                    // Don't really have anything smart to do here other than throw exception
                    ex.printStackTrace();
                    throw new IOException(ex);
                }

                return splitter.totalSize();
            }
        }


        private static String getUpdatePrepared(LiteTableInfo LTI, List<String> nonidlist)
        {
            var setclause = Util.map2list(nonidlist, s -> String.format("%s = ?", s));

            return String.format(
                "UPDATE %s SET %s WHERE %s = ?",
                LTI.dbTabPair._2,
                Util.join(setclause, " , "),
                CoreUtil.STANDARD_ID_COLUMN_NAME
            );
        }

        private static String getInsertPrepared(LiteTableInfo LTI, List<String> nonidlist)
        {
            // Okay, very important: we are supplying the ID column at the END of the list of values
            // to match the ordering requirements of the UPDATE command
            return String.format(
                "INSERT INTO %s (%s, %s) VALUES (%s, ?)",
                LTI.dbTabPair._2,
                Util.join(nonidlist, ","),
                CoreUtil.STANDARD_ID_COLUMN_NAME,
                CoreDb.nQuestionMarkStr(nonidlist.size())
            );
        }

        // this is no longer used
        // Previous idea was to allow caller to decline to specify some IDs, and the server would supply for you
        // That is no longer used
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


    private static class InsertUpdateSplit
    {
        private List<LinkedHashMap<String, Object>> _mainList;

        private Set<Integer> _currentIdSet;

        InsertUpdateSplit(LiteTableInfo table, String bulkupstr) throws ParseException
        {
            JSONArray array = Util.cast(new JSONParser().parse(bulkupstr));
            List<?> array2 = Util.cast(array);

            String query = Util.sprintf("SELECT id FROM %s", table.dbTabPair._2);
            QueryCollector qcol = QueryCollector.buildAndRun(query, table.dbTabPair._1);

            _currentIdSet = Util.map2set(qcol.recList(), amap -> amap.getSingleInt());

            // Have some weird superstition about converting to List<?> here
            _mainList = table.bulkConvert(array2);
        }

        private boolean haveCurrentId(LinkedHashMap<String, Object> record)
        {
            var id = Util.cast(record.get(CoreUtil.STANDARD_ID_COLUMN_NAME));
            return _currentIdSet.contains(id);
        }

        private List<LinkedHashMap<String, Object>> getDesiredSplit(boolean isupdate)
        {
            return Util.filter2list(_mainList, r -> haveCurrentId(r) == isupdate);
        }

        private LinkedHashMap<String, Object> getExample()
        {
            Util.massert(_mainList.size() > 0, "The update list is empty - you must check before calling!!");
            return _mainList.get(0);
        }

        private List<String> getNonIdList()
        {
            return Util.filter2list(getExample().keySet(),
                s -> !CoreUtil.STANDARD_ID_COLUMN_NAME.equals(s));

        }

        private Integer totalSize()
        {
            return _mainList.size();
        }
    }

}