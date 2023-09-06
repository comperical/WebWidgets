package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 

import javax.servlet.http.HttpServletRequest;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.CollUtil;
import net.danburfoot.shared.FileUtils;

import net.danburfoot.shared.CollUtil.*;
import net.danburfoot.shared.CoreDb.QueryCollector;
import net.danburfoot.shared.CoreDb.ConnectionSource;


import io.webwidgets.core.LifeUtil.*;
import io.webwidgets.core.WidgetOrg.*;

public class LiteTableInfo
{
	public static final String LOAD_SUCCESS_TAG = LiteTableInfo.class.getSimpleName() + "__LOAD_SUCCESS";
	
	public static final String DECODE_URI_SHORTHAND = "__duric";
	
	public static final Set<String> SQLITE_STR_TYPE = Util.setify("varchar", "text");
	
	public enum ExchangeType
	{
		smallint,
		m_int("int"),
		real,
		m_double("double"),
		text,
		varchar;
		
		final String lookupTag;
		
		ExchangeType(String s)
		{
			lookupTag = s == null ? this.toString() : s;
		}
		
		ExchangeType()
		{
			this(null);
		}
	
		public static ExchangeType lookupFromSql(String scolname)
		{
			Set<ExchangeType> hits = Util.filter2set(ExchangeType.values(), et -> scolname.toLowerCase().contains(et.lookupTag));
			
			// Will hit both smallint and int since string overlap.
			if(hits.equals(Util.setify(ExchangeType.smallint, ExchangeType.m_int)))
				{ hits = Util.setify(ExchangeType.smallint); }

			Util.massert(hits.size() > 0, "No ExchangeType found for colname %s", scolname);
			Util.massert(hits.size() == 1, "Multiple exchange types found for colname %s :: %s", scolname, hits);
			
			return hits.iterator().next();
		}
		
		public boolean isJsInteger()
		{
			return this == ExchangeType.smallint || this == ExchangeType.m_int;	
		}
		
		public boolean isJsFloat()
		{
			return this == ExchangeType.real || this == ExchangeType.m_double;	
		}		
	}
	
	public final Pair<WidgetItem, String> dbTabPair;

	private Map<String, String> _colTypeMap = Util.linkedhashmap();
	
	private List<String> _pkeyList = Util.vector();

	private Boolean _isBlobStore = null;

	private final boolean _noDataMode;
	
	
	public LiteTableInfo(WidgetItem widget, String table)
	{
		this(widget, table, false);
	}


	public LiteTableInfo(WidgetItem widget, String table, boolean nodata)
	{
		dbTabPair = Pair.build(widget, table);
				
		Util.massert(table.length() > 0, "Empty table name");
		Util.massert(table.toLowerCase().equals(table),
			"Table names should be lower case");
		String basic = getBasicName();
		_noDataMode = nodata;
	}
	
	public LiteTableInfo(ArgMap onemap)
	{
		WidgetUser wowner = WidgetUser.valueOf(onemap.getStr("wowner"));
		String wname = onemap.getStr("wname");
		String table = onemap.getStr("tablename");
				
		dbTabPair = Pair.build(new WidgetItem(wowner, wname), table);
		
		
		Util.massert(table.length() > 0, "Empty table name");
		Util.massert(table.toLowerCase().equals(table),
			"Table names should be lower case");
		
		// Util.pf("%s\n", dbTabPair);
		String basic = getBasicName();	
		_noDataMode = false;	
	}		

	public void runSetupQuery()
	{
		try {
			Connection conn = dbTabPair._1.createConnection();
			
			String prepsql = Util.sprintf("SELECT * FROM %s LIMIT 2", dbTabPair._2);
			
			PreparedStatement pstmt = conn.prepareStatement(prepsql);
			
			ResultSet rset = pstmt.executeQuery();
			
			ResultSetMetaData rsmd = rset.getMetaData();
			
			popColTypeMap(rsmd);
			
			popKeyList(conn);
			
			conn.close();

			_isBlobStore = BlobDataManager.isBlobStorageTable(_colTypeMap.keySet());
			
		} catch (Exception ex) {
			
			throw new RuntimeException(ex);	
		}
	}
	
	
	
	public void printInfo()
	{
		Util.pf("Col2Type map: %s\n", _colTypeMap);
		
		Util.pf("PKey List: %s\n", _pkeyList);
	}
	
	private void popColTypeMap(ResultSetMetaData rsmd) throws SQLException
	{
		for(int ci : Util.range(rsmd.getColumnCount()))
		{
			String colname = rsmd.getColumnName(ci+1);
			
			String classname = rsmd.getColumnTypeName(ci+1);
			
			ExchangeType etype = ExchangeType.lookupFromSql(classname);
			
			_colTypeMap.put(colname, classname);
		}			
	}
	
	ExchangeType getColumnExType(String colname)
	{	
		String classname = _colTypeMap.get(colname);
		Util.massert(classname != null, 
			"Unknown column %s, options are %s", colname, _colTypeMap.keySet());
		
		return ExchangeType.lookupFromSql(classname);
	}
	
	private void popKeyList(Connection conn) throws SQLException
	{
		String pragsql = Util.sprintf("PRAGMA table_info(%s)", dbTabPair._2);
		
		PreparedStatement pstmt = conn.prepareStatement(pragsql);
		
		ResultSet rset = pstmt.executeQuery();
		
		while(rset.next())
		{
			String colname = rset.getString(2);
			
			int ispkey = rset.getInt(6);
			
			if(ispkey > 0)
				{ _pkeyList.add(colname); }
		}
		
		conn.close();
		
		Util.massert(!_pkeyList.isEmpty(), 
			"Found no Primary Key for table %s", dbTabPair._2);
	}
	
	public WidgetItem getWidget()
	{
		return dbTabPair._1;	
	}
	
	public String getWidgetOwner()
	{
		return dbTabPair._1.theOwner.toString();	
	}
	
	public String getWidgetName()
	{
		return dbTabPair._1.theName;	
	}
	
	public String getBasicName()
	{
		return LifeUtil.snake2CamelCase(dbTabPair._2);	
	}
	
	public String getSimpleTableName()
	{
		return dbTabPair._2;	
	}
	
	public String getRecordName()
	{
		return getBasicName() + "Item";	
	}
	
	// TODO: remove references to this in actual hand-written code,
	// then rename to something like __XyzTable;
	public String getCollectName()
	{
		return getBasicName() + "Table";	
		
	}
	
	public List<String> getPkeyList()
	{
		return Collections.unmodifiableList(_pkeyList);	
	}
	
	public ConnectionSource getDbRef()
	{
		return dbTabPair._1;		
	}
	
	public Map<String, String> getColTypeMap()
	{
		return Collections.unmodifiableMap(_colTypeMap);	
		
	}
	
	public String getCsvPkeyStr()
	{
		return Util.join(_pkeyList, ", ");	
	}
	
	// Okay, this method can't be offloaded to JS creator, it needs to run every time.
	public List<String> composeDataRecSpool()
	{
		return composeDataRecSpool(dbTabPair._2);
	}
	
	List<String> composeDataRecSpool(String querytarget)
	{
		Util.massert(!_colTypeMap.isEmpty(), 
			"You must call runQuery before creating the data, sorry bad naming");
		
		List<String> reclist = Util.vector();
				
		reclist.add("");
		reclist.add("");
		reclist.add("");
		
		reclist.addAll(composeJsonRepList(querytarget));
		
		return reclist;			
	}
	
	private List<String> composeJsonRepList(String querytarget)
	{
		Util.massert(!_colTypeMap.isEmpty(), 
			"You must call runQuery before creating the data, sorry bad naming");
		
		
		List<ArgMap> recordList = Collections.emptyList();

		if(!_noDataMode) 
		{
			QueryCollector bigcol = QueryCollector.buildAndRun("SELECT * FROM " + querytarget, dbTabPair._1);

			recordList = bigcol.getArgMapList();
		}

		List<String> jsonitems = Util.vector();
		
		for(ArgMap onemap : recordList)
		{
			List<String> arglist = _colTypeMap.keySet()
							.stream()
							.map(onekey -> getArrayRep(onemap, onekey))
							.collect(CollUtil.toList());
			
			// reclist.add(Util.sprintf("%sTable.register(new %sItem(%s));", getBasicName(), getBasicName(), Util.join(arglist, ", ")));
			StringBuilder sb = new StringBuilder();
			sb.append("\t[ ");
			sb.append(Util.join(arglist, ", "));
			sb.append("] ");
			
			// String jsonitem = Util.sprintf("\t{ %s }", Util.join(arglist, ", "));
			jsonitems.add(sb.toString());
		}
		
		List<String> reclist = Util.vector();

		String converter = Util.sprintf("__arr2Dict%s", getBasicName());
		
		{
			List<String> cols = Util.vector(_colTypeMap.keySet());
			
			reclist.add(Util.sprintf("function %s(arr) {", converter));
			reclist.add("\tconst d = {};");
			
			int idx = 0;
			
			for(String col : _colTypeMap.keySet())
			{
				String assign = Util.sprintf("arr[%d]", idx);
				if(SQLITE_STR_TYPE.contains(_colTypeMap.get(col).toLowerCase()))
					{ assign = Util.sprintf("decodeURIComponent(%s)", assign); }
				
				reclist.add(Util.sprintf("\td['%s'] = %s;", col, assign));				
				idx++;
			}
			
			reclist.add("\treturn d;");
			reclist.add("}");
		}
		
		
		reclist.add("[");
		for(int i : Util.range(jsonitems)) 
		{
			String jsitem = jsonitems.get(i);
			String maybecomma = i < jsonitems.size() - 1 ? " , " : "";
			reclist.add(jsitem + maybecomma);
		}
		reclist.add(Util.sprintf("].forEach(function(myrec) { \n\t%sTable.register(W.buildItem(\"%s\", %s(myrec)));\n});", 
			getBasicName(), dbTabPair._2, converter));
		
		reclist.add("");
		reclist.add("// " + LOAD_SUCCESS_TAG);
		
		return reclist;			
	}	
	
	private String getArrayRep(ArgMap onemap, String onecol)
	{
		String s = onemap.getStr(onecol);
		Util.massert(s != null, 
			"Found null value for column %s, this system cannot handle nulls, use empty strings", onecol);
		
		// Need to put quotes around string types
		if(!SQLITE_STR_TYPE.contains(_colTypeMap.get(onecol).toLowerCase()))
			{ return s; }

		StringBuilder sb = new StringBuilder();	
		sb.append("\"");
		sb.append(myEncodeURIComponent(s));
		sb.append("\"");		
		return sb.toString();
	}	
	
	private String getJsonRep(ArgMap onemap, String onecol)
	{
		StringBuffer sb = new StringBuffer();
		
		sb.append(onecol);
		sb.append(" : ");
		
		
		if(SQLITE_STR_TYPE.contains(_colTypeMap.get(onecol).toLowerCase()))
		{
			String s = onemap.getStr(onecol);
			
			Util.massert(s != null, 
				"Found null value for column %s, this system cannot handle nulls, use empty strings", onecol);
			
			sb.append(DECODE_URI_SHORTHAND);
			sb.append("(\"");
			sb.append(myEncodeURIComponent(onemap.getStr(onecol)));
			sb.append("\")");
		} else {
			
			sb.append(onemap.getStr(onecol));
		}
		
		return sb.toString();
	}
	
	// http://stackoverflow.com/questions/607176/java-equivalent-to-javascripts-encodeuricomponent-that-produces-identical-outpu		
	/*
	public static String encodeURIComponent(String s)
	{
		return LifeUtil.encodeURIComponent(s);
	}  
	*/
	
	void processAjaxOp(ArgMap argmap)
	{
		// TODO: this is going to probably cause some scalability issues
		// when we get to 100000's of tables
		SyncController editcontrol = getEditController(dbTabPair._1);
		
		synchronized(editcontrol)
		{
			String ajaxop = argmap.getStr("ajaxop");
			
			if(ajaxop.equals("upsert"))
			{
				doUpsert(argmap);
				return;
			}
			
			if(ajaxop.equals("delete"))
			{
				doDelete(argmap);
				return;
			}
			
			Util.massert(false, "Unknown AjaxOp %s", ajaxop);
		}
	}
	
	public boolean isBlobStoreTable()
	{
		Util.massert(_isBlobStore != null, "Must call runSetupQuery first");

		return _isBlobStore;
	}

	public void doUpsert(ArgMap argmap)
	{
		Util.massert(argmap.getStr("tablename").equals(dbTabPair._2),
			"Wrong table name: %s vs %s", argmap.getStr("tablename"), dbTabPair._2);
		
		LinkedHashMap<String, Object> paymap = getPayLoadMap(argmap, _colTypeMap.keySet());

		// If the payload has blob data, this operation swaps out the blob data and writes the file to disk and S3
		// What gets entered into the SQLite table is the blob coords, not the blob data itself
		BlobDataManager.optProcessBlobInput(this, paymap);
		
		CoreDb.upsertFromRecMap(dbTabPair._1, dbTabPair._2, _pkeyList.size(), paymap);
	}
	
	public void doDelete(ArgMap argmap)
	{
		Util.massert(argmap.getStr("tablename").equals(dbTabPair._2),
			"Wrong table name: %s vs %s", argmap.getStr("tablename"), dbTabPair._2);
		
		// TODO: do I want to allow arbitrary deletes? Not for now.
		LinkedHashMap<String, Object> paymap = getPayLoadMap(argmap, _pkeyList);

		BlobDataManager.optProcessDelete(this, paymap);
		
		CoreDb.deleteFromColMap(dbTabPair._1, dbTabPair._2, paymap);
	}		
	
	
	private LinkedHashMap<String, Object> getPayLoadMap(ArgMap argmap, Collection<String> arglist)
	{
		LinkedHashMap<String, Object> paymap = Util.linkedhashmap();
		
		// TODO: do I want to allow arbitrary deletes? Not for now.
		for(String onecol : arglist)
		{
			String onetype = _colTypeMap.get(onecol);
			
			Object payload = getPayLoad(onecol, onetype, argmap);
			
			paymap.put(onecol, payload);
		}			
		
		return paymap;
	}
	
	static Object getPayLoad(String onecol, String onetype, ArgMap recmap)
	{
		try 
		{
			switch(onetype)
			{
				case "INT": return recmap.getInt(onecol);
				case "INTEGER" : return recmap.getInt(onecol);
				case "TINYINT": return recmap.getInt(onecol);
				case "SMALLINT": return recmap.getInt(onecol);
				case "VARCHAR": return recmap.getStr(onecol);
				case "TEXT"   : return recmap.getStr(onecol);
				case "STRING": return recmap.getStr(onecol);
				case "REAL" : return recmap.getDbl(onecol);
				case "DOUBLE": return recmap.getDbl(onecol);
				default: throw new RuntimeException("Unknown Type: " + onetype);
			}
		} catch (NumberFormatException nfex) {

			String input = recmap.get(onecol);
			throw new ArgMapNumberException(onecol, onetype, input);
		}
	}

	static Class getJavaTypeFromLite(String litetype)
	{
        ArgMap mymap = new ArgMap();
        mymap.put("dummy", "454534");

        Object lookup = LiteTableInfo.getPayLoad("dummy", litetype, mymap);
        return lookup.getClass();
	}

	public String getWebAutoGenJsPath()
	{
		Optional<File> jsfile = findAutoGenFile();
		Util.massert(jsfile.isPresent(),
			"AytoGen JS file must be present at this point!!");
		
		String pref = "/u/" + dbTabPair._1.theOwner.toString();
		
		return Util.sprintf("%s/autogenjs/%s/%s", pref, dbTabPair._1.theName, jsfile.get().getName());
	}
	
	List<String> maybeUpdateJsCode(boolean dogenerate)
	{
		Optional<File> prevfile = findAutoGenFile();
		// Normal situation - file exists and we aren't asked to generate it.
		if(prevfile.isPresent() && !dogenerate)
			{ return Util.listify(); }
		
		
		CodeGenerator ncgen = new CodeGenerator(this);
		List<String> newsrc = ncgen.getCodeLineList();
		
		if(oldVersionOkay(prevfile, newsrc))
		{
			String mssg = Util.sprintf("New version of AutoGen code identical to previous for DB %s\n", dbTabPair._2);
			return Util.listify(mssg);
		}
		
		int oldversion = prevfile.isPresent() ? this.getVersionFromPath(prevfile.get()) : 0;
		String newjspath = this.getAutoGenProbePath(oldversion+1);					
		
		FileUtils.getWriterUtil()
				.setFile(newjspath)
				.writeLineListE(newsrc);
		
		List<String> loglist = Util.vector();
		loglist.add(Util.sprintf("Wrote autogen code to path %s\n", newjspath));
		
		if(prevfile.isPresent())
		{
			prevfile.get().delete();
			loglist.add(Util.sprintf("Deleted old file %s\n", prevfile.get()));	
		}
		
		return loglist;		
	}
	
	// TODO: this does not go here
	static boolean oldVersionOkay(Optional<File> prevfile, List<String> newsrc)
	{
		if(!prevfile.isPresent())
			{ return false; }
		
		List<String> oldsrc = FileUtils.getReaderUtil()
							.setFile(prevfile.get())
							.setTrim(false)
							.readLineListE();

		return oldsrc.equals(newsrc);
	}
		
	String getAutoGenProbePath(int version)
	{
		File wdir = WebUtil.getAutoGenJsDir(dbTabPair._1);
		return Util.sprintf("%s/%s__%03d.js", wdir.toString(), getBasicName(), version);
	}
	
	// TODO: need to get rid of this hacky way of upgrading the versions
	// Just put the file modtime in there, Jesus
	int getVersionFromPath(File thefile)
	{	
		String fname = thefile.getName();
		String[] toks = fname.split("__");
		String justnum = LifeUtil.peelSuffix(toks[1], ".js");
		return Integer.valueOf(justnum);
	}

	private boolean matchesFileName(File thefile)
	{
		String fname = thefile.getName();
		String[] toks = fname.split("__");
		return getBasicName().equals(toks[0]);
	}	
	
	public Optional<File> findAutoGenFile()
	{
		File wdir = WebUtil.getAutoGenJsDir(dbTabPair._1);
		Util.massert(wdir.exists() && wdir.isDirectory(),
			"AutoGen JS Directory does not exist or is not directory %s", wdir);
		
		List<File> hits = Util.filter2list(wdir.listFiles(), f -> matchesFileName(f));
		Util.massert(hits.size() <= 1, "Found multiple versions of AutoGen JS file : %s", hits);
		
		return hits.isEmpty() ? Optional.empty() : Optional.of(hits.get(0));
	}



	private static Map<String, SyncController> __SYNC_MAP = Util.treemap();
	
	private static synchronized SyncController getEditController(WidgetItem witem) 
	{
		String pathkey = witem.getLocalDbPath();
		
		__SYNC_MAP.putIfAbsent(pathkey, new SyncController());

		return __SYNC_MAP.get(pathkey);
	}
	
	private static class SyncController {}
	
	
	// http://stackoverflow.com/questions/607176/java-equivalent-to-javascripts-encodeuricomponent-that-produces-identical-outpu		
	// NB: this method may have performance implications when used excessively.
	private static String myEncodeURIComponent(String s)
	{
		try
		{
			// Okay, Java's URL Encoder is different from the JS encodeURIComponent
			// in that a couple of things aren't escaped: !
			
			String encoded = java.net.URLEncoder.encode(s, "UTF-8");
			/*
			result = encoded
							.replaceAll("\\+", "%20")
							.replaceAll("\\%21", "!")
							.replaceAll("\\%27", "'")
							.replaceAll("\\%28", "(")
							.replaceAll("\\%29", ")")
							.replaceAll("\\%7E", "~");
							
			result = java.net.URLEncoder.encode(s, "UTF-8")
							.replace("+", "%20")
							.replace("%21", "!")
							.replace("%27", "'")
							.replace("%28", "(")
							.replace("%29", ")")
							.replace("%7E", "~");	
							
			*/
			
			return fastReplace(encoded);
						
			// String other = LifeUtil.encodeURIComponent(s);
			
			// Util.massert(result.equals(other),
			//	"Got result/other: \n\t%s\n\t%s", result, other);
		}
		
		// This exception should never occur.
		catch (UnsupportedEncodingException e)
		{
			throw new RuntimeException(e);
		}
	} 	
	
	private static Map<String, Character> _REPLACE_MAP = Util.treemap();
	
	static {
		_REPLACE_MAP.put("21", '!');
		_REPLACE_MAP.put("27", '\'');
		_REPLACE_MAP.put("28", '(');
		_REPLACE_MAP.put("29", ')');
		_REPLACE_MAP.put("7E", '~');
	}
	
	private static String fastReplace(String s)
	{
		StringBuilder sb = new StringBuilder();
		
		for(int i = 0; i < s.length(); i++)
		{
			char c = s.charAt(i);
			
			if(c == '+')
			{
				sb.append("%20");
				continue;
			}
			
			
			if(c == '%' && i < s.length()-2)
			{
				String probe = s.substring(i+1,i+3);
				if(_REPLACE_MAP.containsKey(probe))
				{
					sb.append(_REPLACE_MAP.get(probe));	
					i += 2;
					continue;
				}
			}
			
			
			sb.append(c);
		}
		
		return sb.toString();
	}

	static class ArgMapNumberException extends RuntimeException
	{

		ArgMapNumberException(String colname, String coltype, String inputstr)
		{
			super(getMessage(colname, coltype, inputstr));
		}

		private static String getMessage(String colname, String coltype, String inputstr)
		{
			return String.format("The input string %s could not be converted into a %s, for column %s", inputstr, coltype, colname);
		}

	}
}