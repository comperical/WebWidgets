
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


// TODO: this can be just WidgetItem
public class WidgetOrg
{ 
	
	public static class WidgetItem implements ConnectionSource, Comparable<WidgetItem>
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
		
		WidgetItem(WidgetUser user, String name, boolean isvirt)
		{
			theOwner = user;
			theName = name;
			isVirtual = isvirt;

			Util.massert(theOwner != null && name != null, 
				"Attempt to create WidgetItem with null owner (%s) or name (%s)", theOwner, name);
		}
				
		
		public Connection createConnection() throws SQLException
		{
			
			CoreUtil.maybeInitClass();
			
			return DriverManager.getConnection(geJdbcUrl());
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
	}


} 

