package io.webwidgets.core;

import java.io.*; 
import java.util.*; 
import java.sql.*;
import java.util.zip.*;
import java.time.LocalDate;
import java.util.stream.Stream;
import java.util.function.Predicate;
import java.nio.charset.StandardCharsets;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.DayCode;
import net.danburfoot.shared.CollUtil;
import net.danburfoot.shared.FileUtils;
import net.danburfoot.shared.TimeUtil.*;
import net.danburfoot.shared.CollUtil.*;
import net.danburfoot.shared.Util.SyscallWrapper;
import net.danburfoot.shared.CoreDb.QueryCollector;
import net.danburfoot.shared.CoreDb.ConnectionSource;



// SRCORDER::1

// This is the first class in the core package in incremental compilation mode,
// it cannot refer to any other classes in WWIO 
public class CoreUtil
{ 


	public static final String BASE_WIDGET_NAME = "base";

	// All Widget DB tables must have a single integer primary key with this name
	public static final String STANDARD_ID_COLUMN_NAME = "id";

	// This is used by the system to represent nulls. Sorry, you cannot have values that equal this literal string.
	// This much match the JS code.
	public static final String MAGIC_NULL_STRING = "_x_NULL_y_";

	public static final String USER_NAME_COOKIE = "username";

	public static final String ACCESS_HASH_COOKIE = "accesshash";

	// Widget DB for storing config-related info. This one is intended to be generally public or shareable
	public static final String CONFIG_DB_NAME = "config";

	// A table with this column is considered to have granular permissions
	public static final String GROUP_ALLOW_COLUMN = "group_allow";

	// TODO: probably want to expand this to include other things like "include"
	public static final Set<String> AUX_CODE_OKAY = Collections.unmodifiableSet(
		Util.setify(BASE_WIDGET_NAME)
	);


	static String getSubDirectory(String basedir, String kidname)
	{
		return getSubDirectory(basedir, kidname, 0);
	}

	// Simple path manipulation, attempting to be friendly to Windows or others with non-standard path separator
	static String getSubDirectory(String basedir, String kidname, int removelast)
	{
		return composeSubDirectory(basedir, removelast, kidname);
	}

	static String composeSubDirectory(String basedir, int removelast, String... extrapath)
	{
		String charsep = ""+File.separatorChar;

		LinkedList<String> tokens = Util.linkedlistify(basedir.split(charsep));

		if(tokens.peekLast().isEmpty())
			{ tokens.pollLast(); }

		// Remove last directory, add peer
		for(int i : Util.range(removelast))
			{ tokens.pollLast();} 

		for(String kidname : extrapath)
			{ tokens.add(kidname); }

		return Util.join(tokens, charsep);
	}


	// TODO: for all these hacky path manipulation stuff: use Java Path and related methods
	// This string is spliced into the code by the Python script when it is compiled
	// The compile script detects it's install directory
	public static final String WWIO_BASE_CONFIG_DIR = "WWIO_CONFIG_DIR_GOES_HERE";


	public static final String REPO_BASE_DIRECTORY = composeSubDirectory(WWIO_BASE_CONFIG_DIR, 3);

	// The directory for Widgets CODE and DATA/DB
	// These are PEERS of the main WWIO repo
	// To get peer of the main repo dir, we walk back 4 paths from the config dir
	// .../INSTALL_DIR/wwiocore/server/workdir/config => ../INSTALL_DIR
	public static final String WIDGET_CODE_DIR = getSubDirectory(WWIO_BASE_CONFIG_DIR, "widgetserve", 4);
	public static final String WIDGET_DB_DIR = getSubDirectory(WWIO_BASE_CONFIG_DIR, "db4widget", 4);


	// This is a VIRTUAL path - we do not typically create files in this path.
	// Instead, paths under this directory are sent to the blob storage tool for archival/backup purposes
	public static final String DB_ARCHIVE_VDIR = getSubDirectory(WWIO_BASE_CONFIG_DIR, "dbarchive", 3);

	public static final String GALLERY_CODE_DIR = getSubDirectory(WWIO_BASE_CONFIG_DIR, "gallery", 3);
	

	public static final String DEMO_DATA_DIR = getSubDirectory(WWIO_BASE_CONFIG_DIR, "demodata", 3);


	// Jclass is the direct peer of the config directory
	public static final String JCLASS_BASE_DIR = getSubDirectory(WWIO_BASE_CONFIG_DIR, "jclass", 1);

	// Directory for miscellaneous config etc files. Not checked into repo, but used in the application
	public static final String WWIO_MISC_DATA_DIR = getSubDirectory(WWIO_BASE_CONFIG_DIR, "miscdata", 1);

	// Temporary directory for importing code from gallery
	public static final String IMPORT_TEMP_DIR = getSubDirectory(WWIO_MISC_DATA_DIR, "importtmp");


	// On user creation, the dummy password is set to this
	// However, the authentication does not work until the password is set to something new
	public static final String DUMMY_PASSWORD = "DummyPass";

	// Special non-widget code, running on server. Not controlled by users.
	// Served from /admin
	public static final String WIDGET_ADMIN_DIR = WIDGET_CODE_DIR + "/admin";

	// TODO: need to rationalize this. The BlobStorageManager should probably use a workdir directory
	public static final String WWIO_BLOB_BASE_DIR = "/opt/rawdata/wwio/blob";

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


	public static File getDemoDataDumpFile(String widgetname)
	{
		String filename = Util.sprintf("%s_DB.sql.dump", widgetname.toUpperCase());
		String dumpfile =  Util.join(Util.listify(CoreUtil.DEMO_DATA_DIR, filename), File.separator);
		return new File(dumpfile);
	}

	public static Set<String> getDemoDataReadySet()
	{
		File[] dumplist = (new File(CoreUtil.DEMO_DATA_DIR)).listFiles();
		Set<String> ready = Util.treeset();

		for(File onefile : dumplist)
		{
			String[] tokens = onefile.getName().toLowerCase().split("_");
			Util.massert(tokens.length == 2 && tokens[1].equals("db.sql.dump"));
			ready.add(tokens[0]);
		}

		return ready;

	}

	public static int getNewDbId(ConnectionSource witem, String tabname)
	{
		return getNewDbId(witem, tabname, STANDARD_ID_COLUMN_NAME);
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
		
	
	// Canonical Random ID creation process. Create N new random IDs
	// Check them against the given predicate, and throw out those that fall in the "magic" window -1000 <= x <= 0
	// Error if the random generator fails more than 1K times to create new IDs
	// This *could* be dangerous for very large tables, if you are generating a lot...?
	// E.g. you filled up 1% of the table, and you're trying to create a million new IDs?
	// This ID creation scheme should agree with the JS one
	public static TreeSet<Integer> canonicalRandomIdCreate(Predicate<Integer> isvalid, Random r, int num2supply)
	{
		TreeSet<Integer> newset = Util.treeset();
		int numcheck = 0;

		while(true)
		{
			int probe = r.nextInt();
			numcheck++;

	        // Reserve this small range for "magic" ID numbers like -1
			if(-1000 <= probe && probe <= 0)
				{ continue; }

			// Okay, this one is not valid, try again
			if(!isvalid.test(probe))
				{ continue; }

			newset.add(probe);

			if(newset.size() >= num2supply)
				{ break; }

			Util.massert(numcheck <= num2supply + 1_000,
				"ID creation failed too many times, num2supply=%d, but numcheck=%d",
				num2supply, numcheck
			);
		}

		return newset;
	}

	public static QueryCollector tableQuery(ConnectionSource csrc, String sql)
	{
		return (new QueryCollector(sql)).doQuery(csrc);
	}

	// This is going to fail if the connection is not actually a Sqlite connector
	public static Set<String> getLiteTableNameSet(ConnectionSource litedb)
	{
		return getLiteTableNameSet(litedb, true);
	}


	// Allinclude = false :: skip table names that start with __
	public static Set<String> getLiteTableNameSet(ConnectionSource litedb, boolean allinclude)
	{
		return getCreateTableMap(litedb, allinclude).keySet();
	}

	public static Map<String, String> getCreateTableMap(ConnectionSource litedb)
	{
		return getCreateTableMap(litedb, true);
	}
	

	public static Map<String, String> getCreateTableMap(ConnectionSource litedb, boolean allinclude)
	{
		String sql = "SELECT name, sql FROM sqlite_master WHERE type='table'";

		Predicate<ArgMap> mypred = allinclude 
										? argmap -> true 
										: argmap -> !argmap.getStr("name").startsWith("__");

		List<ArgMap> reclist = Util.filter2list(QueryCollector.buildAndRun(sql, litedb).recList(), mypred);
		
		return Util.map2map(reclist, amap -> amap.getStr("name"), amap -> amap.getStr("sql"));
	}
	
	public static String getCreateTableSql(ConnectionSource witem, String tablename)
	{
		String query = Util.sprintf("SELECT sql FROM sqlite_master WHERE type = 'table' AND tbl_name = '%s'", tablename);
		QueryCollector qcol = QueryCollector.buildAndRun(query, witem);
		return qcol.getSingleArgMap().getSingleStr();
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
		public default int compareTo(ProxyCompare<T> that)
		{
			T mine = this.getProxy();
			T your = that.getProxy();

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
				.map(s -> CoreUtil.capitalizeFirst(s))
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
	
	public enum MasterTable
	{
		user_main(
			"CREATE TABLE user_main (id int, username varchar(20), accesshash varchar(20), email varchar(100), " + 
			"gdrive_folder varchar(100) default \"\", is_admin smallint DEFAULT 0, primary key(id), unique(username))"
		),
		
		email_control(
			"CREATE TABLE email_control (id int, address varchar(100), sender varchar(30), priority int, " + 
			"status varchar(10), timestamp_utc varchar(10), notes varchar(100), primary key(id))"
		),

		system_setting(
			"CREATE TABLE system_setting (id int, key_str varchar(100), val_str varchar(100), primary key(id), unique(key_str))"
		),
		
		perm_grant(
			"CREATE TABLE perm_grant (id int, owner varchar(100), widget_name varchar(100), " + 
			"grantee varchar(100), perm_level varchar(10), primary key(id))"
		);
		
		public final String createSql;
		
		MasterTable(String c)
		{
			createSql = c;
		}
		
	}





	public enum SystemPropEnum
	{
		// If present, the server is in maintenance mode and updates will be rejected
		// The value of the setting will be sent to users who try to make updates
		MAINTENANCE_MODE,

		// comma-separated list of user names who are exempt from code format checker
		// basically, these are accounts who are managed/developed by the admins of the service,
		// not individuals/etc
		CODE_FORMAT_EXEMPT_LIST, 

		// If present and equal to "true", the system is in insecure mode
		INSECURE_ALLOW_MODE;

	}

	public static Optional<File> findPreferredWidgetFile(File targetdir)
	{
		if(!targetdir.exists())
			{ return Optional.empty(); }

		Util.massert(targetdir.isDirectory(), "Bad directory %s", targetdir);

		Map<String, File> filemap = Util.map2map(Util.listify(targetdir.listFiles()), file -> file.getName(), file -> file);

		for(String pref : Util.listify("widget.wisp", "widget.jsp"))
		{
			if(filemap.containsKey(pref))
				{ return Optional.of(filemap.get(pref)); }
		}

		for(String ext : Util.listify(".wisp", ".jsp"))
		{
			List<String> hits = Util.filter2list(filemap.keySet(), fname -> fname.endsWith(ext));

			if(!hits.isEmpty())
				{ return Optional.of(filemap.get(hits.get(0))); }

		}

		return Optional.empty();
	}


	public static Optional<ZipEntry> findZipSlipEntry(ZipFile probefile) throws IOException
	{
		// We're not actually expanding anything into this
		File basedir = new File("/this/is/not/a/real/path");
		Enumeration<? extends ZipEntry> zipen = probefile.entries();

		while(zipen.hasMoreElements()) {
			ZipEntry zent = zipen.nextElement();

			// Here we are being more strict than is truly required; paranoia is good
			if(zent.getName().contains(".."))
				{ return Optional.of(zent); }

			File kidfile = new File(basedir, zent.getName());
			String basepath = basedir.getCanonicalPath();
			String filepath = (new File(basedir, zent.getName())).getCanonicalPath();

			if(!filepath.startsWith(basepath + File.separator))
				{ return Optional.of(zent); }
		}

		return Optional.empty();

	}

	public static <S, T> T wrapOperation(S input, java.util.function.Function<S, T> myfunc)
	{
		try { return myfunc.apply(input); }
		catch (Exception ex) { throw new RuntimeException(ex); }

	}


	// http://stackoverflow.com/questions/607176/java-equivalent-to-javascripts-encodeuricomponent-that-produces-identical-outpu		
	// NB: this method may have performance implications when used excessively.
	static String myEncodeURIComponent(String s)
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



} 
