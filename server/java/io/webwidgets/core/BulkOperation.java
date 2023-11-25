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

            // This sequence of error checking is shared with CallBack2Me, figure out how to share
            Optional<WidgetUser> optuser = AuthLogic.getLoggedInUser(request);
            if(!optuser.isPresent())
            {
                placeFailCode(outmap, FailureCode.UserLoggedOut);
                return;
            }
            
            AuthChecker myChecker = AuthChecker.build().userFromRequest(request).directDbWidget(tableInfo.getWidget());

            if (!myChecker.allowWrite())
            {
                placeFailCode(outmap, FailureCode.AccessDenied);
                return;
            }
            
            Optional<String> maintmode = CoreUtil.maintenanceModeInfo();
            if(maintmode.isPresent())
            {
                placeFailCode(outmap, FailureCode.MaintenanceMode, maintmode.get());
                return;
            }

            // TODO: this should be a special error message, cannot do bulk updates of Mail box probably
            Optional<String> emailissue = MailSystem.checkForEmailError(tableInfo, innmap);
            if(emailissue.isPresent())
            {
                placeFailCode(outmap, FailureCode.EmailProblem, emailissue.get());
                return;
            }
            

            int upcount = processBulkUpdate(tableInfo, innmap);


            outmap.put("status_code", "okay");
            outmap.put("user_message", Util.sprintf("Bulk update of %d records successful", upcount));

        
            {
                JSONObject jsonout = CallBack2Me.buildJsonResponse(outmap);
                PrintWriter out = response.getWriter();
                out.print(jsonout.toString());
                out.print("\n");
                out.close();
            }
        }

        private static int processBulkUpdate(LiteTableInfo table, ArgMap innmap) throws IOException
        {
            try {
                List<LinkedHashMap<String, Object>> updatelist = loadPayloadList(table, innmap);
                for(var item : updatelist)
                    { CoreDb.upsertFromRecMap(table.dbTabPair._1, table.dbTabPair._2, 1, item); }


                return updatelist.size();

            } catch (ParseException pex) {
                throw new IOException(pex);
            }
        }

        private static List<LinkedHashMap<String, Object>> loadPayloadList(LiteTableInfo table, ArgMap innmap) throws ParseException
        {
            String bigdata = innmap.getStr("bulkpayload");

            JSONArray array = Util.cast(new JSONParser().parse(bigdata));
            List<?> array2 = Util.cast(array);

            return Util.map2list(array2, ob -> table.getPayLoadMap((JSONObject) ob));
        }



        // TODO: all of this code is copy+pasted from CallBack2Me, figure out how to share
        private void placeException(ArgMap outmap, Exception ex)
        {
            placeException(outmap, FailureCode.OtherError, ex);
        }

        private void placeException(ArgMap outmap, FailureCode fcode, Exception ex)
        {
            outmap.put("status_code", "fail");
            outmap.put("failure_code", fcode.toString());
            outmap.put("user_message", ex.getMessage().trim());
            outmap.put("extra_info", "");
        }
        
        private void placeFailCode(ArgMap outmap, FailureCode fcode)
        {
            placeFailCode(outmap, fcode, "");
        }
            
        
        private void placeFailCode(ArgMap outmap, FailureCode fcode, String extrainfo)
        {
            outmap.put("status_code", "fail");
            outmap.put("failure_code", fcode.toString());
            outmap.put("user_message", fcode.userErrorMessage);
            outmap.put("extra_info", extrainfo);
        }

    }



}