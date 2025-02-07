
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 

import javax.servlet.http.HttpServletRequest;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.CollUtil;
import net.danburfoot.shared.FileUtils;
import net.danburfoot.shared.CollUtil.*;

import io.webwidgets.core.CoreUtil.*;
import io.webwidgets.core.WidgetOrg.*;
import io.webwidgets.core.AuthLogic.*;

public class DataServer
{
	private static final String ASSET_INCLUDE_COMPLETE = "wwio_asset_include_complete";
	
	public enum DataIncludeArg
	{
		tables("Comma-separated list of table names to include. By default, include all tables in the widget"),
		
		username("Username of widget owner. Current user must have at least read permission for the widget. Defaults to current owner"),
		
		widgetname("Name of the widget to include. Default is determined based on the URL of the browser request"),

		no_data("Do not actually serve any data. This can be useful to reduce bandwidth for write-only pages"),

		view_prefixes("Comma-separated list of view prefixes to be used for these lookups. If a prefix matches multiple view/table pairs, you will get multiple views"),
		
		from_url("If true, pull any valid DataIncludeArgs from the request URL. Do not overwrite args in the wisp tag. This enables a simple form of dynamic loading. Default false"),

		filter_column("Name of column to filter results by. If present, you must also include target_value argument"),

		target_value("Desired value of filter column to search for. May only be present if filter_column is present"),

		okay_if_absent(
			"By default, system will throw an error if a table is requested that is not present. " + 
			"Set this to true to suppress the error"); 
		
		public final String docStr; 
		
		DataIncludeArg(String ds) 
		{
			docStr = ds;
		}
	}
	
	public static final Set<String> OKAY_ARG_SET = Util.map2set(Util.listify(DataIncludeArg.values()), dia -> dia.toString());
	
	// Get widget from request.
	// Get user from request, authenticate.
	// Include all tables for widget.
	// Only the basic include() and include(request, ...) are now supported, others removed in favor of 
	// using appropriate DataIncludeArg options
	public static String include(HttpServletRequest request)
	{
		return include(request, "");
	}
	
	public static String include(HttpServletRequest request, String query)
	{
		Map<DataIncludeArg, String> argmap = parseQuery2DargMap(query);
		return LegacyServerUtil.build(request, argmap).include();
	}

	static Map<DataIncludeArg, String> parseQuery2DargMap(String paramstr)
	{
		if(paramstr.trim().isEmpty())
			{ return Collections.emptyMap(); }

		Map<DataIncludeArg, String> mymap = Util.treemap();

		String[] terms = paramstr.trim().split("&");

		for(String kv : terms)
		{
			String[] tokens = kv.split("=");

			Util.massert(tokens.length == 2, 
				"Attempt to use invalid Key=Value term %s, all DataServer include parameters must follow this convention", kv);

			try {
				DataIncludeArg diarg = DataIncludeArg.valueOf(tokens[0]);
				Util.massert(!mymap.containsKey(diarg), "Duplicate DataServer include argument __%s__", diarg);
				mymap.put(diarg, tokens[1]);

			} catch (IllegalArgumentException ilex) {
				Util.massert(false, 
					"Invalid DataServer include argument %s, options are %s", tokens[0], Util.listify(DataIncludeArg.values()));
			}
		}

		return mymap;
	}
	
	public abstract static class ServerUtilCore
	{
		private final Map<DataIncludeArg, String> _dargMap;
		
		protected WidgetItem _theItem;
		
		// Base table name -> query target
		// query target is either just the base, or an overlay view
		protected Map<String, String> _base2Target;

		protected boolean _noDataMode = false;

		protected Optional<String> _fullViewName = Optional.empty();

		protected Optional<Pair<String, Object>> _optFilterTarget = Optional.empty();


		protected ServerUtilCore(Map<DataIncludeArg, String> amap)
		{
			_dargMap = amap;
		}

		protected abstract Optional<WidgetItem> lookupPageWidget();

		protected abstract Optional<WidgetUser> getPageAccessor();

		protected abstract void markIncludeComplete(boolean global);

		protected abstract boolean shouldPerformInclude(boolean global);

		// If true, include the script tags for the auto-include JS file,
		// as well as open/close script tags around the JS
		// In other words, when true, the include(...) produces something that can go into the
		// head section of a document on its own, if false, it is pure JS.
		protected boolean coreIncludeScriptTag()
		{
			return true;
		}

		private void onDemandSetup() throws WidgetRequestException
		{
			if(_base2Target != null)
				{ return; }

			// First, find the page from the request URL. This serves as default
			// Rule: must have a valid Widget page to request Widget data
			Optional<WidgetItem> pageWidget = lookupPageWidget();
			if(!pageWidget.isPresent())
			{
				throw new WidgetRequestException("All Widget data requests must come from some widget");
			}
					
			
			// The owner of the widget that we are requesting.
			// This is NOT necessarily the user who is logged-in
			WidgetUser wdgOwner;
			{
				Optional<String> optuser = getArg(DataIncludeArg.username);
				
				if(optuser.isPresent())
				{
					try 
						{ wdgOwner = WidgetUser.valueOf(optuser.get());}
					catch (Exception ex) 
						{ throw new WidgetRequestException("No user named: " + optuser.get()); }
				} else {
					// Default to the owner of the widget
					wdgOwner = pageWidget.get().theOwner;
				}
			}
			

			// Option to request data from Widget A in Widget B
			{
				Optional<String> wdgname = getArg(DataIncludeArg.widgetname);

				if(wdgname.isPresent())
				{
					Set<String> okset = Util.map2set(WidgetItem.getUserWidgetList(wdgOwner), wdg -> wdg.theName);
					if(!okset.contains(wdgname.get()))
					{
						String mssg = Util.sprintf("No widget with name %s found for user %s", wdgname.get(), wdgOwner);
						throw new WidgetRequestException(mssg);
					}
					
					_theItem = new WidgetItem(wdgOwner, wdgname.get()); 
				} else {
					// Default to this
					_theItem = pageWidget.get();
				}
			}

			Util.massert(_theItem.dbFileExists(), "Widget DB %s not found", _theItem);

			// By default, you are going to get all the tables  in a widget
			Set<String> tableset = _theItem.getDbTableNameSet();
			
			// Option to slim down the amount of data you request by specifying only a few tables
			// Idea here is to reduce bandwidth and load time if you don't need all the data in a widget
			{
				Optional<String> tableStr = getArg(DataIncludeArg.tables);

				if(tableStr.isPresent())
				{
					String[] tabs = tableStr.get().split(",");
					
					for(String t : tabs)
					{
						if(!tableset.contains(t))
						{
							String mssg = Util.sprintf("Widget %s does not contain table %s, options are %s", _theItem, t, tableset);
							throw new WidgetRequestException(mssg);
						}
					}
					
					tableset = Util.setify(tabs);
				}
			}

			_base2Target = Util.map2map(tableset, tbl -> tbl, tbl -> tbl);

			{
				Optional<String> viewpref = getArg(DataIncludeArg.view_prefixes);
				
				if(viewpref.isPresent())
				{
					Set<String> viewset = _theItem.getDbViewNameSet();
					for(String pref : viewpref.get().split(","))
					{
						Set<String> baseswap = lookupBaseViewSwap(_base2Target, viewset, pref);
						Util.massert(baseswap.size() >= 1, 
							"No valid base tables were found for prefix %s. Base tables are %s, views are %s", 
							pref, _base2Target.keySet(), viewset);

						// For the matched base table names, set the query target to be the view
						for(String base : baseswap)
							{ _base2Target.put(base, composeViewName(pref, base)); }
					}
				}
			}


			{
				Optional<String> noData = getArg(DataIncludeArg.no_data);

				if(noData.isPresent())
				{
					if(!noData.get().equals(true+"")) 
					{
						String mssg = Util.sprintf("When using the no-data option, the argument must be the literal string 'true', found %s", noData.get());
						throw new WidgetRequestException(mssg);
					}

					_noDataMode = true;
				}
			}

			{
				Optional<String> fc = getArg(DataIncludeArg.filter_column);
				Optional<String> tv = getArg(DataIncludeArg.target_value);

				Util.massert(fc.isPresent() == tv.isPresent(),
					"If filter_column argument is present, target value argument must be present and vice versa");

				if(fc.isPresent())
					{ _optFilterTarget = Optional.of(Pair.build(fc.get(), tv.get())); }
			}

			AuthChecker checker = AuthChecker.build().directSetAccessor(getPageAccessor()).directDbWidget(_theItem);

			// In theory, we could allow read here if noDataMode is set. But the only reason to set noDataMode
			// is so that you can WRITE data to the widget, and you can never read if you can't also write
			if(!checker.allowRead())
			{
				String mssg = Util.sprintf("User %s does not have read permissions for widget %s", getPageAccessor(), _theItem);
				throw new WidgetRequestException(mssg);
			}
		}

		private Optional<String> getArg(DataIncludeArg diarg)
		{
			return Optional.ofNullable(_dargMap.get(diarg));
		}


		private void maybeGetAssetInclude(StringBuilder sb, boolean global)
		{
			if(shouldPerformInclude(global))
			{
				sb.append(global ? getGlobalInclude() : AutoInclude.getUserAutoInclude(_theItem));
				markIncludeComplete(global);
			}
		}

		static String getGlobalInclude()
		{
			StringBuilder sb = new StringBuilder();
			sb.append("<!-- Widget Core Asset Include -->\n");

			// These two blocks are very similar, but there are a few subtle differences, that make me feel
			// like it's not worth trying to combine
			{
				// Sort list by file name length for pleasing effect
				List<File> csslist = Util.listify(AdvancedUtil.SHARED_CSS_ASSET_DIR.listFiles());
				CollUtil.sortListByFunction(csslist, cssfile -> cssfile.getName().length());
				
				for(File cssfile : csslist)
				{
					// Shouldn't really have non-CSS code here, but whatever
					if(!cssfile.getName().endsWith(".css"))
						{ continue; }
					
					long modtime = cssfile.lastModified();
					
					String url = Util.sprintf("<link rel=\"stylesheet\" href=\"/u/shared/css/%s?modtime=%d\" />\n", cssfile.getName(), modtime);
					
					sb.append(url);
				}
			}


			{
				// Sort list by file name length for pleasing effect
				List<File> jslist = Util.listify(AdvancedUtil.SHARED_JSLIB_ASSET_DIR.listFiles());
				CollUtil.sortListByFunction(jslist, jsfile -> jsfile.getName().length());
				
				for(File jsfile : jslist)
				{
					// SHouldn't really have non-JS code here, but whatever
					if(!jsfile.getName().endsWith(".js"))
						{ continue; }
					
					long modtime = jsfile.lastModified();
					
					String url = Util.sprintf("<script src=\"/u/shared/jslib/%s?modtime=%d\"></script>\n", jsfile.getName(), modtime);
					
					sb.append(url);
				}
			}
			
			sb.append("<!-- End Core Asset Include -->\n\n\n");
			return sb.toString();
		}



		public String include()
		{
			boolean okay2skip = (""+true).equals(_dargMap.get(DataIncludeArg.okay_if_absent));
						
			try 
				{ onDemandSetup(); }
			catch (WidgetRequestException wrex) 
			{
				if(okay2skip)
				{
					String mssg = Util.sprintf("<!-- Widget Serve command failed with message : %s -->", wrex.getMessage());
					return mssg;
				}
				
				throw wrex;
			}

			StringBuilder sb = new StringBuilder();
			maybeGetAssetInclude(sb, true);
			sb.append(composeScriptInfo());
			maybeGetAssetInclude(sb, false);
			return sb.toString();
		}


		String composeScriptInfo()
		{
			// This should be redundant at this point, I have already checked it
			// But paranoia is good
			AuthChecker checker;
			{
				var accessor = getPageAccessor();
				checker = AuthChecker.build().directDbWidget(_theItem).directSetAccessor(accessor);
				Util.massert(checker.allowRead(),
					"Access denied, user %s lacks permissions to read data from widget %s", accessor, _theItem);
			}

			return composeDirectLoadTag();
		}

		private String composeDirectLoadTag()
		{
			var dargcopy = new HashMap<>(_dargMap);

			if(!dargcopy.containsKey(DataIncludeArg.username))
				{ dargcopy.put(DataIncludeArg.username, _theItem.theOwner.toString()); }

			if(!dargcopy.containsKey(DataIncludeArg.widgetname))
				{ dargcopy.put(DataIncludeArg.widgetname, _theItem.theName); }

			List<String> kvlist = Util.map2list(dargcopy.entrySet(),
				pr -> Util.sprintf("%s=%s", pr.getKey(), pr.getValue()));

			String tagstr = Util.join(kvlist, "&");

			return Util.sprintf("<script src=\"/u/directload?%s\"></script>", tagstr);
		}
	}


	static class LegacyServerUtil extends ServerUtilCore
	{

		public static final String GLOBAL_INCLUDE_COMPLETE = "GlobalAsestIncDone";

		public static final String USER_AUTO_INCLUDE_COMPLETE = "UserAutoIncludeDone";

		private final HttpServletRequest _theRequest;
		
		private LegacyServerUtil(HttpServletRequest req, Map<DataIncludeArg, String> amap)
		{
			super(amap);

			_theRequest = req;
		}
		
		public static LegacyServerUtil build(HttpServletRequest req)
		{
			return build(req, Collections.emptyMap());
		}
		
		public static LegacyServerUtil build(HttpServletRequest req, Map<DataIncludeArg, String> amap)
		{
			return new LegacyServerUtil(req, amap);
		}
		
		@Override
		protected Optional<WidgetUser> getPageAccessor()
		{
			// July 2023: no longer require a logged-in user
			return AuthLogic.getLoggedInUser(_theRequest);
		}

		@Override
		protected boolean shouldPerformInclude(boolean global)
		{
			return !isIncludeComplete(global);
		}

		private boolean isIncludeComplete(boolean global)
		{
			String attname = global ? GLOBAL_INCLUDE_COMPLETE : USER_AUTO_INCLUDE_COMPLETE;
			String already = (String) _theRequest.getAttribute(attname);
			return (true+"").equals(already);
		}

		@Override
		protected void markIncludeComplete(boolean global)
		{
			String attname = global ? GLOBAL_INCLUDE_COMPLETE : USER_AUTO_INCLUDE_COMPLETE;
			_theRequest.setAttribute(attname, true+"");
		}

		@Override
		protected Optional<WidgetItem> lookupPageWidget()
		{
			return WebUtil.lookupWidgetFromPageUrl(_theRequest);
		}
	}


    // This thing is a weird contraption that might not actually be necessary
    // It seems to be required because of the way the old DataServer.include(...) statements
    // "mark" that the inclusion of the core JS files is complete
    public static class WispServerUtil extends DataServer.ServerUtilCore
    {
        final Optional<WidgetUser> pageAccessor;

        final WidgetItem pageItem;

        private boolean _doGlobalInclude = false;

        private boolean _doUserInclude = false;
        
        public WispServerUtil(Optional<WidgetUser> accessor, WidgetItem pitem, Map<DataIncludeArg, String> dargmap)
        {
            super(dargmap);

            pageAccessor = accessor;

            pageItem = pitem;
        }
        
        void setGlobalInclude()
        {
            _doGlobalInclude = true;
        }

        void setUserInclude()
        {
            _doUserInclude = true;
        }
        
        @Override
        protected Optional<WidgetUser> getPageAccessor()
        {
            return pageAccessor;
        }


        @Override
        protected boolean shouldPerformInclude(boolean global)
        {
            // return _includeComplete;
            return global ? _doGlobalInclude : _doUserInclude;
        }

        @Override
        protected void markIncludeComplete(boolean global)
        {
            boolean relbit = global ? _doGlobalInclude : _doUserInclude;
            Util.massert(relbit, "Marked include complete for global=%s, but this tag was not configured to include it!!");
        }

        @Override
        protected Optional<WidgetItem> lookupPageWidget()
        {
            return Optional.of(pageItem);
        }
    }

	private static Set<String> lookupBaseViewSwap(Map<String, String> base2view, Set<String> viewset, String prefix)
	{
		return base2view.keySet()
					.stream()
					.filter(base -> viewset.contains(composeViewName(prefix, base)))
					.collect(CollUtil.toSet());
	}

	private static Map<String, String> getBase2ViewMap(Set<String> nameset, Set<String> viewset, List<String> prefixes)
	{
		Map<String, String> result = Util.treemap();

		for(String base : nameset)
		{
			Optional<String> optview = findViewPrefixMatch(base, viewset, prefixes);
			result.put(base, optview.orElse(base));
		}

		return result;
	}

	private static Optional<String> findViewPrefixMatch(String basename, Set<String> viewset, List<String> prefixes)
	{
		return prefixes
					.stream()
					.map(pref -> composeViewName(pref, basename))
					.filter(view -> viewset.contains(view))
					.findFirst();
	}

	private static String composeViewName(String prefix, String basename)
	{
		return String.format("%s_%s", prefix, basename);
	}
	
	
	public static class WidgetRequestException extends RuntimeException
	{
		public WidgetRequestException(String mssg)
		{
			super(mssg);
		}
	}


	public static class AutoInclude
	{
		public static final String AUTO_INCLUDE_PREFIX = "My";

		public static final String FAVICON_FILE_NAME = "MyFavIcon";
		
		public static final List<String> AUTO_INCLUDE_SUFFIX = Util.listify(".js", ".css", ".html");


		// This is an extra string that must be included in .html files for auto-inclusion
		public static final String HTML_HEADER_TAG = "Header";

		// Send the auto-include JS and CSS statements for the given dbitem
		// This includes BOTH the material local to the item, as well as the base files
		// Inclusion runs for the OWNER, not the accessor
		// Auto-inclusion does not work for cross-loads, if you need those assets,
		// you should include them directly via script include
		static String getUserAutoInclude(WidgetItem dbitem)
		{
			StringBuilder sb = new StringBuilder();

			// Gotcha - need to request JS auto-include from the Widget - owner, not the logged-in user
			// This feature is tricky, think more about it
			List<String> includeList = AutoInclude.getAutoIncludeStatement(dbitem);
			
			sb.append("\n\n<!-- Custom JS code for user -->\n");
			
			for(String include : includeList) 
			{ 
				sb.append(include);
				sb.append("\n");
			}
			
			sb.append("<!-- End custom JS code for user -->\n\n");
			return sb.toString();
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
	}

} 



