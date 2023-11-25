
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 

import javax.servlet.*;
import javax.servlet.http.*;

import org.json.simple.JSONObject;



import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.FileUtils;

import io.webwidgets.core.WidgetOrg.*;
import io.webwidgets.core.AuthLogic.*;
import io.webwidgets.core.LiteTableInfo.*;


public class CallBack2Me extends HttpServlet
{ 
	public enum FailureCode
	{
		MaintenanceMode("The server is in maintenance mode"),
		SyncError("The widget data has been changed by another user"),
		WidgetNotFound("The widget could not be found"),
		AccessDenied("You do not have permission to modify this widget's data"),
		EmailProblem("There is a problem with this email"),
		NumberConversionError("There was a problem converting data into numeric types"),
		// For this one, the exception stack trace should be shown, nothing else.
		OtherError("-------"),
		UserLoggedOut("You have been logged out, please refresh the page to log in again");
		
		public final String userErrorMessage;
		
		FailureCode(String uem) 
		{
			userErrorMessage = uem;	
		}
	}
	
	public void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException
	{
		doBoth(request, response);
	}
	
	public void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException
	{
		doBoth(request, response);
	}
	
	private void doBoth(HttpServletRequest request, HttpServletResponse response)
	throws ServletException, IOException
	{
		ArgMap outmap = new ArgMap();
		
		try {
			processGetSub(request, outmap);
			
		} catch (ArgMapNumberException ex) {
			
			placeException(outmap, FailureCode.NumberConversionError, ex);

		} catch (Exception ex) {
			
			placeException(outmap, ex);
		}
		
		Util.massert(outmap.containsKey("status_code"), "Should have a status code");
		

		JSONObject jsonout = buildJsonResponse(outmap);
		
		{
			PrintWriter out = response.getWriter();
			out.print(jsonout.toString());
			out.print("\n");
			out.close();
		}
	}
	
	@SuppressWarnings("unchecked")
	static JSONObject buildJsonResponse(ArgMap outmap) 
	{
		JSONObject jsonout = new JSONObject();
		jsonout.putAll(outmap);
		return jsonout;
	}

	private void processGetSub(HttpServletRequest request, ArgMap outmap)
	{
		ArgMap innmap = WebUtil.getArgMap(request);	

		// TODO: this section implies that every Sync or delete operation requires a full LTI setup,
		// which potentially involves a significant amount of overhead (?)
		// Caching would be powerful here, because usage patterns will follow a "session" pattern,
		// where the user accesses a widget and interacts with it several times before moving on
		LiteTableInfo tableInfo = new LiteTableInfo(innmap);
		tableInfo.runSetupQuery();
		
		Optional<WidgetUser> optuser = AuthLogic.getLoggedInUser(request);
		if(!optuser.isPresent())
		{
			placeFailCode(outmap, FailureCode.UserLoggedOut);
			return;
		}
		
		AuthChecker myChecker = AuthChecker.build()
							.userFromRequest(request)
							.directDbWidget(tableInfo.getWidget());

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

		Optional<String> emailissue = MailSystem.checkForEmailError(tableInfo, innmap);
		if(emailissue.isPresent())
		{
			placeFailCode(outmap, FailureCode.EmailProblem, emailissue.get());
			return;
		}
		
		tableInfo.processAjaxOp(innmap);
		
		outmap.put("status_code", "okay");
		outmap.put("user_message", "ajax sync op successful");
	}

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

