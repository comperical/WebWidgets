
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 

import javax.servlet.*;
import javax.servlet.http.*;
import javax.servlet.annotation.WebFilter;
import javax.servlet.annotation.WebServlet;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.FileUtils;
import net.danburfoot.shared.TimeUtil.*;
import net.danburfoot.shared.CollUtil.Pair;


import io.webwidgets.core.WidgetOrg.*;
import io.webwidgets.core.AuthLogic.AuthChecker;


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
		
	// For this method, the URL MUST conform to the expected pattern
	// If you are not sure if it will conform, use getWidgetFromPageUrl
	public static WidgetItem getWidgetFromUrl(String pageurl)
	{
		// TODO: this technique makes it impossible to run tests against a server that does not have the webwidgets.io URL
		String subpath = getRelativeResource(pageurl);
		Util.massert(subpath.startsWith("/u/"),
			"Expected to start with /u/ patter, got %s", subpath);
		
		LinkedList<String> toklist = Util.linkedlistify(subpath.split("/"));

		Util.massert(toklist.poll().equals(""));
		Util.massert(toklist.poll().equals("u"));

		String username = toklist.poll();
		WidgetUser wuser = WidgetUser.valueOf(username);

		String pageName = toklist.pollLast();
		return toklist.isEmpty() ? WidgetItem.userBaseWidget(wuser) : new WidgetItem(wuser, toklist.peek());
	}

	static Pair<String, String> widgetInfoFromUri(String uri)
	{

		if(uri.length() == 0)
			{ return null; }

		LinkedList<String> toklist = Util.linkedlistify(uri.split("/"));
		if(toklist.isEmpty() || !toklist.peekFirst().equals(""))
			{ return null; }

		// Peel off starting item
		toklist.pollFirst();

		// Need to at least have /u/<username
		if(toklist.size() < 2)
			{ return null;}

		// Peel off the /u prefix
		if(!toklist.pollFirst().toLowerCase().equals("u"))
				{ return null; }

		// Now we have the actual user. The name may or may not be present
		String userprobe = toklist.pollFirst();
		String nameprobe = null;

		if(toklist.size() > 1)
			{ nameprobe = toklist.pollFirst(); }

		// The second argument can be null
		return Pair.build(userprobe, nameprobe);
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
	
	public static List<String> getConfigTemplate(WidgetUser wuser)
	{
		String accessline = String.format("%s=%s", CoreUtil.ACCESS_HASH_COOKIE, wuser.getAccessHash());
		
		return Arrays.asList(
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


	// This filter blocks the app from serving flat files in a user directory,
	// if the accessor does not have appropriate (read) permission
	// Thus, flat files in the /u/dburfoot/links/... folder will be readable or not
	// exactly if the Widget data in the dburfoot::links DB is readable
	// The question of what to do with base-level data, and data that is in a folder other than the widget folder, is TBD
	// Currently it is public, for backwards - compat reasons
	@WebFilter("/*")
	public static class ProtectUserDataFilter implements Filter {

		// This thing is apparently required
		@Override
		public void init(FilterConfig filterConfig) throws ServletException {}

	    @Override
	    public void doFilter(javax.servlet.ServletRequest request, javax.servlet.ServletResponse response, FilterChain chain)
	            throws IOException, ServletException {

	        var httprequest = (HttpServletRequest) request;

	        String uri = httprequest.getRequestURI();

	        // For these two types of files, we include the auth checking and forwarding in the downstream handler
	        boolean downcheck = uri.endsWith(".jsp") || uri.endsWith(".wisp");

	        if(!downcheck && blockUserDataRead(httprequest))
	        {
	            ((HttpServletResponse) response).sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied");
	            return;
	        }

	        chain.doFilter(request, response);
	    }

	    private static boolean blockUserDataRead(HttpServletRequest request, Pair<String, String> infopair)
	    {
			// there's no way for it to be a user's stuff. Will be protected by other pieces of code.
			if(infopair == null)
				{ return false; }

			// Lookup the user. If there's no user, can't be user's stuff, same idea as above.
			var user = WidgetUser.softLookup(infopair._1);
			if(!user.isPresent())
				{ return false; }

			// Don't block the shared user!!!
			if(user.get() == WidgetUser.getSharedUser())
				{ return false; }

			// Here we're checking if it's a "normal" widget
			// Block unless the logged-in user can read the widget data
			if(infopair._2 != null)
			{
				// What do we do about non-DB subfolders here? This is a point of study.
				// Hopefully the AuthChecker will not throw an error if you 
				var item = new WidgetItem(user.get(), infopair._2);
				var okayread = AuthChecker.build().userFromRequest(request).directDbWidget(item).allowRead();
				return !okayread;
			}

			// We are now dealing with the "base" widget, ie the user's root directory
			// For backward compat, and because I don't know the right thing to do here, 
			// allow the read.
			return false;
		}
	    

	    private static boolean blockUserDataRead(HttpServletRequest request)
	    {
	        // Important: remove the /autogenjs from a URI if you see it
	        // autogenjs data will be treated the same as the Widget it corresponds to
	    	var uriparser = new UriParser(request.getRequestURI().replaceAll("/autogenjs", ""));

			// there's no way for it to be a user's stuff. Will be protected by other pieces of code.
			if(!uriparser.isUserArea())
				{ return false; }

			// Lookup the user. If there's no user, can't be user's stuff, same idea as above.
			var owner = uriparser.getOwner();
			if(!owner.isPresent())
				{ return false; }

			// Don't block the shared user!!
			if(owner.get() == WidgetUser.getSharedUser())
				{ return false; }

			// Here we're checking if it's a "normal" widget
			// Block unless the logged-in user can read the widget data
			var dbitem = uriparser.getWidgetItem();
			if(dbitem.isPresent())
			{
				var okayread = AuthChecker.build().userFromRequest(request).directDbWidget(dbitem.get()).allowRead();
				return !okayread;
			}

			// We are now dealing with the "base" widget, ie the user's root directory
			// For backward compat, and because I don't know the right thing to do here, 
			// allow the read.
			return false;
		}

	}


	// This is a targeted/surgical filter operation that does just one thing:
	// allow the apps to leave out the file extension for .wisp and .jsp files
	// This results in cleaner URLs, and hides details of the underlying JSP implementation
	// The logic is very simple: if you see a request that could be serviced by adding a ".wisp" or ".jsp" suffix,
	// go ahead and service it using the appropriate suffix.
	@WebFilter("/*")
	public static class SkipExtensionFilter implements Filter {

		private static Set<String> KNOWN_API_PATH_SET = Util.setify("directload", "bulkupdate", "callback", "blobstore", "push2me", "pull2you", "extend");

		@Override
		public void init(FilterConfig filterConfig) throws ServletException {}

	    @Override
	    public void doFilter(javax.servlet.ServletRequest _request, javax.servlet.ServletResponse _response, FilterChain chain)
	            throws IOException, ServletException {

	        var request = (HttpServletRequest) _request;
	        var uri = request.getRequestURI();
	        var infopair = widgetInfoFromUri(uri);

	        // Gotcha: you cannot split on ".", it is interpreted as a wildcard, must escape it
	        if(infopair == null || uri.split("\\.").length > 1 || KNOWN_API_PATH_SET.contains(infopair._1))
	        {
		        chain.doFilter(_request, _response);
				return;
	        }

	        var suburi = uri.startsWith("/u") ? uri.substring("/u".length()) : uri;
	        var realpath = request.getServletContext().getRealPath(suburi);

	        for(String ext : approvedExtensionList(infopair))
	        {
				var probefile = new File(realpath + ext);
				if(probefile.exists())
				{
					var dispatcher = request.getRequestDispatcher(suburi + ext);
					dispatcher.forward(request, _response);
					return;
				}
	        }

	        chain.doFilter(_request, _response);
	    }

	    private static List<String> approvedExtensionList(Pair<String, String> infopair)
	    {
			if(infopair == null)
				{ return Collections.emptyList(); }

			var optuser = WidgetUser.softLookup(infopair._1);
			if(optuser.isPresent())
				{ return Util.listify(".wisp", ".jsp"); }

			// I am a bit scared about this, but I want to be able to skip the .jsp extensions
			// things like AdminMain.jsp, LogIn.jsp, etc
			return Util.listify(".jsp");
		}
	}

	public static class UriParser
	{

		private LinkedList<String> _subDirList;

		private final String _leafSegment;

		private boolean _userArea = false;

		private UriParser(String uri)
		{
			_subDirList = Util.linkedlistify(uri.split("/"));
			var expempty = _subDirList.pollFirst();
			Util.massert(expempty.equals(""), 
				"By convention, expect the URI string to start with a forward path, got %s", uri);


			_leafSegment = _subDirList.isEmpty() ? null : _subDirList.pollLast();

			if(_subDirList.peek().equals("u"))
			{
				_userArea = true;
				_subDirList.poll();
			}

		}

		public static UriParser fromRequest(HttpServletRequest request)
		{
			return new UriParser(request.getRequestURI());
		}

		public static UriParser fromUri(java.net.URI myuri)
		{
			return new UriParser(myuri.getRawPath());
		}

		public List<String> getDirTokenList()
		{
			return Collections.unmodifiableList(_subDirList);
		}

		public String getLeafSegment()
		{
			return _leafSegment;
		}


		public boolean isUserArea()
		{
			return _userArea;
		}

		public Optional<WidgetUser> getOwner()
		{
			if(isUserArea() && !_subDirList.isEmpty())
				{ return WidgetUser.softLookup(_subDirList.get(0)); }

			return Optional.empty();
		}

		public Optional<WidgetItem> getWidgetItem()
		{
			Optional<WidgetUser> owner = getOwner();
			if(owner.isPresent() && _subDirList.size() >= 2)
			{
				var item = new WidgetItem(owner.get(), _subDirList.get(1));
				if(item.dbFileExists())
					{ return Optional.of(item); }
			}

			return Optional.empty();
		}
	}
}

