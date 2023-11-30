package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 

import javax.servlet.http.*;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;

import org.json.simple.*;
import org.json.simple.parser.*;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.CoreDb;


import io.webwidgets.core.AuthLogic.*;
import io.webwidgets.core.WidgetOrg.*;
import io.webwidgets.core.CallBack2Me.*;


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
            LiteTableInfo tableInfo = new LiteTableInfo(innmap);
            tableInfo.runSetupQuery();

            boolean haveissue = standardCheckForIssue(request, tableInfo, outmap);

            // This sequence of error checking is shared with CallBack2Me, figure out how to share
            Optional<String> emailissue = MailSystem.checkForEmailError(tableInfo, innmap);
            if(emailissue.isPresent())
            {
                placeFailCode(outmap, FailureCode.EmailProblem, emailissue.get());
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
                    int upcount = processBulkUpdate(tableInfo, bulkupstr);
                    outmap.put("user_message", Util.sprintf("Bulk update of %d records successful", upcount));
                }

                outmap.put("status_code", "okay");
            }
            
            writeJsonResponse(response, outmap);
        }

        private static int processBulkUpdate(LiteTableInfo table, String bulkupstr) throws IOException
        {
            try {
                List<LinkedHashMap<String, Object>> updatelist = loadPayloadList(table, bulkupstr);
                for(var item : updatelist)
                    { CoreDb.upsertFromRecMap(table.dbTabPair._1, table.dbTabPair._2, 1, item); }

                return updatelist.size();

            } catch (ParseException pex) {
                throw new IOException(pex);
            }
        }

        private static List<LinkedHashMap<String, Object>> loadPayloadList(LiteTableInfo table, String bulkupstr) throws ParseException
        {
            JSONArray array = Util.cast(new JSONParser().parse(bulkupstr));
            List<?> array2 = Util.cast(array);

            return Util.map2list(array2, ob -> table.getPayLoadMap((JSONObject) ob));
        }

        private static List<Integer> loadDeleteIdList(String delidstr)
        {
            List<String> tokens = Util.listify(delidstr.split(","));
            return Util.map2list(tokens, tkn -> Integer.valueOf(tkn));
        }

        private static int processDelete(LiteTableInfo table, String delidstr) throws IOException
        {
            var deletelist = loadDeleteIdList(delidstr);
            for(int delid : deletelist)
            { 
                var colmap = CoreDb.getRecMap("id", delid);
                CoreDb.deleteFromColMap(table.dbTabPair._1, table.dbTabPair._2, colmap); 
            }

            return deletelist.size();
        }
    }

    // This sequence of error checking is shared with CallBack2Me, figure out how to share
    static boolean standardCheckForIssue(HttpServletRequest request, LiteTableInfo tableInfo, ArgMap outmap)
    {
        Optional<WidgetUser> optuser = AuthLogic.getLoggedInUser(request);
        if(!optuser.isPresent())
        {
            placeFailCode(outmap, FailureCode.UserLoggedOut);
            return true;
        }
        
        AuthChecker myChecker = AuthChecker.build().userFromRequest(request).directDbWidget(tableInfo.getWidget());

        if (!myChecker.allowWrite())
        {
            placeFailCode(outmap, FailureCode.AccessDenied);
            return true;
        }
        
        Optional<String> maintmode = CoreUtil.maintenanceModeInfo();
        if(maintmode.isPresent())
        {
            placeFailCode(outmap, FailureCode.MaintenanceMode, maintmode.get());
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

    // TODO: all of this code is copy+pasted from CallBack2Me, figure out how to share
    private static void placeException(ArgMap outmap, Exception ex)
    {
        placeException(outmap, FailureCode.OtherError, ex);
    }

    private static void placeException(ArgMap outmap, FailureCode fcode, Exception ex)
    {
        placeFailCode(outmap, fcode, ex.getMessage());
    }
    
    private static void placeFailCode(ArgMap outmap, FailureCode fcode)
    {
        placeFailCode(outmap, fcode, "");
    }
    
    private static void placeFailCode(ArgMap outmap, FailureCode fcode, String extrainfo)
    {
        outmap.put("status_code", "fail");
        outmap.put("failure_code", fcode.toString());
        outmap.put("user_message", fcode.userErrorMessage);
        outmap.put("extra_info", extrainfo);
    }
}