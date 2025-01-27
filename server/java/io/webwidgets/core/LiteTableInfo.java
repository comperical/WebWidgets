package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 

import java.util.regex.Pattern;
import java.util.regex.Matcher;
import java.util.function.Consumer;

import javax.servlet.http.HttpServletRequest;
import org.json.simple.JSONObject;


import net.danburfoot.shared.Util;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.CollUtil;
import net.danburfoot.shared.FileUtils;

import net.danburfoot.shared.CollUtil.*;
import net.danburfoot.shared.CoreDb.QueryCollector;
import net.danburfoot.shared.CoreDb.ConnectionSource;


import io.webwidgets.core.CoreUtil.*;
import io.webwidgets.core.WidgetOrg.*;

/**
 * Metadata about an underlying SQLite table
 * This class is used by the JS Code Generator to create the wrapper code that gets sent to the browser
 * This information is primarily generated by doing a SELECT * LIMIT 1 on the table and then examining
 * the ResultSetMetaData
 */
public class LiteTableInfo
{

    public static final Pattern BASIC_TABLE_MATCH = Pattern.compile("CREATE TABLE \"?(\\w+)\"?\\s*\\((.*?)\\)$");

    public static final Pattern DEFAULT_PATTERN = Pattern.compile("DEFAULT\\s+(?:(?:'([^']*)')|(\\d+(?:\\.\\d+)?)(?=\\s|,|$)|(\\w+))", Pattern.CASE_INSENSITIVE);

    public static final Pattern SIMPLE_STRING_OKAY = Pattern.compile("^[A-Za-z0-9]+$");

	public static final String LOAD_SUCCESS_TAG = LiteTableInfo.class.getSimpleName() + "__LOAD_SUCCESS";
		
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

		public boolean isJsString()
		{
			return this == ExchangeType.text || this == ExchangeType.varchar;
		}

		public Class getJavaType()
		{
			return isJsFloat() ? Double.class : (isJsInteger() ? Integer.class : String.class);
		}

		private Object convertFromJson(JSONObject jsonob, String colname)
		{
			if(isJsInteger())
			{
				var ob = jsonob.get(colname);
				return ob == null ? null : ((Long) ob).intValue();
			}

			if(isJsFloat())
			{
				var ob = jsonob.get(colname);
				return ob == null ? null : ((Number) ob).doubleValue();

			}

			var ob = jsonob.get(colname);
			Util.massert(ob instanceof String, "Expected String for column %s but got %s", colname, ob);
			return ob;
		}

		private Object convertFromArgMap(ArgMap recmap, String colname)
		{
			if(isJsInteger())
				{ return recmap.getInt(colname); }

			if(isJsFloat())
				{ return recmap.getDbl(colname); }

			return recmap.getStr(colname);
		}
	}
	
	public final Pair<WidgetItem, String> dbTabPair;

	// Note: the order of these keys are very important
	// Nov 2024: this is the new format for the _colTypeMap, we can get the ExchangeTypes from JDBC metadata
	private LinkedHashMap<String, ExchangeType> _exTypeMap = Util.linkedhashmap();

	private Pair<String, Object> _colFilterTarget = null;

	private Boolean _isBlobStore = null;

	private Set<WidgetUser> _checkAuthOwner = null;

	private boolean _noDataMode;

	public LiteTableInfo(WidgetItem widget, String table)
	{
		dbTabPair = Pair.build(widget, table);
				
		Util.massert(table.length() > 0, "Empty table name");
		Util.massert(table.toLowerCase().equals(table), "Table names should be lower case");

		String basic = getBasicName();
		_noDataMode = false;
	}
	

	public static LiteTableInfo fromArgMap(ArgMap onemap)
	{
		WidgetUser owner = WidgetUser.valueOf(onemap.getStr("wowner"));
		String wname = onemap.getStr("wname");
		String table = onemap.getStr("tablename");
		return new LiteTableInfo(new WidgetItem(owner, wname), table);
	}

	public void runSetupQuery()
	{
		try {
			Connection conn = dbTabPair._1.createConnection();
			
			String prepsql = Util.sprintf("SELECT * FROM %s LIMIT 1", dbTabPair._2);
			
			PreparedStatement pstmt = conn.prepareStatement(prepsql);
			
			ResultSet rset = pstmt.executeQuery();
			
			ResultSetMetaData rsmd = rset.getMetaData();
			
			popColTypeMap(rsmd);
						
			conn.close();

			_isBlobStore = BlobDataManager.isBlobStorageTable(_exTypeMap.keySet());
			
		} catch (Exception ex) {
			
			throw new RuntimeException(ex);
		}
	}
	
	
	public LiteTableInfo withNoDataMode(boolean ndmode)
	{
		_noDataMode = ndmode;
		return this;
	}

	public LiteTableInfo withColumnTarget(String colname, Object value)
	{
		Util.massert(_exTypeMap != null, "You must run the setup query first");
		Util.massert(_exTypeMap.containsKey(colname), 
			"Attempt to filter on missing column %s, options are %s", colname, _exTypeMap.keySet());

		_colFilterTarget = Pair.build(colname, value);
		return this;
	}

	public LiteTableInfo withAuthOwnerSet(Set<WidgetUser> userset)
	{
		Util.massert(hasGranularPerm(), "Attempt to check auth owner set for table without granular permissions");
		_checkAuthOwner = userset;
		return this;
	}
	
	private void popColTypeMap(ResultSetMetaData rsmd) throws SQLException
	{
		for(int ci : Util.range(rsmd.getColumnCount()))
		{
			String colname = rsmd.getColumnName(ci+1);
			
			String classname = rsmd.getColumnTypeName(ci+1);
			
			ExchangeType etype = ExchangeType.lookupFromSql(classname);

			_exTypeMap.put(colname, etype);
		}

		// TODO: reintroduce this assertion, my old DB tables are not configured properly
		boolean isdcb = dbTabPair._1.theOwner.toString().equals("dburfoot");
		Util.massert(isdcb || _exTypeMap.keySet().iterator().next().toLowerCase().equals(CoreUtil.STANDARD_ID_COLUMN_NAME),
				"Expect first column to be ID, but got %s, for %s", _exTypeMap.keySet(), dbTabPair);
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
		return CoreUtil.snake2CamelCase(dbTabPair._2);
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
		return Arrays.asList("id");
	}
	
	public ConnectionSource getDbRef()
	{
		return dbTabPair._1;
	}
	
	public Set<String> getColumnNameSet()
	{
		return Collections.unmodifiableSet(_exTypeMap.keySet());

	}
	
	public Map<String, ExchangeType> getColumnExTypeMap()
	{
		return Collections.unmodifiableMap(_exTypeMap);
	}


	// Okay, this method can't be offloaded to JS creator, it needs to run every time.
	public List<String> composeDataRecSpool()
	{
		return composeDataRecSpool(dbTabPair._2);
	}
	
	List<String> composeDataRecSpool(String querytarget)
	{
		Util.massert(!_exTypeMap.isEmpty(),
			"You must call runQuery before creating the data, sorry bad naming");
		
		List<String> reclist = Util.vector();
				
		reclist.add("");
		reclist.add("");
		reclist.add("");
		
		reclist.addAll(composeJsonRepList(querytarget));

		return reclist;
	}
	

	// TODO: all of the query-specific logic should be in another place, and another class
	// The LiteTableInfo is metadata about a TABLE, not a QUERY
	public List<ArgMap> loadRecordList(String querytarget)
	{
		Util.massert(!_exTypeMap.isEmpty(),
			"You must call runQuery before creating the data, sorry bad naming");
		
		Util.massert(_checkAuthOwner == null || hasGranularPerm(),
			"Attempt to check granular permissions, but this table is not configured for granular perms");
		
		if(_noDataMode)
			{ return Collections.emptyList(); }

		String query = "SELECT * FROM " + querytarget;
		QueryCollector bigcol;

		Util.massert(_colFilterTarget == null || _checkAuthOwner == null,
			"As of Jan 2025, cannot use filter column targets with auth owner targets");

		if(_colFilterTarget != null)
		{
			query += String.format(" WHERE %s = ? ", _colFilterTarget._1);
			bigcol = QueryCollector.buildRunPrepared(query, dbTabPair._1, _colFilterTarget._2);

		} else if (_checkAuthOwner != null) {

			query += String.format(" WHERE %s IN (%s) ", CoreUtil.AUTH_OWNER_COLUMN, CoreDb.nQuestionMarkStr(_checkAuthOwner.size()));
			bigcol = QueryCollector.buildRunPrepared(query, dbTabPair._1, _checkAuthOwner.toArray());

		} else {
			bigcol = QueryCollector.buildAndRun(query, dbTabPair._1);
		}

		return bigcol.getArgMapList();
	}

	private List<String> composeJsonRepList(String querytarget)
	{
		
		List<ArgMap> recordList = loadRecordList(querytarget);

		List<String> jsonitems = Util.vector();
		
		for(ArgMap onemap : recordList)
		{
			List<String> arglist = _exTypeMap.keySet()
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
			List<String> cols = Util.vector(_exTypeMap.keySet());
			
			reclist.add(Util.sprintf("function %s(arr) {", converter));
			reclist.add("\tconst d = {};");
			
			int idx = 0;
			
			for(var colexpair : _exTypeMap.entrySet())
			{
				String assign = Util.sprintf("arr[%d]", idx);
				if(colexpair.getValue().isJsString())
					{ assign = Util.sprintf("decodeURIComponent(%s)", assign); }
				
				reclist.add(Util.sprintf("\td['%s'] = %s;", colexpair.getKey(), assign));
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

		// This is the primary connection between the code generation and the code library
		// The tableNameIndex returns the table object, which has a register(...) function
		reclist.add(Util.sprintf("].forEach(function(myrec) { \n\tW.__tableNameIndex.get('%s').register(W.buildItem('%s', %s(myrec)));\n});", 
			dbTabPair._2, dbTabPair._2, converter));

		
		reclist.add("");
		reclist.add("// " + LOAD_SUCCESS_TAG);
		
		return reclist;
	}
	
	// Return the JSON-valid representation of the value in the given column
	// This could be the literal null, a literal numeric representation, or a quoted string
	private String getArrayRep(ArgMap onemap, String onecol)
	{
		String s = onemap.getStr(onecol);

		// Util.massert(s != null,
		//	"Found null value for column %s, this system cannot handle nulls, use empty strings", onecol);
		
		if(s == null)
			{ return null + ""; }

		// Need to put quotes around string types
		if(!_exTypeMap.get(onecol).isJsString())
			{ return s; }

		StringBuilder sb = new StringBuilder();
		sb.append("\"");

		// May 2024 note: could not detect any performance improvements by using the library version of the escape operation
		// sb.append(_useJsonQuote ? org.json.simple.JSONValue.escape(s) : myEncodeURIComponent(s));

		sb.append(myEncodeURIComponent(s));
		sb.append("\"");
		return sb.toString();
	}

	public Map<String, Object> getDefaultInfo()
	{
		var coldef = loadColumnDefinition(dbTabPair._1, dbTabPair._2);
		return getDefaultReadout(coldef);
	}


	// True if the table has "granular" permissions
	public boolean hasGranularPerm()
	{
		Util.massert(_exTypeMap != null && !_exTypeMap.isEmpty(), "You must run the setup query first");
		return _exTypeMap.containsKey(CoreUtil.AUTH_OWNER_COLUMN);
	}

	Optional<ArgMap> lookupRecordById(int recordid)
	{
		String where = String.format(" %s = %d ", CoreUtil.STANDARD_ID_COLUMN_NAME, recordid);

		// This is fast; all WWIO tables have single PKey
		QueryCollector query = CoreUtil.tableQuery(dbTabPair._1, dbTabPair._2, Util.listify(where));

		return query.getNumRec() > 0 ? Optional.of(query.getSingleArgMap()) : Optional.empty();
	}

	static boolean isUpsertAjaxOp(ArgMap argmap)
	{
		String ajaxop = argmap.getStr("ajaxop");
		boolean isups = ajaxop.equals("upsert");
		boolean isdel = ajaxop.equals("delete");

		Util.massert(isups || isdel, "Bad Ajax Operation code %s", ajaxop);
		return isups;
	}

	
	void processAjaxOp(ArgMap argmap)
	{
		// Modestly better performance to do this here, rather than within sync block
		Consumer<ArgMap> myfunc = isUpsertAjaxOp(argmap) ? this::doUpsert : this::doDelete;

		// TODO: this is going to probably cause some scalability issues
		// when we get to 100000's of tables
		SyncController editcontrol = getEditController(dbTabPair._1);
		
		synchronized(editcontrol)
		{
			myfunc.accept(argmap);
		}
	}
	
	public boolean isBlobStoreTable()
	{
		Util.massert(_isBlobStore != null, "Must call runSetupQuery first");

		return _isBlobStore;
	}

	private void doUpsert(ArgMap argmap)
	{
		Util.massert(argmap.getStr("tablename").equals(dbTabPair._2),
			"Wrong table name: %s vs %s", argmap.getStr("tablename"), dbTabPair._2);
		
		LinkedHashMap<String, Object> paymap = getPayLoadMap(argmap);

		// If the payload has blob data, this operation swaps out the blob data and writes the file to disk and S3
		// What gets entered into the SQLite table is the blob coords, not the blob data itself
		BlobDataManager.optProcessBlobInput(this, paymap);
		
		// The getPkeyList().size() is a bit unnecessary, all WWIO tables have exactly 1 PK column "id"
		CoreDb.upsertFromRecMap(dbTabPair._1, dbTabPair._2, getPkeyList().size(), paymap);
	}
	
	private void doDelete(ArgMap argmap)
	{
		Util.massert(argmap.getStr("tablename").equals(dbTabPair._2),
			"Wrong table name: %s vs %s", argmap.getStr("tablename"), dbTabPair._2);
		
		// TODO: historical versions of WWIO allowed multi-column primary keys
		// Current version (Oct 2023) allows only single-column primary key with Integer "id"
		// So this command really just getRecMap("id", argmap.getInt("id"))); 
		// LinkedHashMap<String, Object> paymap = getPayLoadMap(argmap, _pkeyList);
		LinkedHashMap<String, Object> paymap = CoreDb.getRecMap("id", argmap.getInt("id"));

		BlobDataManager.optProcessDelete(this, paymap);
		
		CoreDb.deleteFromColMap(dbTabPair._1, dbTabPair._2, paymap);
	}
	
	
	// Convert the ArgMap representation of a record payload to the LHM version
	// Follow ordering of given collection
	// Use the appropriate getXYZ methods on ArgMap to convert
	private LinkedHashMap<String, Object> getPayLoadMap(ArgMap argmap)
	{
		return convertPayLoadSub(argmap, null);
	}

	// Convert a list of JSONObjects, from JSON.parse(...), into LHM form for insert
	List<LinkedHashMap<String, Object>> bulkConvert(List<?> jsonlist)
	{
        Util.massert(!_exTypeMap.isEmpty(), "You must setup the LiteTable before calling!!");
        return Util.map2list(jsonlist, ob -> convertPayLoadSub(null, ((JSONObject) ob)));
	}

	// Convert from either ArgMap or JSON to LHM
	// 
	private LinkedHashMap<String, Object> convertPayLoadSub(ArgMap argmap, JSONObject jsonob)
	{
		LinkedHashMap<String, Object> paymap = Util.linkedhashmap();
		
		for(var colname : _exTypeMap.keySet())
		{
			var ob = argmap != null ? exchangeConvert(argmap, colname) : exchangeConvert(jsonob, colname);
			paymap.put(colname, ob);
		}

		return paymap;
	}

	private Object exchangeConvert(ArgMap recmap, String onecol)
	{
		String probe = recmap.get(onecol);
		if(CoreUtil.MAGIC_NULL_STRING.equals(probe))
			{ return null; }

		ExchangeType coltype = getExchangeType(onecol);

		try {
			return coltype.convertFromArgMap(recmap, onecol);
		} catch (NumberFormatException nfex) {

			String input = recmap.get(onecol);
			throw new ArgMapNumberException(onecol, coltype, input);
		}
	}

	private Object exchangeConvert(JSONObject jsonob, String onecol)
	{
		Object probe = jsonob.get(onecol);
		if(CoreUtil.MAGIC_NULL_STRING.equals(probe))
			{ return null; }

		ExchangeType coltype = getExchangeType(onecol);
		return coltype.convertFromJson(jsonob, onecol);
	}


	ExchangeType getExchangeType(String colname)
	{
		var litedef = _exTypeMap.get(colname);
		Util.massert(litedef != null, "Attempt to lookup Exchange Type for non-existent column %s", colname);
		return litedef;
	}


	// TODO: this is unused except for a unit test, refactor the unit test
	static Object getJsonPayLoad(String onecol, String onetype, JSONObject jsonob)
	{
		Object probe = jsonob.get(onecol);
		if(CoreUtil.MAGIC_NULL_STRING.equals(probe))
			{ return null; }

		java.util.function.Function<Object, Integer> convertlong = ob -> (ob == null ? null : ((Long) ob).intValue());
		java.util.function.Function<Object, Double> convertreal = ob -> (ob == null ? null : ((Number) ob).doubleValue());

		switch(onetype)
		{
			case "INT":
			case "TINYINT":
			case "SMALLINT":
			case "INTEGER" : return convertlong.apply(probe);


			case "REAL":
			case "DOUBLE": return convertreal.apply(probe);

			case "VARCHAR":
			case "TEXT": 
			case "STRING": return (String) probe;

			default: throw new RuntimeException("Unknown Type: " + onetype);
		}
	}

	// Load the SQLite create table statement, parse in the column name :: definition pairs
	// This code is replicated in DataDesigner in extension package
	// Eventually need a complete class that represents everything about a SQLite table definition
	// TODO: this code will break if the user uploads a table with an INDEX or UNIQUE definition in it
    public static LinkedHashMap<String, String> loadColumnDefinition(WidgetItem item, String table)
    {
        String tablesql = CoreUtil.getCreateTableSql(item, table).strip().replaceAll("\n", " ");

        Matcher basicmatch = BASIC_TABLE_MATCH.matcher(tablesql);
        if(!basicmatch.find())
        {
            throw new RuntimeException("Bad table definition : " + tablesql);
        }

        {
            String sanity = basicmatch.group(1);

            if(!sanity.toLowerCase().equals(table.toLowerCase()))
            {
                String errmssg = String.format("Requested table name %s, but CREATE TABLE returned %s!!!", table, sanity);
                throw new RuntimeException(errmssg);
            }
        }

        var result = new LinkedHashMap<String, String>();

        String columnDef = basicmatch.group(2);

        var colDefList = Util.linkedlistify(columnDef.split(","));

        checkPollPrimaryKey(colDefList);

        for(String colpair : colDefList)
		{
			String trimmed = colpair.trim();
	        int spaceidx = trimmed.indexOf(" ");
	        String colname = trimmed.substring(0, spaceidx);
	        String coldef = trimmed.substring(spaceidx+1);
	        result.put(colname, coldef);
		}

        String firstcol = result.keySet().iterator().next().toLowerCase();
        Util.massert(firstcol.equals("id"), "Expected 'id' as first column, but found %s", firstcol);

        return result;
    }

    private static String basicStringReduce(String mystr)
    {
        return mystr.toLowerCase().replaceAll(" ", "");
    }

    private static void checkPollPrimaryKey(LinkedList<String> colinfo)
    {
    	boolean foundprim = false;

    	while(!colinfo.isEmpty())
    	{
    		String reduced = basicStringReduce(colinfo.peekLast());

			String fkred = basicStringReduce("foreign key");
			if(reduced.contains(fkred))
			{
				colinfo.pollLast();
				continue;
			}

			String primkey = basicStringReduce("primary key(id)");
			if(reduced.equals(primkey))
			{
				colinfo.pollLast();
				foundprim = true;
				continue;
			}

			break;
    	}

    	Util.massert(foundprim, "Failed to find primary key, columns are %s", colinfo);
    }

    public static Map<String, Object> getDefaultReadout(LinkedHashMap<String, String> coldef)
    {
    	var hitkeys = Util.filter2list(coldef.keySet(), k -> extractDefaultInfo(coldef.get(k)).isPresent());

    	return Util.map2map(hitkeys, k -> k, k -> extractDefaultInfo(coldef.get(k)).get());
    }

    public static Optional<Object> extractDefaultInfo(String defstart)
    {
    	String definition = defstart.replaceAll("\"", "'");

        Matcher matcher = DEFAULT_PATTERN.matcher(definition);

        if (matcher.find()) {

        	if(matcher.group(1) != null)
	        	{ return Optional.of(matcher.group(1)); }

	        if(matcher.group(2) != null)
	        { 
	        	String dstr = matcher.group(2);

	        	// Lots of PAIN here, trying to get it to return the right Integer/Double as appropriate
	        	// int dotidx = dstr.indexOf(".");

	        	// This is very very weird, but this statement doesn't work the way I want,
	        	// somehow the compiler decides to return Double in both cases. 
	        	// But spelling it out DOES work
	        	// Object o = (dotidx == -1 ? Integer.valueOf(dstr) : Double.valueOf(dstr));
	        	Object o;

	        	if(dstr.indexOf(".") == -1)
		        	{ o = Integer.valueOf(dstr); }
		        else
			        { o = Double.valueOf(dstr); }

	        	return Optional.of(o);
	        }

	        if(matcher.group(3) != null)
		    {
		    	String boolstr = matcher.group(3).toLowerCase();
		    	if(Util.setify(true+"", false+"").contains(boolstr))
		    		{ return Optional.of(Boolean.valueOf(boolstr)); }
		    }
        }

        return Optional.empty();
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
		File wdir = dbTabPair._1.getAutoGenJsDir();
		return Util.sprintf("%s/%s__%03d.js", wdir.toString(), getBasicName(), version);
	}
	
	// TODO: need to get rid of this hacky way of upgrading the versions
	// Just put the file modtime in there, Jesus
	int getVersionFromPath(File thefile)
	{
		String fname = thefile.getName();
		String[] toks = fname.split("__");
		String justnum = CoreUtil.peelSuffix(toks[1], ".js");
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
		File wdir = dbTabPair._1.getAutoGenJsDir();
		Util.massert(wdir.exists() && wdir.isDirectory(),
			"AutoGen JS Directory does not exist or is not directory %s", wdir);
		
		List<File> hits = Util.filter2list(wdir.listFiles(), f -> matchesFileName(f));
		Util.massert(hits.size() <= 1, "Found multiple versions of AutoGen JS file : %s", hits);
		
		return hits.isEmpty() ? Optional.empty() : Optional.of(hits.get(0));
	}



	private static Map<String, SyncController> __SYNC_MAP = Util.treemap();
	
	static synchronized SyncController getEditController(WidgetItem witem) 
	{
		String pathkey = witem.getLocalDbPath();
		
		__SYNC_MAP.putIfAbsent(pathkey, new SyncController());

		return __SYNC_MAP.get(pathkey);
	}
	
	static class SyncController {}
	
	
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
						
			// String other = CoreUtil.encodeURIComponent(s);
			
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

		ArgMapNumberException(String colname, ExchangeType coltype, String inputstr)
		{
			super(getMessage(colname, coltype, inputstr));
		}

		private static String getMessage(String colname, Object coltype, String inputstr)
		{
			return String.format("The input string %s could not be converted into a %s, for column %s", inputstr, coltype, colname);
		}

	}
}
