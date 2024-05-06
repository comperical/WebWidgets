
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 

import javax.servlet.http.HttpServletRequest;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.CollUtil;
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
	
	// TODO: remove all the special include operations, these are no longer used

	// Get widget from request.
	// Get user from request, authenticate.
	// Include all tables for widget.
	public static String basicInclude(HttpServletRequest request)
	{
		return includeSub(request, "");
	}
	
	// Get widget from request.
	// Get user from request, authenticate.
	// Include all tables for widget.
	public static String include(HttpServletRequest request)
	{
		return include(request, "");
	}
	
	public static String include(HttpServletRequest request, String query)
	{
		return includeSub(request, query);
	}	
	
	public static String includeIfOkay(HttpServletRequest request, String query)
	{
		Util.massert(!query.contains(DataIncludeArg.okay_if_absent.toString()),
			"By convention, when using this method, do not use okay_if_absent command");
		
		String addtag = DataIncludeArg.okay_if_absent + "=true";
		String augquery = query.trim().isEmpty() ? addtag : query + "&" + addtag;
		return includeSub(request, augquery);
	}
		
	public static String basicIncludeOnly(HttpServletRequest request, String... tables)
	{		
		String tablestr = Util.join(Util.listify(tables), ",");
		String query = Util.sprintf("%s=%s", DataIncludeArg.tables, tablestr);
		return includeSub(request, query);		
	}
	
	private static String includeSub(HttpServletRequest request, String query)
	{
		ArgMap argmap = buildIncludeMap(query);
		
		return ServerUtil
			.build(request, argmap)
			.include();
	}

	static ArgMap buildIncludeMap(String paramstr)
	{
		ArgMap mymap = new ArgMap();
		if(paramstr.trim().isEmpty())
			{ return mymap; }

		String[] terms = paramstr.trim().split("&");

		for(String kv : terms)
		{
			String[] tokens = kv.split("=");

			Util.massert(tokens.length == 2, 
				"Attempt to use invalid Key=Value term %s, all DataServer include parameters must follow this convention", kv);

			try {
				DataIncludeArg diarg = DataIncludeArg.valueOf(tokens[0]);
				Util.massert(!mymap.containsKey(diarg.toString()), "Duplicate DataServer include argument __%s__", diarg);
				mymap.setStr(diarg.toString(), tokens[1]);

			} catch (IllegalArgumentException ilex) {
				Util.massert(false, 
					"Invalid DataServer include argument %s, options are %s", tokens[0], Util.listify(DataIncludeArg.values()));
			}
		}

		return mymap;
	}
	
	
	public static String includeIfAvailable(HttpServletRequest request, String widgetname, String... tables)
	{
		String tablestr = Util.join(Util.listify(tables), ",");
		String query = Util.sprintf("%s=%s&%s=%s&%s=true", 
			DataIncludeArg.widgetname, widgetname, DataIncludeArg.tables, tablestr, DataIncludeArg.okay_if_absent);
		
		return includeSub(request, query);
	}
	

	
	public static void markAssetIncludeComplete(HttpServletRequest request)
	{
		request.setAttribute(ASSET_INCLUDE_COMPLETE, true+"");
	}
	

	public abstract static class ServerUtilCore
	{
		private final ArgMap _argMap;
		
		protected WidgetItem _theItem;
		
		// Base table name -> query target
		// query target is either just the base, or an overlay view
		private Map<String, String> _base2Target;

		private boolean _noDataMode = false;

		private Optional<String> _fullViewName = Optional.empty();

		private Optional<Pair<String, Object>> _optFilterTarget = Optional.empty();

		// TODO: refactor this to use a normal Map<DataIncludeArg, String>
		protected ServerUtilCore(ArgMap amap)
		{
			_argMap = amap;
		}

		protected abstract Optional<WidgetItem> lookupPageWidget();

		protected abstract Optional<WidgetUser> getPageAccessor();

		protected abstract void markIncludeComplete();

		protected abstract boolean isIncludeComplete();

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
				Optional<String> optuser = _argMap.optGetStr(DataIncludeArg.username.toString());
				
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
				Optional<String> wdgname = _argMap.optGetStr(DataIncludeArg.widgetname.toString());
				if(wdgname.isPresent())
				{
					Set<String> okset = Util.map2set(wdgOwner.getUserWidgetList(), wdg -> wdg.theName);
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

			// TODO: need to put something like this in here
			// Util.massert(_theItem.dbFileExists());

			// By default, you are going to get all the tables  in a widget
			Set<String> tableset = _theItem.getDbTableNameSet();
			
			// Option to slim down the amount of data you request by specifying only a few tables
			// Idea here is to reduce bandwidth and load time if you don't need all the data in a widget
			{
				Optional<String> tableStr = _argMap.optGetStr(DataIncludeArg.tables.toString());
				
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
				Optional<String> viewpref = _argMap.optGetStr(DataIncludeArg.view_prefixes.toString());
				
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
				Optional<String> noData = _argMap.optGetStr(DataIncludeArg.no_data.toString());

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
				Optional<String> fc = _argMap.optGetStr(DataIncludeArg.filter_column.toString());
				Optional<String> tv = _argMap.optGetStr(DataIncludeArg.target_value.toString());

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

		private void maybeGetAssetInclude(StringBuilder sb)
		{
			if(isIncludeComplete())
				{ return; }

			addAssetInclude(sb);
			markIncludeComplete();
		}

		// This is a replacement for the old AssetInclude.jsp_inc file.
		// We don't want to expose end users to that complexity
		private void addAssetInclude(StringBuilder sb)
		{
			sb.append("<!-- Widget Core Asset Include -->\n");


			// These two blocks are very similar, but there are a few subtle differences, that make me feel
			// like it's not worth trying to combine
			{
				// Sort list by file name length for pleasing effect
				List<File> csslist = Util.listify(CoreUtil.SHARED_CSS_ASSET_DIR.listFiles());
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
				List<File> jslist = Util.listify(CoreUtil.SHARED_JSLIB_ASSET_DIR.listFiles());
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
			
			// Gotcha - need to request JS auto-include from the Widget - owner, not the logged-in user
			// This feature is tricky, think more about it
			List<String> includeList = WebUtil.getAutoIncludeStatement(_theItem);
			
			sb.append("<!-- Custom JS code for user -->\n");
			
			for(String include : includeList) 
			{ 
				sb.append(include);
				sb.append("\n");
			}
			
			sb.append("<!-- End custom JS code for user -->\n\n");
		}


		public String include()
		{
			for(String argkey : _argMap.keySet())
			{
				Util.massert(OKAY_ARG_SET.contains(argkey),
					"Invalid DataServer include argument %s, options are %s", argkey, OKAY_ARG_SET);
			}
			
			
			boolean okay2skip = _argMap.getBit("okay_if_absent", false);
			
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
			maybeGetAssetInclude(sb);
			return sb.append(getScriptInfo(getPageAccessor(), _theItem, _base2Target, _noDataMode, _optFilterTarget)).toString();
		}


		private static String getScriptInfo(Optional<WidgetUser> accessor, WidgetItem dbitem, Map<String, String> base2view, boolean nodata, Optional<Pair<String, Object>> filter)
		{
			// This should be redundant at this point, I have already checked it
			// But paranoia is good
			AuthChecker checker = AuthChecker.build().directDbWidget(dbitem).directSetAccessor(accessor);
			Util.massert(checker.allowRead(),
				"Access denied, user %s lacks permissions to read data from widget %s", accessor, dbitem);
			
			List<String> reclist = Util.vector();
			
			for(String onetab : base2view.keySet())
			{
				LiteTableInfo LTI = new LiteTableInfo(dbitem, onetab, nodata);
				LTI.runSetupQuery();

				if(filter.isPresent())
				{
					if(LTI.getColTypeMap().containsKey(filter.get()._1))
						{ LTI.withColumnTarget(filter.get()._1, filter.get()._2); }
				}
				
				// dogenerate=false
				// This will only generate the code if it's not available.
				LTI.maybeUpdateJsCode(false);
				
				Optional<File> jsfile = LTI.findAutoGenFile();
				Util.massert(jsfile.isPresent(), 
					"AutoGen JS file not present even after we asked to create it if necessary!!!");
				
				reclist.add(Util.sprintf("<script src=\"%s\"></script>", LTI.getWebAutoGenJsPath()));
				
				reclist.add("<script>");
				reclist.addAll(LTI.composeDataRecSpool(base2view.get(onetab)));
				
				// If the user has read-only access to the table, record that info
				if(!checker.allowWrite())
				{
					reclist.add("");
					reclist.add("// table is in read-only access mode");
					reclist.add(String.format("W.__readOnlyAccess.push(\"%s\");", onetab));
					reclist.add("");
				}
				
				reclist.add("</script>");
			}

			reclist.add("<script>");
			reclist.add("// Data Loading is now complete ");
			reclist.add("W.__DATA_LOAD_COMPLETE = true;");

			reclist.add("// Check for bad index creation in user code");
			reclist.add("W.__badIndexCreationCheck();");
			reclist.add("</script>");
			
			return Util.join(reclist, "\n");
		}
	}


	static class ServerUtil extends ServerUtilCore
	{

		private final HttpServletRequest _theRequest;
		
		private ServerUtil(HttpServletRequest req, ArgMap amap)
		{
			super(amap);

			_theRequest = req;
		}
		
		public static ServerUtil build(HttpServletRequest req)
		{
			return build(req, new ArgMap());
		}
		
		public static ServerUtil build(HttpServletRequest req, ArgMap amap)
		{
			return new ServerUtil(req, amap);
		}
		
		@Override
		protected Optional<WidgetUser> getPageAccessor()
		{
			// July 2023: no longer require a logged-in user
			return AuthLogic.getLoggedInUser(_theRequest);
		}

		@Override
		protected boolean isIncludeComplete()
		{
			String already = (String) _theRequest.getAttribute(ASSET_INCLUDE_COMPLETE);
			return (true+"").equals(already);
		}

		@Override
		protected void markIncludeComplete()
		{
			markAssetIncludeComplete(_theRequest);
		}

		@Override
		protected Optional<WidgetItem> lookupPageWidget()
		{
			return WebUtil.lookupWidgetFromPageUrl(_theRequest);
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
} 



