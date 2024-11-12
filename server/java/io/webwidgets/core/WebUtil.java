
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
	
	public static List<String> AUTO_INCLUDE_SUFFIX = Util.listify(".js", ".css", ".html");
	
	public static String WWIO_DOMAIN = "webwidgets.io";

	public static String LOCALHOST = "localhost:8080";

	public static String AWS_HOST = "compute.amazonaws.com";

	// This is an extra string that must be included in .html files for auto-inclusion
	public static String HTML_HEADER_TAG = "Header";
		
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
	@Deprecated
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

		var uri = convert2Uri(pageurl);
		var parser = UriParser.fromUri(uri);

		var dbitem = parser.getWidgetItem();
		if(dbitem.isPresent())
			{ return dbitem.get(); }

		var owner = parser.getOwner();
		if(owner.isPresent())
			{ return WidgetItem.userBaseWidget(owner.get()); }

		return null;

		// TODO: this technique makes it impossible to run tests against a server that does not have the webwidgets.io URL
		/*
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
		*/


	}

	private static java.net.URI convert2Uri(String pageurl)
	{
		try { 
			return new java.net.URI(pageurl);
		} catch (Exception ex) {
			throw new RuntimeException("Failed to convert URL " + pageurl + " to valid URI, please use valid URL syntax");
		}
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
			if(f.isDirectory())
				{ continue; }

			String name = f.getName();

			// Special handling for fav-icons
			if(name.startsWith(FAVICON_FILE_NAME))
			{
				inclist.add(f);
				continue;
			}
			
			if(!name.startsWith(AUTO_INCLUDE_PREFIX))
				{ continue; }
			

			Optional<String> suffix = AUTO_INCLUDE_SUFFIX
											.stream()
											.filter(suff -> name.endsWith(suff))
											.findAny();


			if(!suffix.isPresent())
				{ continue; }

			// HTML files require extra tag to include
			if(suffix.get().equals(".html") && !name.contains(HTML_HEADER_TAG))
				{ continue; }

			inclist.add(f);
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

		List<String> statelist = Util.arraylist();

		for(File f : filelist)
		{
			// For HTML include files, we just insert the HTML directly into the page
			if(f.getName().endsWith(".html"))
			{
				statelist.add("");
				String incname = optname.isPresent() ? optname.get() : "base";
				statelist.add(Util.sprintf("<!-- Auto File Include of HTML snippet (%s):%s -->", incname, f.getName()));

				// For HTML files, we simply slurp the file and include it directly
				List<String> srclist = FileUtils.getReaderUtil().setFile(f).setTrim(false).readLineListE();
				statelist.addAll(srclist);
				statelist.add("<!-- End File Include -->");
				statelist.add("");
				continue;
			}


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
	    public void doFilter(javax.servlet.ServletRequest _request, javax.servlet.ServletResponse _response, FilterChain chain)
	            throws IOException, ServletException {

	        var request = (HttpServletRequest) _request;

	        String uri = request.getRequestURI().toLowerCase();

	        // For these two types of files, we include the auth checking and forwarding in the downstream handler
	        boolean downcheck = uri.endsWith(".jsp") || uri.endsWith(".wisp");

	        // Update: we need to probe for files that don't have extensions also
	        // The handler will forward to the wisp/jsp and handle it from there
			downcheck |= SkipExtensionFilter.probeForExtension(request).isPresent();

	        if(!downcheck && blockUserDataRead(request))
	        {
	            ((HttpServletResponse) _response).sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied");
	            return;
	        }

	        chain.doFilter(_request, _response);
	    }

	    private static boolean blockUserDataRead(HttpServletRequest request)
	    {
	    	var uriparser = UriParser.fromRequest(request);

			// there's no way for it to be a user's stuff. Will be protected by other pieces of code.
			if(!uriparser.isUserArea())
				{ return false; }

			// Lookup the user. If there's no user, can't be user's stuff, same idea as above.
			var owner = uriparser.getOwner();
			if(!owner.isPresent())
				{ return false; }

			// Don't block the shared user!!
			// TODO: having the shared user own both the MASTER db and the shared assets (js/css) is a TERRIBLE design
			// As of Aug 2024, I think it's okay because the Master widget is not market as public read
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

		@Override
		public void init(FilterConfig filterConfig) throws ServletException {}

	    @Override
	    public void doFilter(javax.servlet.ServletRequest _request, javax.servlet.ServletResponse _response, FilterChain chain)
	            throws IOException, ServletException {

	        var request = (HttpServletRequest) _request;
	        var uriparser = UriParser.fromRequest(request);

	        // These conditions all DQ the request from probing for ellided extension
	        if(!uriparser.isUserArea() || uriparser.requestHasExtension() || uriparser.isKnownApiCall())
	        {
		        chain.doFilter(_request, _response);
				return;
	        }

	        var uri = request.getRequestURI();
	        var suburi = uri.startsWith("/u") ? uri.substring("/u".length()) : uri;
	        var realpath = request.getServletContext().getRealPath(suburi);
	        var optext = probeForExtension(request);

	        // Okay, we found a hit on the extension, go ahead and use that
	        if(optext.isPresent())
	        {
				var dispatcher = request.getRequestDispatcher(suburi + optext.get());
				dispatcher.forward(request, _response);
				return;
	        }

	        chain.doFilter(_request, _response);
	    }

	    // Try to find an extension of the request path that has a valid extension (basically JSP or WISP)
	    // If you find it, return the EXTENSION
	    private static Optional<String> probeForExtension(HttpServletRequest request)
	    {
	    	var uriparser = UriParser.fromRequest(request);
	    	if(!uriparser.isUserArea())
	    		{ return Optional.empty(); }

	    	var uri = request.getRequestURI();
	    	// TODO: this should be a method of UriParser
	        var suburi = uri.startsWith("/u") ? uri.substring("/u".length()) : uri;
	        var realpath = request.getServletContext().getRealPath(suburi);

	        for(String ext : approvedExtensionList(uriparser))
	        {
				var probefile = new File(realpath + ext);
				if(probefile.exists())
					{ return Optional.of(ext); }
	        }

	        return Optional.empty();
	    }

	    private static List<String> approvedExtensionList(UriParser uriparser)
	    {
	    	if(!uriparser.isUserArea())
				{ return Collections.emptyList(); }

			// I am a bit scared about using no-extension for the admin console pages,
			// but I want to be able to ellide for requests like AdminMain.jsp, LogIn.jsp, etc
			return uriparser.getOwner().isPresent() 
						? Arrays.asList(".wisp", ".jsp") 
						: Arrays.asList(".jsp");
	    }
	}

	public static class UriParser
	{

		private static Set<String> KNOWN_API_PATH_SET = Util.setify("directload", "bulkupdate", "callback", "blobstore", "push2me", "pull2you", "extend");

		private LinkedList<String> _subDirList;

		private boolean _userArea = false;

		private boolean _knownApiCall = false;

		private Optional<WidgetUser> _optOwner = Optional.empty();

		private Optional<WidgetItem> _optItem = Optional.empty();

		private UriParser(String uri)
		{
			// Canonical swap-out of autogenjs paths. These are considered to be part of the widget from which
			// the JS code is generated.
			_subDirList = Util.linkedlistify(uri.toLowerCase().replaceAll("/autogenjs", "").split("/"));

			if(!_subDirList.isEmpty() && _subDirList.peekFirst().isEmpty())
				{ _subDirList.pollFirst(); }


			// If the first token is specifically "u", we're in the user area of the site
			// otherwise we're in the global area
			if(!_subDirList.isEmpty() && _subDirList.peekFirst().equals("u"))
			{
				_userArea = true;
				_subDirList.pollFirst();
			}

			// IF not user area, or no more tokens, no more analysis is necessary.
			if(!_userArea || _subDirList.isEmpty())
				{ return; }


			// The request represents a call to a known API endpoint of the system
			if(KNOWN_API_PATH_SET.contains(_subDirList.peekFirst()))
			{
				_knownApiCall = true;
				return;
			}

			// The widget owner will be the next token
			_optOwner = WidgetUser.softLookup(_subDirList.peek());
			if(_optOwner.isPresent())
				{ _subDirList.pollFirst(); }


			// If no owner, or out of tokens, we're done.
			if(!_optOwner.isPresent() || _subDirList.isEmpty())
				{ return; }


			// Check to see if the WidgetItem exists.
			// There's a conceptual question here about what to do if it's a user area,
			// but not a widget, eg a "virtual" widget.
			var probe = new WidgetItem(_optOwner.get(), _subDirList.peek());
			if(probe.dbFileExists())
			{
				_optItem = Optional.of(probe);
				_subDirList.pollFirst();
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

		// NOTE: do I want to commit to exposing this, or not?
		// Is there ever any relevance to the "central" tokens?
		public List<String> getExtraTokenList()
		{
			return Collections.unmodifiableList(_subDirList);
		}

		public String getLeafSegment()
		{
			return _subDirList.isEmpty() ? null : _subDirList.peekLast();
		}

		public boolean isUserArea()
		{
			return _userArea;
		}

		// True if the Leaf Segment of the request has an extension
		public boolean requestHasExtension()
		{
			var leaf = getLeafSegment();
			return leaf != null && leaf.split("\\.").length > 1;
		}

		public boolean isKnownApiCall()
		{
			return _knownApiCall;
		}

		public Optional<WidgetUser> getOwner()
		{
			return _optOwner;
		}

		public Optional<WidgetItem> getWidgetItem()
		{
			return _optItem;
		}
	}
}

