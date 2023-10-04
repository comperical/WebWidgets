
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 

import javax.servlet.http.HttpServletRequest;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.CollUtil;

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
	
	static class ServerUtil
	{

		private final HttpServletRequest _theRequest;
			
		private final ArgMap _argMap;
		
		private WidgetItem _theItem;
		
		// Base table name -> query target
		// query target is either just the base, or an overlay view
		private Map<String, String> _base2Target;

		private boolean _noDataMode = false;

		private Optional<String> _fullViewName = Optional.empty();
		
		private ServerUtil(HttpServletRequest req, ArgMap amap)
		{
			_theRequest = req;
			
			_argMap = amap;
		}
		
		public static ServerUtil build(HttpServletRequest req)
		{
			return build(req, new ArgMap());	
		}
		
		public static ServerUtil build(HttpServletRequest req, ArgMap amap)
		{
			return new ServerUtil(req, amap);
		}
		
		private Optional<WidgetUser> getLoggedInUser()
		{
			// July 2023: no longer require a logged-in user
			return AuthLogic.getLoggedInUser(_theRequest);
		}
		
		private void onDemandSetup() throws WidgetRequestException
		{
			if(_base2Target != null)
				{ return; }
			

			// First, find the page from the request URL. This serves as default
			// Rule: must have a valid Widget page to request Widget data
			Optional<WidgetItem> pageWidget = WebUtil.lookupWidgetFromPageUrl(_theRequest);
			if(!pageWidget.isPresent())
			{
				throw new WidgetRequestException("All Widget data requests must come from some widget");
			}
					
			
			// Okay, there is a lot of weird stuff going on here!!!
			// In theory you can request data from another user's widget. 
			WidgetUser wdgOwner;

			// Option to request data from another user's widget
			// As of June 2022, this option is very experimental
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

			AuthChecker checker = AuthChecker.build()
												.userFromRequest(_theRequest)
												.directDbWidget(_theItem);

			// TODO: do we allow this if noDataMode is configured?
			if(!checker.allowRead())
			{
				String mssg = Util.sprintf("User %s does not have read permissions for widget %s", getLoggedInUser(), _theItem);
				throw new WidgetRequestException(mssg);
			}
		}

		private StringBuilder maybeGetAssetInclude()
		{
			StringBuilder sb = new StringBuilder();
			String already = (String) _theRequest.getAttribute(ASSET_INCLUDE_COMPLETE);
			if ((true+"").equals(already))
				{ return sb; }

			addAssetInclude(sb);
			markAssetIncludeComplete(_theRequest);
			return sb;
		}

		// This is a replacement for the old AssetInclude.jsp_inc file.
		// We don't want to expose end users to that complexity
		private void addAssetInclude(StringBuilder sb)
		{
			sb.append("<!-- Widget Core Asset Include -->\n");

			addIncludeInfo(sb, CoreUtil.SHARED_CSS_ASSET_DIR, ".css", "css");
			addIncludeInfo(sb, CoreUtil.SHARED_JSLIB_ASSET_DIR, ".js", "jslib");

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

		private static void addIncludeInfo(StringBuilder sb, File assetdir, String extension, String sharedir)
		{

			// Sort list by file name length for pleasing effect
			List<File> flist = Util.listify(assetdir.listFiles());
			CollUtil.sortListByFunction(flist, myfile -> myfile.getName().length());

			for(File myfile : flist)
			{
				if(!myfile.getName().endsWith(extension))
					{ continue; }

				long modtime = myfile.lastModified();
				
				String url = Util.sprintf("<script src=\"/u/shared/%s/%s?modtime=%d\"></script>\n", sharedir, myfile.getName(), modtime);
				
				sb.append(url);
			}
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

			StringBuilder sb = maybeGetAssetInclude();
			return sb.append(getScriptInfo(getLoggedInUser(), _theItem, _base2Target, _noDataMode)).toString();
		}

		private static String getScriptInfo(Optional<WidgetUser> accessor, WidgetItem dbitem, Map<String, String> base2view, boolean nodata)
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
			
			// This is the old, naive checksum-based data protection code
			/*
			{	
				String cksumkey = dbitem.getCheckSumKey();
				long cksum = dbitem.getDbCheckSum();
				
				reclist.add("<script>");			
				reclist.add("// Widget DB checksum. This can be set multiple times without breaking anything");
				
				// Warning: This variable has to match LiteJsHelper
				reclist.add(Util.sprintf("W.__databaseCheckSum[\"%s\"] = 0;", cksumkey, cksum));
			
				reclist.add("</script>");	
			}
			*/
			
			return Util.join(reclist, "\n");
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



