
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 
import java.time.LocalDate;
import java.util.stream.Stream;
import java.nio.charset.StandardCharsets;


import net.danburfoot.shared.Util;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.DayCode;
import net.danburfoot.shared.CollUtil;
import net.danburfoot.shared.FileUtils;
import net.danburfoot.shared.TimeUtil.*;
import net.danburfoot.shared.CollUtil.*;
import net.danburfoot.shared.Util.SyscallWrapper;
import net.danburfoot.shared.CoreDb.QueryCollector;
import net.danburfoot.shared.CoreDb.ConnectionSource;

import io.webwidgets.core.WidgetOrg.*;


public class LifeUtil
{ 

	public static String BASE_WIDGET_NAME = "base";

	public static String SMS_WIDGET_NAME = "sms_box";

	public static List<String> RESERVED_WIDGET_NAMES = Arrays.asList(
		MailSystem.MAILBOX_WIDGET_NAME,
		SMS_WIDGET_NAME,
		BASE_WIDGET_NAME
	);

	public static final String USER_DATA_DIR = "/opt/userdata";
	public static final String MAIN_LIFECODE_DIR = USER_DATA_DIR + "/lifecode";
	public static final String RAW_DATA_DIR = "/opt/rawdata";
		
	// This is the new place for user widgets.
	// For a given user, it will go in widgets/username
	// TODO: this is a bad name, should be something like "code dir";
	public static final String WIDGETS_DIR = USER_DATA_DIR + "/widgetserve";
	
	public static final String WIDGET_DB_DIR = USER_DATA_DIR + "/db4widget";


	

	// On user creation, the dummy password is set to this
	// However, the authentication does not work until the password is set to something new
	public static final String DUMMY_PASSWORD = "DummyPass";

	// Widget admin directory
	// Special non-widget code, running on server. Not controlled by users.
	// Served from /admin
	static final String WIDGET_ADMIN_DIR = WIDGETS_DIR + "/admin";

	public static final String CONFIG_DIR = MAIN_LIFECODE_DIR + "/configfile";
	
	public static final String PERSONAL_RESIN_CONFIG = CONFIG_DIR + "/personal";
	public static final String WIDGETS_RESIN_CONFIG = CONFIG_DIR + "/widgets";
	
	public static final String DATA_DIR_PATH = MAIN_LIFECODE_DIR + "/datadir";

	public static final String WWIO_RAWDATA_BASE_DIR = "/opt/rawdata/wwio";
	public static final String WWIO_BLOB_BASE_DIR = WWIO_RAWDATA_BASE_DIR + "/blob";

		
	public static final String DB_ARCHIVE_DIR = DATA_DIR_PATH + "/dbarchive";
	
	public static final String SCRIPT_DIR = MAIN_LIFECODE_DIR + "/script";

	// TODO: need a directory that is specific to WWIO miscdata, not just reuse of CRM miscdata
	public static final String MISC_DATA_DIR = USER_DATA_DIR + "/crm/miscdata";

	public static final String JCLASS_BASE_DIR = USER_DATA_DIR + "/crm/compiled/jclass";

	public static final String PYTHON_AUTOGEN_DOC = MISC_DATA_DIR + "/AutoDocResult.html";

	public static final String WIDGET_REPO_DIR = USER_DATA_DIR + "/external/WebWidgets";
	public static final String WIDGET_JSLIB_DIR = WIDGET_REPO_DIR + "/jslib";

	public static final File SHARED_CSS_ASSET_DIR = (new WidgetItem(WidgetUser.getSharedUser(), "css")).getWidgetBaseDir();	
	public static final File SHARED_JSLIB_ASSET_DIR = (new WidgetItem(WidgetUser.getSharedUser(), "jslib")).getWidgetBaseDir();
	
	
	public static final String WEB_SITE_DIR = MAIN_LIFECODE_DIR + "/website";
	
	public static final String WWIO_SITE_DIR = MAIN_LIFECODE_DIR + "/wwiosite";
	
	public static final String WWIO_SNIPPET_DIR = WWIO_SITE_DIR + "/snippet";
	
	public static final String WWIO_PUBDOCS_DIR = WWIO_SITE_DIR + "/docs";

	static final String MASTER_WIDGET_NAME = "master";
	
	
	private static boolean _CLASS_INIT = false;
	
	static void maybeInitClass()
	{
		if(_CLASS_INIT)
			{ return ; }
		
		try {
			Class.forName("org.sqlite.JDBC");
			_CLASS_INIT = true;
		} catch (Exception ex )  {
			throw new RuntimeException(ex);	
		}		
	}

	public static WidgetItem getMasterWidget()
	{
		return new WidgetItem(WidgetUser.getDburfootUser(), MASTER_WIDGET_NAME);
	}

	// This is the same algorithm that the JS code uses
	// Not 100% required for it to be the same, but it gratifies my feeling of seiketsukan
	public static int createNewIdRandom(WidgetItem witem, String tabname)
	{
		// This has been checked before. We check again out of paranoia
		// this is protection against SQL injection attacks
		Util.massert(witem.getDbTableNameSet().contains(tabname),
			"Table Name %s not present for widget %s", tabname, witem);

		Random r = new Random();

		for(int attempt : Util.range(10))
		{
			int probe = r.nextInt();

	        // Reserve this small range for "magic" ID numbers like -1
			if(-1000 <= probe && probe <= 0)
				{ continue; }

			if(!haveRecordWithId(witem, tabname, probe))
				{ return probe; }
		}

		Util.massert(false, "Failed to find new ID after 10 tries, this table is too big!!!");
		return -1;
	}

	private static boolean haveRecordWithId(WidgetItem witem, String tabname, int rid) 
	{
		String query = String.format("SELECT * FROM %s WHERE id = %d", tabname, rid);
		int numrec = QueryCollector.buildAndRun(query, witem).getNumRec();
		Util.massert(numrec == 0 || numrec == 1, 
			"Violation of DB contract for table %s, ID %d, multiple records found", tabname, rid);

		return numrec == 1;
	}


	public static int getNewDbId(ConnectionSource witem, String tabname)
	{
		return getNewDbId(witem, tabname, "id");
	}

	public static int getNewDbId(ConnectionSource witem, String tabname, String idcolname)
	{
		String sql = Util.sprintf("SELECT max(%s) FROM %s", idcolname, tabname);
		
		List<Integer> reslist = CoreDb.execSqlQuery(sql, witem);
		
		if(reslist.get(0) == null)
		{
			Util.pf("Got NULL entry for sql %s, returning 0\n", sql);
			return 0; 
		}
		
		return reslist.get(0)+1;
	}
	
	public static QueryCollector fullTableQuery(ConnectionSource csrc, String tabname)
	{
		return tableQuery(csrc, tabname, Collections.emptyList());
	}
	
	public static QueryCollector dayCodeCutoffQuery(ConnectionSource csrc, String tabname, DayCode dc)
	{
		for(String permute : Util.listify("day_code", "daycode"))
		{
			try {
				String where = Util.sprintf(" %s >= '%s' ", permute, dc);
				return tableQuery(csrc, tabname, Util.listify(where));			
			} catch (Exception sqlex) {}
		}
		
		Util.massert(false, "Couldn't find either day_code or daycode columns in table %s", tabname);
		return null;
	}
	
	public static QueryCollector tableQuery(ConnectionSource csrc, String tabname, List<String> wherelist)
	{
		String wherestr = wherelist.isEmpty() ? "" : " WHERE " + Util.join(wherelist, " AND ");
		
		String sql = Util.sprintf("SELECT * FROM %s %s", tabname, wherestr); 
		
		QueryCollector qcol = (new QueryCollector(sql)).doQuery(csrc);
		return qcol;
		
	}	
	
	
	public static QueryCollector tableQuery(ConnectionSource csrc, String tabname, Optional<Integer> optlimit)
	{
		String limitstr = optlimit.isPresent() ? "LIMIT " + optlimit.get() : "";
		
		String sql = Util.sprintf("SELECT * FROM %s %s", tabname, limitstr); 
		
		return tableQuery(csrc, sql);
	}	
		
	
	public static QueryCollector tableQuery(ConnectionSource csrc, String sql)
	{
		return (new QueryCollector(sql)).doQuery(csrc);
	}	

	// This is going to fail if the connection is not actually a Sqlite connector
	public static Set<String> getLiteTableNameSet(ConnectionSource litedb)
	{
		String sql = "SELECT name FROM sqlite_master WHERE type='table'";
		
		return Util.map2set(QueryCollector.buildAndRun(sql, litedb).recList(), amap -> amap.getSingleStr());

	}

	public static Map<String, String> getCreateTableMap(ConnectionSource litedb)
	{
		String sql = "SELECT name, sql FROM sqlite_master WHERE type='table'";
		
		return Util.map2map(QueryCollector.buildAndRun(sql, litedb).recList(), amap -> amap.getStr("name"), amap -> amap.getStr("sql"));
	}
	
	public static DayCode getTodayTzAware() 
	{
		String tsaware = ExactMoment.build().asBasicTs(TimeZoneEnum.PST);	
		return DayCode.lookup(tsaware);		
	}
	
	public static String getCreateTableSql(ConnectionSource witem, String tablename)
	{
		String query = Util.sprintf("SELECT sql FROM sqlite_master WHERE type = 'table' AND tbl_name = '%s'", tablename);
		QueryCollector qcol = QueryCollector.buildAndRun(query, witem);
		return qcol.getSingleArgMap().getSingleStr();
	}
	


	public static File convert2Excel(WidgetItem witem) 
	{
		Util.massert(witem.getLocalDbFile().exists(), "Widget Item DB not found at %s", witem.getLocalDbFile());

		/*
		String xlpath = String.format("%s/%s__%s.xlsx", LifeUtil.TEMP_EXCEL_DIR, witem.theOwner, witem.theName);

		String pycall = String.format("python3 /opt/userdata/lifecode/script/utility/Lite2Excel.py litepath=%s xlpath=%s",
									witem.getLocalDbPath(), xlpath);

		SyscallWrapper syswrap = SyscallWrapper.build(pycall).execE();

		for(String err : syswrap.getErrList())
			{ Util.pferr("** %s\n", err); }

		for(String out : syswrap.getOutList())
			{ Util.pf("%s\n", out); }						

		File result = new File(xlpath);
		Util.massert(result.exists(), "Failed to convert DB to excel");
		return result;
		*/
		
		throw new RuntimeException("Must re-implement");
	}
	

	

	
	public static TreeMap<Pair<Double, String>, List<String>> getSnippetInfoMap(String snipcode)
	{
		File snipdir = new File(Util.sprintf("%s/%s", WWIO_SNIPPET_DIR, snipcode));
		Util.massert(snipdir.exists(), 
			"Could not find snippet directory for code %s, expected at %s", snipcode, snipdir);
		
		TreeMap<Pair<Double, String>, List<String>> result = Util.treemap();
		
		for(File snipfile : snipdir.listFiles())
		{
			String subcode = snipfile.getName();
			
			// Error?
			if(!subcode.endsWith(".html"))
				{ continue; }
			
			subcode = subcode.substring(0, subcode.length()-".html".length());
			
			String[] idname = subcode.split("__");
			Util.massert(idname.length == 2, "Bad snippet subcode name %s", subcode);
			Pair<Double, String> sortkey = Pair.build(Double.valueOf(idname[0]), idname[1]);

			List<String> data = FileUtils.getReaderUtil().setFile(snipfile).setTrim(false).readLineListE();
			result.put(sortkey, data);
		}
		
		return result;
	}

	public static <T> Set<T> combine2set(Collection<T> acol, Collection<T> bcol) 
	{
		return Stream.concat(acol.stream(), bcol.stream()).collect(CollUtil.toSet());
	}


    public static long getFileCkSum(File myfile)
    {
    	Util.massert(myfile.exists(), 
    		"File %s does not exist", myfile.getAbsolutePath());
    	
    	SyscallWrapper swrap = new SyscallWrapper("cksum " + myfile.getAbsolutePath());
    	
    	swrap.execE();
    	
    	Util.massert(swrap.getOutList().size() == 1, 
            "Found wrong number of output lines %s for file %s", 
            swrap.getOutList(), myfile
        );

    	String[] toks = swrap.getOutList().get(0).split(" ");
    	
    	return Long.valueOf(toks[0]);
    }

	public static List<File> getAllFileList(File topdir)
	{
		Util.massert(topdir.isDirectory(), "Expected a directory, found %s", topdir);
		List<File> target = Util.arraylist();
		popFileListSub(target, topdir);
		return target;
	}

	private static void popFileListSub(List<File> target, File curdir)
	{
		Util.massert(curdir.isDirectory());

		for(File kid : curdir.listFiles())
		{
			if(kid.isFile())
			{
				target.add(kid);
				continue;
			}

			popFileListSub(target, kid);
		}
	}

	public static interface ProxyCompare<T extends Comparable<T>> extends Comparable<ProxyCompare<T>>
	{
		public T getProxy();

		@Override
		public default int compareTo(ProxyCompare<T> other)
		{
			T mine = getProxy();
			T your = other.getProxy();

			return mine.compareTo(your);
		}

	}

    public static String peelPrefix(String original, String prefix)
    {
    	Util.massert(original.startsWith(prefix),
    		"Prefix logic error: attempt to peel prefix %s from original string %s", prefix, original);
    	
    	return original.substring(prefix.length());
    }	


    public static String peelSuffix(String original, String suffix)
    {
    	Util.massert(original.endsWith(suffix),
    		"Suffix logic error: attempt to peel suffix %s from original string %s", suffix, original);
    	
    	
    	return original.substring(0, original.length()-suffix.length());
    }

	// lex_id => LexId
	public static String snake2CamelCase(String snakestr)
	{
		return Util.listify(snakestr.split("_"))
				.stream()
				.map(s -> LifeUtil.capitalizeFirst(s))
				.collect(CollUtil.joining());
	}
	
	public static String camel2SnakeCase(String camelstr)
	{
		String[] toks = camelstr.split("(?=\\p{javaUpperCase})");
		
		return Util.listify(toks)
				.stream()
				.map(s -> s.toLowerCase())
				.collect(CollUtil.joining("_"));
	}

	public static String base64Encode(String s)
	{
		Util.massert(!hasNonBasicAscii(s),
			"Found non-basic ASCII in argument string %s, this method is not suitable", s);
		
		try {
			ByteArrayOutputStream baos = new ByteArrayOutputStream();
			OutputStream b64os = Base64.getEncoder().wrap(baos);
			
			b64os.write(s.getBytes(StandardCharsets.US_ASCII));
			
			b64os.close();
			
			return  baos.toString(StandardCharsets.US_ASCII);
			
		} catch (IOException ioex) {
			// Should almost never happen
			throw new RuntimeException(ioex);
		}
	}

	public static String base64Decode(String base64)
	{
		Util.massert(!hasNonBasicAscii(base64),
			"Found non-basic ASCII in argument string %s, this method is not suitable", base64);
		
		byte[] decoded = Base64.getDecoder().decode(base64);
		return new String(decoded, StandardCharsets.UTF_8);
	}	

	public static boolean hasNonBasicAscii(String s)
	{
		for(int i = 0; i < s.length(); i++)
		{
			int x = (int) s.charAt(i);
			
			if(x >= 128)
				{ return true; }
		}
		return false;	
	}		

	public static String capitalizeFirst(String word)
	{
		if(word.isEmpty())
			{ return word; }
		
		char c = word.charAt(0);
		return (""+c).toUpperCase() + word.substring(1);
	}	
} 
