
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 
import java.nio.file.*;

import java.time.LocalDate;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.FileUtils;
import net.danburfoot.shared.CollUtil.*;
import net.danburfoot.shared.CoreDb.QueryCollector;
import net.danburfoot.shared.CoreDb.ConnectionSource;


	
public class WidgetItem implements ConnectionSource, Comparable<WidgetItem>
{
	public final WidgetUser theOwner;
	
	public final String theName;
	
	// This Widget does not have a DB associated with it,
	// it is "virtuaL";
	public final boolean isVirtual;
	
	public WidgetItem(WidgetUser user, String name)
	{
		this(user, name, false);
	}
	
	private WidgetItem(WidgetUser user, String name, boolean isvirt)
	{
		theOwner = user;
		theName = name;
		isVirtual = isvirt;

		Util.massert(theOwner != null && name != null, 
			"Attempt to create WidgetItem with null owner (%s) or name (%s)", theOwner, name);
	}
			

	// TODO: it's a bad idea to have the Master widget be owned by the shared user
	// Shared user assets are totally public, but master widget is maximally private!!!
	public static WidgetItem getMasterWidget()
	{
		return new WidgetItem(WidgetUser.getSharedUser(), CoreUtil.MASTER_WIDGET_NAME);
	}

    public static WidgetItem userBaseWidget(WidgetUser owner)
    {
        return new WidgetItem(owner, CoreUtil.BASE_WIDGET_NAME, true);
    }

    public static WidgetItem createBlankItem(WidgetUser owner, String newname)
    {
        WidgetItem witem = new WidgetItem(owner, newname);
        witem.createEmptyLocalDb();
        witem.createLocalDataFile();
        return witem;
    }


	public Connection createConnection() throws SQLException
	{
		CoreUtil.maybeInitClass();
		return DriverManager.getConnection(geJdbcUrl(), CoreDb.getSqliteConfigProps());
	}
	
	public String getCheckSumKey()
	{
		return String.format("%s::%s", theOwner, theName);
	}
	
	public long getDbCheckSum()
	{
		return CoreUtil.getFileCkSum(getLocalDbFile());
	}
	
	public String getLocalMachinePath() 
	{
		return getLocalDbPath();
	}
	
	public String getLocalDbPath()
	{
		Util.massert(!isVirtual, 
			"Attempt to get local machine path of virtual widget");
		
		return String.format("%s/%s_DB.sqlite", 
			theOwner.getDbDirPath(), theName.toUpperCase());
	}

	public boolean equals(WidgetItem other)
	{
		return compareTo(other) == 0;
	}
	
	public File getLocalDbFile()
	{
		return new File(getLocalDbPath());
	}

	public boolean dbFileExists()
	{
		return getLocalDbFile().exists();
	}

	public File getAutoGenJsDir()
	{
		String userdir = theOwner.getAutoGenJsDir().getAbsolutePath();
		String bdir = userdir + "/" + theName;
		return new File(bdir);
	}
	
	public int compareTo(WidgetItem other) 
	{
		return this.asPair().compareTo(other.asPair());
	}

	private Pair<WidgetUser, String> asPair() 
	{
		return Pair.build(theOwner, theName);
	}

	void createEmptyLocalDb()
	{
		File dbfile = new File(getLocalDbPath());
		if(dbfile.exists())
		{
			Util.pf("Local DB file %s already exists\n", dbfile);
			return;
		}
		
		// Create table and immediately drop it to create empty file.
		CoreDb.execSqlUpdate("CREATE TABLE __gimp (id int)", this);
		CoreDb.execSqlUpdate("DROP TABLE __gimp", this);
		
		Util.pf("Created empty SQLite file at %s\n", dbfile);
	}
			
	void createLocalDataFile()
	{
		File srcdir = theOwner.getUserBaseDir();
		Util.massert(srcdir.exists(), 
			"User source dir not present " + srcdir);
		
		File wdir = new File(Util.sprintf("%s/%s", srcdir, theName));
		if(!wdir.exists())
		{
			Util.pf("Creating directory: %s\n", wdir);
			wdir.mkdir();
		}
	}
	
	public File getWidgetBaseDir()
	{
		File userdir = theOwner.getUserBaseDir();
		String wdir = Util.sprintf("%s/%s", userdir.toString(), theName);
		return new File(wdir);
	}
	
	public String getRelativeBaseDir()
	{
		return String.format("/u/%s/%s", theOwner.toString(), theName);
	}


	public Optional<File> findPreferredTargetPage()
	{
		return CoreUtil.findPreferredWidgetFile(getWidgetBaseDir());
	}

	private List<String> getDefaultWidgetSrc()
	{
		return Util.listify("<html><body></body></html");
	}
	
	private String geJdbcUrl()
	{
		return Util.sprintf("jdbc:sqlite:%s", getLocalDbPath());
	}
	
	public Set<String> getDbTableNameSet()
	{
		// False: do not show __ - prefix tables
		return CoreUtil.getLiteTableNameSet(this, false);
	}

	public Set<String> getDbViewNameSet()
	{
		return CoreDb.getLiteViewNameSet(this);
	}
	
	public String toString()
	{
		return Util.sprintf("%s::%s", theOwner.toString(), theName);
	}

	public List<String> createJsCode()
	{
		List<String> loglist = Util.vector();
		File autogendir = getAutoGenJsDir();
		
		if(!autogendir.exists())
		{
			autogendir.mkdirs();
			loglist.add(Util.sprintf("Created directory %s\n", autogendir));
		}
		
		for(String dbname : getDbTableNameSet())
		{
			LiteTableInfo tinfo = new LiteTableInfo(this, dbname);
			tinfo.runSetupQuery();
			
			// dogenerate = true
			loglist.addAll(CodeGenerator.maybeUpdateCode4Table(tinfo, true));
		}
		
		return loglist;
	}



    public static List<WidgetItem> getUserWidgetList(WidgetUser user)
    {
        File dbdir = new File(user.getDbDirPath());
        List<File> flist = dbdir.listFiles() == null ? Collections.emptyList() : Util.listify(dbdir.listFiles());

        List<WidgetItem> result = Util.vector();
        for(File f : flist)
        {
            String fn = f.getName();
            int suffix = fn.indexOf("_DB.sqlite");
            Util.massert(suffix != -1,
                "Bad file in database dir: %s", fn);
            
            String wname = fn.substring(0, suffix);
            Util.massert(wname.toUpperCase().equals(wname),
                "Widget DB names should be uppercase, got %s", wname);
            
            WidgetItem witem = new WidgetItem(user, wname.toLowerCase());
            result.add(witem);
        }
        
        return result;
    }

	private boolean haveRecordWithId(String tabname, int rid) 
	{
		String query = String.format("SELECT * FROM %s WHERE id = %d", tabname, rid);
		int numrec = QueryCollector.buildAndRun(query, this).getNumRec();
		Util.massert(numrec == 0 || numrec == 1, 
			"Violation of DB contract for table %s, ID %d, multiple records found", tabname, rid);

		return numrec == 1;
	}

	public int newRandomId(String tabname)
	{
		// This has been checked before. We check again out of paranoia
		// this is protection against SQL injection attacks
		Util.massert(getDbTableNameSet().contains(tabname),
			"Table Name %s not present for widget %s", tabname, this);


		Set<Integer> newid = CoreUtil.canonicalRandomIdCreate(
			probe -> !this.haveRecordWithId(tabname, probe), new Random(), 1
		);

		return newid.iterator().next();
	}


	// Delete the widget, including both the DB file and the code directory
	// For safety, require the reversed name of the widget as an argument (user input)
    public void checkAndDelete(String wreverse)
    {
        {
            String checkit = new StringBuilder(theName).reverse().toString();
            Util.massert(wreverse.equals(checkit),
                "You must enter the widget name REVERSED, got %s", wreverse);
        }
        
        // Require that the DB file is present. If there is a subdirectory but not a DB file,
        // that should cause some other alarm
        Util.massert(dbFileExists(), "The DB file for this widget %s does not exist", this);
        
        File dbfile = getLocalDbFile();
        if(dbfile.exists())
        {
            dbfile.delete();
            Util.pf("Deleted DB file %s\n", dbfile);
        }
        
        File localdir = getWidgetBaseDir();
        if(!localdir.exists())
        	{ return; }

        try 
            { FileUtils.recursiveDeleteFile(localdir); }
        catch (IOException ioex) 
            { throw new RuntimeException(ioex); }
            
        Util.pf("Deleted local dir %s\n", localdir);
    }
}

