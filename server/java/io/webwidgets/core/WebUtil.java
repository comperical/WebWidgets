
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 

import javax.servlet.*;
import javax.servlet.http.*;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.FileUtils;
import net.danburfoot.shared.TimeUtil.*;

import io.webwidgets.core.WidgetOrg.*;


public class WebUtil
{ 
	public static String AUTO_INCLUDE_PREFIX = "My";

	public static String FAVICON_FILE_NAME = "MyFavIcon";
	
	public static List<String> AUTO_INCLUDE_SUFFIX = Util.listify(".js", ".css");
	
	public static String WWIO_DOMAIN = "webwidgets.io";

	public static String LOCALHOST = "localhost:8080";

	public static String AWS_HOST = "compute.amazonaws.com";
		
	public static String LOGIN_RELATIVE_URL = "/u/admin/LogIn.jsp";
		
	public static String getUserHomeRelative(WidgetUser wuser)
	{
		return String.format("/u/%s/", wuser.getUserName());
	}

	// Get Widget from the Page URL of the request.
	// Return the home/base Widget if appropriate.
	// If URL corresponds to non-Widget path, return empty.
	public static Optional<WidgetItem> lookupWidgetFromPageUrl(HttpServletRequest request)
	{
		return lookupWidgetFromPageUrl(request.getRequestURL().toString());
	}
	
	public static Optional<WidgetItem> lookupWidgetFromPageUrl(String pageurl) 
	{
		try {
			return Optional.of(getWidgetFromUrl(pageurl));
		} catch (Exception ex) {
			return Optional.empty();	
		}

	}

	// Special feature to help dev: if the user is in local mode, 
	// Bounce the HTTP request to the corresponding local URL.
	// TODO: remove this, it should be no longer used
	public static boolean shouldBounce2Local(HttpServletRequest request)
	{
		// If the user is not logged in at this point, there should be an 
		// error message that gets presented. But it's not responsibility of 
		// this method.
		Optional<WidgetUser> optuser = AuthLogic.getLoggedInUser(request);
		if(!optuser.isPresent())
			{ return false; }
		
		// This feature is only for admins.
		WidgetUser wuser = optuser.get();
		return wuser.isAdmin() && !wuser.haveLocalDb();
	}
	

	public static void bounce2LogInPage(HttpServletRequest request, HttpServletResponse response) throws IOException
	{
		String bounce2url = request.getRequestURL().toString();
		String redirect = String.format("%s?bounceback=%s",
							WebUtil.LOGIN_RELATIVE_URL, request.getRequestURL().toString());

		response.sendRedirect(redirect);
	}

	public static String rewriteAsLocal(String remoteurl) 
	{
		int lifept = remoteurl.indexOf("/life");
		Util.massert(lifept != -1);
		
		String suburl = remoteurl.substring(lifept);
		return Util.sprintf("http://localhost:8080%s", suburl);
	}
		
	// For this method, the URL MUST conform to the expected pattern
	// If you are not sure if it will conform, use getWidgetFromPageUrl
	static WidgetItem getWidgetFromUrl(String pageurl)
	{
		String subpath = getRelativeResource(pageurl);
		Util.massert(subpath.startsWith("/u/"),
			"Expected to start with /u/ patter, got %s", subpath);
		
		LinkedList<String> toklist = Util.linkedlistify(subpath.split("/"));

		Util.massert(toklist.poll().equals(""));
		Util.massert(toklist.poll().equals("u"));

		String username = toklist.poll();
		WidgetUser wuser = WidgetUser.valueOf(username);

		String pageName = toklist.pollLast();
		return toklist.isEmpty() ? wuser.baseWidget() : new WidgetItem(wuser, toklist.peek());
	}	
	
	static String getRelativeResource(String fullurl) 
	{
		for(String probe : Util.listify(LOCALHOST, AWS_HOST, WWIO_DOMAIN))
		{
			int domidx = fullurl.indexOf(probe);
			if(domidx == -1)
				{ continue; }
	
			return fullurl.substring(domidx + probe.length());			
		}
		
		Util.massert(false, "Failed to find domain name in page url %s", fullurl);
		return null;
	}
	
	// TODO: why isn't this a method on WidgetItem...?
	public static File getAutoGenJsDir(WidgetItem witem)
	{
		// /opt/userdata/lifecode/widgets/heather/links/		
		String userdir = witem.theOwner.getAutoGenJsDir().getAbsolutePath();
		String bdir = userdir + "/" + witem.theName;
		return new File(bdir);
	}
	
	public static List<String> getConfigTemplate(WidgetUser wuser)
	{
		String accessline = Util.sprintf("%s=%s", AuthLogic.ACCESS_HASH_COOKIE, wuser.getAccessHash());
		
		return Util.listify(
			accessline,
			"codedir=PATH_TO_CODE_DIR",
			"dbdir=PATH_TO_DATA_DIR"
		);
	}
	
	// List of files in the user base dir that start with My
	// and end in either .css or .js extensions
	public static List<File> getAutoIncludeList(WidgetUser user, Optional<String> optwdg)
	{
		File basedir = optwdg.isPresent()
						? (new WidgetItem(user, optwdg.get())).getWidgetBaseDir()
						: user.getUserBaseDir();
		
		if(!basedir.exists())
			{ return Collections.emptyList(); }
		
		List<File> inclist = Util.listify();
		
		for(File f : basedir.listFiles())
		{
			String name = f.getName();
			
			if(f.isDirectory())
				{ continue; }


			// Special handling for fav-icons
			if(f.getName().startsWith(FAVICON_FILE_NAME))
			{
				inclist.add(f);
				continue;
			}

			
			if(!name.startsWith(AUTO_INCLUDE_PREFIX))
				{ continue; }
			
			boolean havesuffix = AUTO_INCLUDE_SUFFIX
						.stream()
						.filter(suff -> name.endsWith(suff))
						.findAny()
						.isPresent();
			
			if(havesuffix) 
				{ inclist.add(f); }
		}
		
		return inclist;
	}

	// We need this for base-level includes
	// TODO: this stuff really isn't clear yet
	public static List<String> getAutoIncludeStatement(WidgetUser owner)
	{
		List<File> srclist = getAutoIncludeList(owner, Optional.empty());
		return includeTargetFileList(srclist, owner, Optional.empty());
	}
	
	public static List<String> getAutoIncludeStatement(WidgetItem item)
	{
		List<String> result = Util.arraylist();

		for(boolean isbase : Util.listify(true, false))
		{
			Optional<String> wdgname = isbase ? Optional.empty() : Optional.of(item.theName);
			List<File> srclist = getAutoIncludeList(item.theOwner, wdgname);
			result.addAll(includeTargetFileList(srclist, item.theOwner, wdgname));
		}

		return result;
	}

	private static List<String> includeTargetFileList(List<File> filelist, WidgetUser owner, Optional<String> optname)
	{

		// TODO: need to integrate this code with the other autoinclude tech, that does exactly the same thing
		List<String> statelist = Util.arraylist();

		for(File f : filelist)
		{
			long modtime = f.lastModified();
			String relpath = Util.sprintf("/u/%s%s/%s", 
				owner, optname.isPresent() ? "/" + optname.get() : "", f.getName());

			if(f.getName().startsWith(FAVICON_FILE_NAME))
			{
				// <link rel="icon" type="image/x-icon" href="/u/d57tm/vimsicon.png">
				String state = Util.sprintf("<link rel=\"icon\" type=\"image/x-icon\" href=\"%s?modtime=%d\"></link>", relpath, modtime);
				statelist.add(state);
				continue;
			}


			if(f.getName().endsWith(".js"))
			{
				// <script type="text/javascript" src="SecretShared.js"></script>
				String state = Util.sprintf("<script type=\"text/javascript\" src=\"%s?modtime=%d\"></script>", relpath, modtime);
				statelist.add(state);
				continue;
			} 
			
			if(f.getName().endsWith(".css"))
			{
				// <link rel="stylesheet" href="/life/asset/cascade/TableStyle.css"></link>
				String state = Util.sprintf("<link rel=\"stylesheet\" href=\"%s?modtime=%d\"></link>", relpath, modtime);
				statelist.add(state);
				continue;
			}
			
		}
		
		return statelist;



	}

	public static ArgMap getCookieArgMap(HttpServletRequest req)
	{
		ArgMap argmap = new ArgMap();
		
		if(req.getCookies() != null)
		{
			for(Cookie onecook : req.getCookies())
				{ argmap.put(onecook.getName(), onecook.getValue()); }
		}
		
		return argmap;
	}
	
	public static ArgMap getArgMap(ServletRequest request)
	{
		ArgMap argmap = new ArgMap();
		
		for(String pname : request.getParameterMap().keySet())
			{ argmap.setStr(pname, request.getParameter(pname)); }
		
		return argmap;
	}


	// Transform a relative path like:
	// /u/shared/asset/js/LiteJsHelper.js
	// Into:
	// /u/shared/asset/js/LiteJsHelper.js?cksum=34548934
	// Relative path must exist at given location.
	// cksum is the Unix cksum of the file.
	// We do this to tell the browsers to reload the file if the cksum has changed.
	// Deprecated!!! this is only used by the old AssetInclude
	public static String includeCheckRelativePath(String relpath) 
	{
		Util.massert(relpath.startsWith("/u/shared"), "Expected a relative path to start with /u/shared, got " + relpath);

		String prefix = Util.sprintf("%s/%s", CoreUtil.getWidgetCodeDir(), WidgetUser.getSharedUser());

		File mainfile = new File(relpath.replace("/u/shared", prefix));

		Util.massert(mainfile.exists(), 
			"Transformed relative path %s -> full path %s, but full path does not exist", prefix, mainfile);

		long cksum = CoreUtil.getFileCkSum(mainfile);

		return relpath + "?cksum=" + cksum;
	}


	public static void logPageLoad(HttpServletRequest request) 
	{
		String timestamp = ExactMoment.build().asLongBasicTs(TimeZoneEnum.PST);

		try {
			// This is an optional configuration. If the DB is not present, just skip this log
			WidgetItem syslog = new WidgetItem(WidgetUser.getSharedUser(), "syslog");
			if(!syslog.getLocalDbFile().exists())
				{ return; }
			
			int randid = (new Random()).nextInt();

			CoreDb.upsertFromRecMap(syslog, "page_load", 1, CoreDb.getRecMap(
				"id", randid,
				"url", request.getRequestURI().toString(),
				"time_pst", timestamp
			));

		} catch (Exception ex) {
			ex.printStackTrace();
		}

	}
} 

