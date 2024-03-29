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

import io.webwidgets.core.WidgetOrg.*;


public class CoreUtil
{ 
	// This string is spliced into the code by the Python script when it is compiled
	// The compile script detects it's install directory
	public static final String WWIO_BASE_CONFIG_DIR = "WWIO_CONFIG_DIR_GOES_HERE";

	public static String BASE_WIDGET_NAME = "base";


	// This is used by the system to represent nulls. Sorry, you cannot have values that equal this literal string.
	// This much match the JS code.
	public static String MAGIC_NULL_STRING = "_x_NULL_y_";

	// Probably need a pluging that provides extra reserved names
	public static List<String> RESERVED_WIDGET_NAMES = Arrays.asList(
		MailSystem.MAILBOX_WIDGET_NAME,
		BASE_WIDGET_NAME
	);

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

	public static final File SHARED_CSS_ASSET_DIR = (new WidgetItem(WidgetUser.buildBackDoorSharedUser(), "css")).getWidgetBaseDir();
	public static final File SHARED_JSLIB_ASSET_DIR = (new WidgetItem(WidgetUser.buildBackDoorSharedUser(), "jslib")).getWidgetBaseDir();
	public static final File SHARED_IMAGE_ASSET_DIR = (new WidgetItem(WidgetUser.buildBackDoorSharedUser(), "image")).getWidgetBaseDir();



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

	public static synchronized String getWidgetCodeDir()
	{
		return WIDGET_CODE_DIR;
	}

	public static synchronized String getWidgetDbDir()
	{
		return WIDGET_DB_DIR;
	}


	public static WidgetItem getMasterWidget()
	{
		return new WidgetItem(WidgetUser.getSharedUser(), MASTER_WIDGET_NAME);
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


	// If true, the server will allow insecure connections
	// This config is read only once at system startup
	// The file contents must be the string "true" in order to return true
	public static boolean allowInsecureConnection()
	{
		return GlobalIndex.getSystemSetting()
								.getOrDefault(SystemPropEnum.INSECURE_ALLOW_MODE.toString(), "...")
								.equals(true+"");
	}


	public static Optional<String> maintenanceModeInfo()
	{
		return Optional.ofNullable(GlobalIndex.getSystemSetting().get(SystemPropEnum.MAINTENANCE_MODE.toString()));
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
	// TODO: this is in CoreDb
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

	// TODO: this should no longer be necessary/used
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
	

	// TODO: re-implement, move to extension package
	public static File convert2Excel(WidgetItem witem) 
	{
		Util.massert(witem.getLocalDbFile().exists(), "Widget Item DB not found at %s", witem.getLocalDbFile());

		/*
		String xlpath = String.format("%s/%s__%s.xlsx", CoreUtil.TEMP_EXCEL_DIR, witem.theOwner, witem.theName);

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


	public static Set<WidgetUser> getCodeFormatExemptSet(boolean strict)
	{
		String exemptlist = GlobalIndex.getSystemSetting(SystemPropEnum.CODE_FORMAT_EXEMPT_LIST).orElse("").trim();
		if(exemptlist.isEmpty())
			{ return Collections.emptySet(); }


		Set<WidgetUser> result = Util.treeset();
		for(String token : exemptlist.split(","))
		{
			Optional<WidgetUser> optuser = WidgetUser.softLookup(token);
			if(optuser.isPresent())
			{
				result.add(optuser.get());
				continue;
			}

			Util.massert(!strict, "Failed to find user in strict mode for token %s", token);
		}

		return result;
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

	public static Set<WidgetUser> getCodeFormatExemptSet()
	{
		return getCodeFormatExemptSet(false);
	}

    public static void zipDirectory(File zipsrc, File zipdst) {
        try (FileOutputStream fos = new FileOutputStream(zipdst); ZipOutputStream zos = new ZipOutputStream(fos)) {
            zipSub(zipsrc, zipsrc, zos);
        } catch (IOException ioex) {
        	throw new RuntimeException(ioex);
        }
    }

    private static void zipSub(File topdir, File onefile, ZipOutputStream zos) throws IOException {
        if (onefile.isDirectory()) {
            for (File file : onefile.listFiles()) 
				{ zipSub(topdir, file, zos); }
	        return;
	    }

        try (FileInputStream fis = new FileInputStream(onefile)) {
            String entrypath = getRelativePath(topdir, onefile);
            ZipEntry zipentry = new ZipEntry(entrypath);

            zos.putNextEntry(zipentry);
            FileUtils.in2out(fis, zos, false);
            zos.closeEntry();
        }
    }

    private static String getRelativePath(File topdir, File onefile) {
        return topdir.toPath().relativize(onefile.toPath()).toString();
    }
} 
