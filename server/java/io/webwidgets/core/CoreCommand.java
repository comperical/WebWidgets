
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 
import java.util.zip.*;
import java.nio.file.*;

import javax.script.*;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.DayCode;
import net.danburfoot.shared.TimeUtil;
import net.danburfoot.shared.CollUtil;
import net.danburfoot.shared.FileUtils;
import net.danburfoot.shared.TimeUtil.*;
import net.danburfoot.shared.CollUtil.*;
import net.danburfoot.shared.RunnableTech.*;
import net.danburfoot.shared.Util.SyscallWrapper;
import net.danburfoot.shared.CoreDb.QueryCollector;

import io.webwidgets.core.CoreUtil.*;
import io.webwidgets.core.AuthLogic.*;
import io.webwidgets.core.WidgetOrg.*;
import io.webwidgets.core.MailSystem.*;
import io.webwidgets.core.PluginCentral.*;
import io.webwidgets.core.ActionJackson.*;


public class CoreCommand
{

	public static void main(String[] args) throws Exception
	{
		ArgMap amap = ArgMap.getClArgMap(args);
		String simpleclass = args[0].replace("__", "$");
		
		ArgMapRunnable amr = getAmr(simpleclass);
		amr.initFromArgMap(amap);
		amr.runOp();
	}
		
	@SuppressWarnings("deprecation")
	private static ArgMapRunnable getAmr(String fullclass)
	{
		try {
			Class runnerclass = Class.forName(fullclass);
			Object runnerobj = runnerclass.newInstance();
			ArgMapRunnable amr = (ArgMapRunnable) runnerobj;
			return amr;
		} catch (ClassNotFoundException cnfex) {
			Util.pferr("Failed to find class %s\n", fullclass);
			throw new RuntimeException(cnfex);
		} catch (ClassCastException ccex) {
			Util.pferr("Failed to convert class %s into an ArgMapRunnable\n", fullclass);	
			throw new RuntimeException(ccex);
		} catch (InstantiationException inex) {
			Util.pferr("Failed to instantiate class %s with newInstance call, does it have 0-arg constructor?\n", fullclass);	
			throw new RuntimeException(inex);
		} catch (IllegalAccessException illex) {
			Util.pferr("Failed to instantiate class %s with newInstance call do to protection violation\n", fullclass);	
			throw new RuntimeException(illex);
		}
	}	

	public static class DropLiteColumnOp extends ArgMapRunnable
	{
		public void runOp()
		{
			WidgetUser wuser = WidgetUser.valueOf(_argMap.getStr("username"));
			String widgetname = _argMap.getStr("widgetname");
			WidgetItem dbitem = new WidgetItem(wuser, widgetname);
			Util.massert(dbitem.getLocalDbFile().exists());
			
			String tabname = _argMap.getStr("tabname");
			
			String newtabgimp = Util.sprintf("%s_gimp", tabname);
			
			Set<String> newcolset = getGimpColumnSet(dbitem, newtabgimp);
			
			Util.massert(newcolset != null, 
				"To start process, create an empty table named %s WITHOUT the desired column", newtabgimp);
			
			Util.pf("Okay, got NEW column set %s\n", newcolset);
			
			// Okay, we want to drop a column in SQLite. This is done by:
			// Creating new table without column.
			
			List<String> commlist = Util.vector();
			
			commlist.add(Util.sprintf("INSERT INTO %s (%s) SELECT %s FROM %s",
				newtabgimp, Util.join(newcolset, ","), Util.join(newcolset, ","), tabname));
			
			
			commlist.add(Util.sprintf("ALTER TABLE %s RENAME TO __%s", tabname, tabname));
			
			commlist.add(Util.sprintf("ALTER TABLE %s RENAME TO %s", newtabgimp, tabname));
			
			for(String onecomm : commlist)
			{
				Util.pf("\t%s\n", onecomm);	
				
			}
			
			
			if(!Util.checkOkay("Okay to proceed?"))
			{ 
				Util.pf("Aborting\n");
				return;
			}
			
			for(String onecomm : commlist)
			{
				CoreDb.execSqlUpdate(onecomm, dbitem);
			}			
			
			Util.pf("Okay, drop old table __%s when you are confident everything worked\n", tabname);
		}
		
		private Set<String> getGimpColumnSet(WidgetItem dbitem, String tabname)
		{
			try {
				QueryCollector qcol = CoreUtil.fullTableQuery(dbitem, tabname);
				
				if(qcol.getNumRec() > 0)
				{
					Util.pferr("Gimp table is non-empty, please clean it out first\n");
					return null;
				}
				
				return Util.treeset(qcol.getColumnList());
				
			} catch (Exception sqlex) {
				
				Util.pferr("Failed to query table %s, message is %s\n", tabname, sqlex.getMessage());
				return null;	
			}
		}
	}

	
	
	public static class ConvertWidget2Excel extends ArgMapRunnable implements HasDescription 
	{
		
		public String getDesc()
		{
			return "Convert a Widget DB to Excel\n" + 
			"This tool is a wrapper for a Python script\n" + 
			"The output XL file is stored in a standard tmp path\n";
		}
		
		public void runOp()
		{
			double alphatime = Util.curtime();
			
			WidgetUser username = WidgetUser.valueOf(_argMap.getStr("username"));
			String widgetname = _argMap.getStr("widgetname");
			
			WidgetItem witem = new WidgetItem(username, widgetname);
			CoreUtil.convert2Excel(witem);
			
			Util.pf("Conversion took %.03f seconds\n", (Util.curtime()-alphatime)/1000);
		}
		
	}
	
	public static class CleanDbArchive extends ArgMapRunnable implements HasDescription
	{
		public String getDesc()
		{
			return "Cleans out old DB archive directories";
		}
		
		
		public void runOp() throws Exception
		{
			Util.massert(false, "TODO: must reimplement");
			
			/*
			int maxkill = _argMap.getInt("maxkill", 5);
			CleverPath archdir = getArchiveDir();
			DayCode cutoff = DayCode.getToday().nDaysBefore(90);
			List<CleverPath> rmlist = Util.vector();
			
			for(CleverPath oneday : archdir.getS3KidList())
			{
			String[] tokens = oneday.getFullS3Key().split("/");
			
			// Util.pf("%s\n", Util.listify(tokens));
			
			DayCode dc = DayCode.lookup(tokens[tokens.length-1]);
			
			if(dc.compareTo(cutoff) < 0)
			{
			rmlist.add(oneday);	
			Util.pf("Path %s --- %s is before cutoff %s\n",
			oneday.getFullS3Key(), dc, cutoff);
			}
			
			if(rmlist.size() >= maxkill)
			{
			Util.pf("Have more than %d to remove, run again after this or run with maxkill= argument\n", maxkill);
			break;	
			}
			// Util.pf("Got day %s for dir %s\n", dc,
			}
			*/
			
			/*
			if(rmlist.isEmpty())
			{
			Util.pf("No directories older than 90 days\n");
			return;
			}
			
			Util.pf("Going to delete archive dirs as shown\n");
			
			if(!Util.checkOkay("Okay to proceed?"))
			{ return; }
			
			for(CleverPath old : rmlist)
			{
			// This prints debug info
			old.deleteFromS3();				
			}
			*/
		}
		
		private Object getArchiveDir()
		{
			// String archpath = Util.sprintf("%s/archive/", CoreUtil.SQLITE_DIR);
			// return CleverPath.buildFromPath(archpath);	
			return null;
		}

	}
	
	public static class MarkMaintenanceMode extends ArgMapRunnable implements HasDescription
	{
		
		public String getDesc() 
		{
			return 
			"Put the server in maintenance mode by creating a file at the appropriate path\n" + 
			Util.sprintf("The path is %s\n", WebUtil.MAINTENANCE_MODE_FILE);
		}
		
		public void runOp() 
		{
			Optional<String> prevmode = WebUtil.maintenanceModeInfo();
			if(prevmode.isPresent())
			{
				Util.pf("Server is already in maintenance mode: %s\n", prevmode.get());
				return;				
			}
			
			Util.pf("Okay, this will put the server in maintenance mode so no further updates can be processed\n");
			
			Util.pf("Enter your message: ");
			
			String mssgtext = Util.getUserInput();
			
			FileUtils.getWriterUtil()
			.setFile(WebUtil.MAINTENANCE_MODE_FILE)
			.writeLineListE(Util.listify(mssgtext));
			
			Util.pf("Okay, wrote file to path %s\n", WebUtil.MAINTENANCE_MODE_FILE);
			
			Util.pf("Confirm success by running this program again\n");
		}
	}
	
	public static class ClearMaintenanceMode extends ArgMapRunnable implements HasDescription {
		
		public String getDesc() 
		{
			return "Clears the maintenance mode flag, puts the server into activity mode";	
		}
		
		public void runOp() 
		{
			Optional<String> prevmode = WebUtil.maintenanceModeInfo();
			if(!prevmode.isPresent())
			{
				Util.pf("Server is not in maintenance mode!!\n");
				return;				
			}
			
			Util.pf("This command will clear the maintenance mode flag, so users will be able to update their widgets again\n");
			
			if(Util.checkOkay("Okay to proceed? [yes/NO]")) 
			{
				WebUtil.MAINTENANCE_MODE_FILE.delete();	
				Util.pf("Maintenance Mode flag deleted\n");
			}
			
			Optional<String> imempty = WebUtil.maintenanceModeInfo();
			Util.massert(imempty.isEmpty(),
				"Somehow still have a maintenance mode flag!! : %s", imempty);
		}
		
	}
	
	
	public static class CreateCode4User extends ArgMapRunnable 
	{
		public void runOp()
		{
			List<WidgetUser> userlist = getWidgetUserList(_argMap);

			for(WidgetUser wuser : userlist)
			{								
				// Create autogen dir, this will also create the widgetserve directory
				boolean didcreate = wuser.maybeCreateAutogenJsDir();
				if(didcreate)
				{
					Util.pf("Created AutoGen JS dir %s\n", wuser.getAutoGenJsDir());	
				}
				
				List<WidgetItem> itemlist = wuser.getUserWidgetList();
				for(WidgetItem witem : itemlist)
				{
					Util.pf("Attempting to create code for %s\n", witem);
					List<String> loglist = ActionJackson.createCode4Widget(witem);				
					for(String log : loglist)
						{ Util.pf("%s", log); }
				}			
			}
		}

		private static List<WidgetUser> getWidgetUserList(ArgMap amap)
		{
			String userstr = amap.get("username");
			if(userstr.equals("all"))
				{ return Util.vector(WidgetUser.values()); }

			return Util.listify(WidgetUser.valueOf(userstr));

		}
	}
	
	public static class CreateSingleWidgetCode extends ArgMapRunnable 
	{
		public void runOp()
		{
			WidgetUser wuser = WidgetUser.getDburfootUser();
			Util.massert(wuser.haveLocalDb(),
				"We do not have any local DBs for WidgetUser %s, you must create some before using this tool", wuser);
			
			// Create autogen dir, this will also create the widgetserve directory
			boolean didcreate = wuser.maybeCreateAutogenJsDir();
			if(didcreate)
			{
				Util.pf("Created AutoGen JS dir %s\n", wuser.getAutoGenJsDir());	
			}
			
			List<WidgetItem> itemlist = wuser.getUserWidgetList();
			for(WidgetItem witem : itemlist)
			{
				Util.pf("Attempting to create code for %s\n", witem);
				List<String> loglist = ActionJackson.createCode4Widget(witem);				
				for(String log : loglist)
					{ Util.pf("%s", log); }
			}			
		}
	}	
	
	public static class CreateBlankWidget extends ArgMapRunnable
	{
		public void runOp()
		{
			WidgetUser wuser = WidgetUser.valueOf(_argMap.getStr("username"));
			Util.massert(wuser.haveLocalDb(),
				"We do not have any local DBs for WidgetUser %s, you must create some before using this tool", wuser);
			
			String widgetname = _argMap.getStr("widgetname");
			Util.massert(widgetname.toLowerCase().equals(widgetname));
			
			WidgetItem witem = wuser.createBlankItem(widgetname);
			Util.pf("Created blank widget %s\n", witem);
		}
	}

	public static class DummyTestRunner extends ArgMapRunnable
	{
		public void runOp()
		{
			Util.pf("GOing to run some code!!\n");
		}
	}
	
	public static class DeleteWidget extends ArgMapRunnable
	{
		public void runOp()
		{
			WidgetUser wuser = WidgetUser.valueOf(_argMap.getStr("username"));
			Util.massert(wuser.haveLocalDb(),
				"We do not have any local DBs for WidgetUser %s, you must create some before using this tool", wuser);
			
			String widgetname = _argMap.getStr("widgetname");
			String reversed = _argMap.getStr("reversed");
			Util.massert(widgetname.toLowerCase().equals(widgetname));
			
			Set<String> curset = Util.map2set(wuser.getUserWidgetList(), witem -> witem.theName);
			Util.massert(curset.contains(widgetname),
				"That widget does not exist: %s", widgetname);
			
			wuser.checkAndDelete(widgetname, reversed);
		}
	}
	
	
	public static class ImportWidget extends ArgMapRunnable
	{
		
		public void runOp()
		{
			WidgetUser wuser = WidgetUser.valueOf(_argMap.getStr("username"));
			
			String widgetname = _argMap.getStr("widgetname");
			wuser.importFromTemplate(widgetname);
		}
	}
	
	public static class ImportDummyUserBase extends ArgMapRunnable implements HasDescription
	{
		public static final WidgetUser DUMMY_USER = WidgetUser.valueOf("rando");
		
		public String getDesc()
		{
			return 
			"Imports the base code from the dummy user to a new user's space\n" + 
			"You must run this AFTER doing folder setup";
		}
		
		public void runOp() throws IOException
		{
			WidgetUser wuser = WidgetUser.valueOf(_argMap.getStr("username"));
			
			listOrCopy(wuser, false);
			
			if(!Util.checkOkay("Okay to copy those?")) 
			{
				Util.pf("Quitting\n");
				return;
			}
			
			listOrCopy(wuser, true);
			
		}
		
		private void listOrCopy(WidgetUser wuser, boolean iscopy) throws IOException
		{
			File dmmybase = DUMMY_USER.getUserBaseDir();
			File userbase = wuser.getUserBaseDir();
			
			Util.massert(userbase.exists(), "User base directory %s does not exist, you must create", userbase);
			Util.massert(dmmybase.exists(), "Could not find dummy user base directory!!!");
			int copycount = 0;
			
			for(File dmmyfile : dmmybase.listFiles()) 
			{
				if(dmmyfile.isDirectory())
					{ continue; }
				
				String userpath = dmmyfile.toString().replace("/" + DUMMY_USER + "/", "/" + wuser + "/");
				File userfile = new File(userpath);
				
				Util.massert(!userfile.exists(),
					"User file %s already exists, you must explicitly delete before continuing", userfile);
				
				Util.pf("Going to copy:\n\t%s\n\t%s\n", dmmyfile, userfile);
				
				if(iscopy) {
					java.nio.file.Files.copy(dmmyfile.toPath(), userfile.toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING);
					copycount++;
				}
			}
			
			if (iscopy) {
				Util.pf("Copied %d files\n", copycount);
			}
		}
	}
	
	public static class CopyAdminWidgetStruct extends ArgMapRunnable
	{
		public void runOp() throws IOException
		{
			WidgetUser wuser = WidgetUser.valueOf(_argMap.getStr("username"));
			Util.massert(wuser.haveLocalDb(),
				"We do not have any local DBs for WidgetUser %s, you must create some before using this tool", wuser);
			
			String widgetname = _argMap.getStr("widgetname");
			
			WidgetItem srcdb = new WidgetItem(WidgetUser.getDburfootUser(), widgetname);
			WidgetItem dstdb = new WidgetItem(wuser, widgetname);
			
			Util.massert(srcdb.getLocalDbFile().exists(),
				"Could not find admin widget DB file %s", srcdb.getLocalDbFile());
			
			Util.massert(!dstdb.getLocalDbFile().exists(),
				"Destination DB %s already exists, please delete manually first",
				dstdb.getLocalDbPath());
			
			{
				java.nio.file.Files.copy(
					srcdb.getLocalDbFile().toPath(), 
					dstdb.getLocalDbFile().toPath(),
					java.nio.file.StandardCopyOption.REPLACE_EXISTING);
				
				Util.pf("Copied src/dst files: \n\t%s\n\t%s\n",
					srcdb.getLocalDbPath(), dstdb.getLocalDbPath());
			}
			
			// Make sure dstdb!!!
			removeTableData(dstdb);
		}
		
		private static void removeTableData(WidgetItem db) 
		{
			// Extra paranoia
			Util.massert(db.theOwner != WidgetUser.getDburfootUser());
			Set<String> tableset = CoreDb.getLiteTableNameSet(db);
			
			for(String tbl : tableset)
			{
				String trunc = Util.sprintf("DELETE FROM " + tbl);
				int delrow = CoreDb.execSqlUpdate(trunc, db);
				Util.pf("Cleaned %d records from table %s of %s\n",
					delrow, tbl, db.getLocalDbPath());
			}
		}
	}
	
	public static class SymLinkWidgetTemplate extends ArgMapRunnable
	{
		public void runOp()
		{
			WidgetUser wuser = WidgetUser.valueOf(_argMap.getStr("username"));
			String widgetname = _argMap.getStr("widgetname");
			
			WidgetItem template = new WidgetItem(WidgetUser.getDburfootUser(), widgetname);
			WidgetItem copyitem = new WidgetItem(wuser, widgetname);
			
			File basedir = template.getWidgetBaseDir();
			Util.massert(basedir.exists(),
				"Base Widget directory %s does not exist", basedir);
			
			File copydir = copyitem.getWidgetBaseDir();
			// Util.massert(!copydir.exists(), "Copy dir already exists, remove if you want to proceed", copydir);
			// copydir.mkdir();
			
			for(File srcfile : basedir.listFiles())
			{
				// TODO: this is fucked up, change this to something more standard
				// Temporary hack while undergoing big organization shift
				String dstfile = srcfile.toString().replace("lifecode/jsp", "widgetserve/" + wuser.toString());
				Util.pf("Linking:\n\t%s\n\t%s\n", srcfile, dstfile);
				
				String syscall = Util.sprintf("ln -s %s %s", srcfile, dstfile);
				SyscallWrapper syswrap = SyscallWrapper.build(syscall).execE();
			}
			
			
		}
	}	
	
	public static class CopyTableStructure extends ArgMapRunnable
	{
		// This thing sucks because you need to explicitly list out the table names!!!
		public void runOp()
		{
			String dbname = _argMap.getStr("dbname");
			String tabname = _argMap.getStr("tabname");
			
			WidgetUser wuser = WidgetUser.valueOf(_argMap.getStr("username"));
			Util.massert(wuser != WidgetUser.getDburfootUser());
			String wname = _argMap.getStr("widgetname");
			
			WidgetItem source = new WidgetItem(WidgetUser.getDburfootUser(), dbname);
			WidgetItem destin = new WidgetItem(wuser, wname);
			
			String create = CoreUtil.getCreateTableSql(source, tabname);
			Util.pf("CREATE statement is:\n\t%s\n", create);
			
			if(Util.checkOkay("Okay to run?"))
			{
				CoreDb.execSqlUpdate(create, destin);
				
			}
		}
	}
	
	public static class TransferAdminDb extends ArgMapRunnable
	{
		public void runOp()
		{
			String srcdb = _argMap.getStr("srcdb");
			String dstdb = _argMap.getStr("dstdb");
			String tabname = _argMap.getStr("tabname");
			
			WidgetItem source = new WidgetItem(WidgetUser.getDburfootUser(), srcdb);
			WidgetItem destin = new WidgetItem(WidgetUser.getDburfootUser(), dstdb);
			
			String create = CoreUtil.getCreateTableSql(source, tabname);
			Util.pf("CREATE statement is:\n\t%s\n", create);
			
			if(!Util.checkOkay("okay to run?"))
			{
				Util.pf("Quitting\n");
				return;
			}
			
			CoreDb.execSqlUpdate(create, destin);
			
			QueryCollector qcol = CoreUtil.fullTableQuery(source, tabname);
			Util.pf("Loaded %d records for admin table %s\n", qcol.recList().size(), tabname);
			Util.pf("Copying data to widget DB...\n");
			
			for(ArgMap onemap : qcol.recList())
			{
				CoreDb.upsertFromRecMap(destin, tabname, 1, convertArg2Link(onemap));
			}		
			
			Util.pf("... done\n");
		}
		
		static LinkedHashMap<String, Object> convertArg2Link(ArgMap argmap)
		{
			Util.massert(argmap.containsKey("id"),
				"ArgMap is missing ID column 'id', keys are %s", argmap.keySet());
			
			LinkedHashMap<String, Object> mymap = Util.linkedhashmap();
			mymap.put("id", argmap.get("id"));
			
			for(String k : argmap.keySet())
			{
				if(k.equals("id"))
					{ continue; }
				
				mymap.put(k, argmap.get(k));
			}
			
			return mymap;
		}
		
	}
	
	public static class ShowHashForStart extends ArgMapRunnable
	{
		
		public void runOp()
		{
			Console console = System.console();
			Util.massert(console != null, "Somehow failed to get a console instance");
			
			char[] passwordArray = console.readPassword("Enter your secret password: ");
			String acchash = AuthLogic.canonicalHash(new String(passwordArray)).toLowerCase();
			
			Util.pf("Access hash is %s\n", acchash);			
		}
	}
	
	public static class UpdateUserPassWord extends ArgMapRunnable
	{
		
		public void runOp()
		{
			WidgetUser wuser = WidgetUser.valueOf(_argMap.getStr("username"));
			
			Console console = System.console();
			Util.massert(console != null, "Somehow failed to get a console instance");
			
			char[] passwordArray = console.readPassword("Enter your secret password: ");
			String acchash = AuthLogic.canonicalHash(new String(passwordArray)).toLowerCase();
			
			wuser.hardPasswordUpdate(acchash);

			Util.pf("Updated password for user %s, now run %s to confirm password\n",
				wuser, CheckUserPassword.class.getSimpleName());			
			
			Util.pf("Remember to restart web server to pick up new password data\n");
		}
		
		private int lookupUserId(WidgetUser wuser)
		{
			WidgetItem master = CoreUtil.getMasterWidget();		
			QueryCollector qcol = QueryCollector.buildAndRun(
				Util.sprintf("SELECT id FROM user_main WHERE username = '%s'", wuser), master);
			int userid = qcol.getSingleArgMap().getSingleInt();			
			return userid;			
		}
	}
	
	
	
	public static class AddUserMasterRecord extends LogSwapRunnable
	{
		public void runOp()
		{
			String username = _argMap.getStr("username");
			dumbCheckUnique(username);
						
			QueryCollector qcol = QueryCollector.buildAndRun("SELECT max(id) FROM user_main", CoreUtil.getMasterWidget());
			int curmaxid = qcol.getSingleArgMap().getSingleInt();
			
			CoreDb.upsertFromRecMap(CoreUtil.getMasterWidget(), "user_main", 1, CoreDb.getRecMap(
				"id", curmaxid+1,
				"username", username,
				"accesshash", WidgetUser.getDummyHash(),
				"email", ""
			));

			// TODO: keeping too many indices around here. Need to get rid of some, simplify this.	
			// This feels dangerous - I am running this from both the CLI and from the WebApp
			// 
			GlobalIndex.clearUserIndexes();
			createUserDir(username);
			
			
			mypf("Added master record for user %s. This script no longer sets password, use %s to do so", 
				username, UpdateUserPassWord.class.getSimpleName());
		}

		private static void dumbCheckUnique(String username)
		{
			Optional<WidgetUser> dummy = WidgetUser.softLookup(username);
			Util.massert(!dummy.isPresent(), "User name %s already present in the Master DB!!", username);
		}

		private void createUserDir(String username)
		{
			WidgetUser user = WidgetUser.lookup(username);
			Util.massert(user != null, "Failed to lookup WidgetUser for username %s", username);

			List<File> ndirlist = Util.listify(user.getUserBaseDir(), user.getDbDir());

			for(File ndir : ndirlist)
			{
				Util.massert(!ndir.exists(), "This directory already exists!! Config error!!");
				ndir.mkdir();
				mypf("Created directory %s\n", ndir);		
			}
		}
	}	

	public static class MasterDeleteUser extends LogSwapRunnable
	{
		public void runOp() throws IOException
		{
			String username = _argMap.getStr("username");
			String checkconfirm = new StringBuilder(_argMap.getStr("checkconfirm")).reverse().toString();

			Optional<WidgetUser> lookup = WidgetUser.softLookup(username);
			Util.massert(lookup.isPresent(), "Failed to find user with name %s", username);

			Util.massert(username.equals(checkconfirm),
				"You need to confirm delete by using checkconfirm= argument to be REVERSE of username");

			deleteMasterRecord(username);

			List<File> rmlist = Util.listify(lookup.get().getUserBaseDir(), lookup.get().getDbDir());

			for(File rmdir : rmlist)
			{
				FileUtils.recursiveDeleteFile(rmdir);
				Util.pf("Deleted directory %s\n", rmdir);
			}

			Util.pf("Removed data related to user %s, remember to restart Resin\n", username);
		}

		private static void deleteMasterRecord(String username)
		{	
			int numdel = CoreDb.deleteFromColMap(CoreUtil.getMasterWidget(), "user_main", CoreDb.getRecMap(
				"username", username
			));

			Util.massert(numdel == 1, "Somehow failed to delete the right number of records, expected 1, got %d", numdel);
			Util.pf("Deleted master record from DB\n");
		}
	}	



	
	public static class CheckUserPassword extends ArgMapRunnable
	{
		public void runOp()
		{
			WidgetUser wuser = WidgetUser.valueOf(_argMap.getStr("username"));
			Console console = System.console();
			Util.massert(console != null, "Somehow failed to get a console instance");
			
			console.printf("Checking password for user %s\n", wuser);
			char[] passwordArray = console.readPassword("Enter your secret password: ");
			String acchash = AuthLogic.canonicalHash(new String(passwordArray)).toLowerCase();
			Util.pf("Hashed password is %s\n", acchash.toLowerCase());			
			
			if(AuthLogic.checkCredential(wuser.toString(), acchash))
			{
				Util.pf("Password matches!!\n");
				return;
			}
			
			Util.pf("Password failed!!");
		}
	}
	
	public static class TestBaseExtractor extends ArgMapRunnable
	{
		public void runOp() throws Exception
		{
			WidgetUser wuser = WidgetUser.valueOf(_argMap.getStr("username"));
			
			CodeLocator codeloc = new CodeLocator(wuser, "base", UploadFileType.basezip);
			CodeExtractor codex = codeloc.getExtractor();
			
			File zipfile = codeloc.getCodeFile();
			Util.massert(zipfile.exists(), "Could not find Zip file at %s", zipfile);
			Util.pf("Found zip file %s\n", zipfile);
			
			codex.cleanOldCode();
			codex.extractCode(codeloc);
			
			for(String log : codex.getLogList())
			{
				Util.pf("%s", log);	
			}
		}
	}	
	
	
	public static class TestTableLoadTime extends ArgMapRunnable 
	{
		
		public void runOp()
		{
			Util.pf("Going to load table data!!\n");
			WidgetItem witem = new WidgetItem(WidgetUser.getDburfootUser(), "chinese");
			
			List<String> tables = Util.listify("review_log", "hanzi_data", "palace_item");
			
			for(int i : Util.range(1000))
			{
				
				double alpha = Util.curtime();
				for(String tbl : tables)
				{
					LiteTableInfo LTI = new LiteTableInfo(witem, tbl);
					LTI.runSetupQuery();
					List<String> reclist = LTI.composeDataRecSpool();
				}
				
				Util.pf("Loaded tables, took %.03f seconds\n", (Util.curtime()-alpha)/1000);
			}
		}
	}
	
	
	public static class TestScriptSolution extends ArgMapRunnable
	{
		public void runOp() throws Exception
		{
			
			ScriptEngineManager factory = new ScriptEngineManager();
			ScriptEngine engine = factory.getEngineByName("JavaScript");
			
			
			try {
				engine.eval("print(encodeURIComponent('\"A\" B ± \"'))");
			} catch (ScriptException screx) {
				throw screx;	
			}
		}
	}
	
	
	public static class ShowAutoInclude extends ArgMapRunnable
	{
		public void runOp()
		{
			WidgetItem item = new WidgetItem(WidgetUser.getDburfootUser(), "finance");

			for(String s : WebUtil.getAutoIncludeStatement(item))
			{
				Util.pf("Statement is \n\t%s\n", s);	
			}
		}
	}
	
	public static class ShowOrderedColumnList extends ArgMapRunnable
	{
		
		public void runOp()
		{
			/*
			WidgetItem widget = new WidgetItem(WidgetUser.getDburfootUser(), "media");
			String tablename = _argMap.getStr("tablename");
			List<String> ordercol = CoreUtil.getOrderedColumnList(widget, tablename);
			Util.pf("Ordered column list is %s\n", ordercol);
			*/
			
		}
	}
	
	
	public static class ShowSnippetInfo extends ArgMapRunnable
	{
		public void runOp()
		{
			TreeMap<Pair<Double, String>, List<String>> info = CoreUtil.getSnippetInfoMap("docs");
			
			for(Pair<Double, String> subcode : info.keySet())
			{
				Util.pf("Found %d lines of data for subcode %s\n", info.get(subcode).size(), subcode);	
			}
			
		}
		
		
		
	}
	
	
	
	
	public static class CheckRunTimeTest extends ArgMapRunnable 
	{
		public void runOp()
		{
			Util.pf("hello, time!!\n");
			
			long probemilli = 1650000000000L;
			
			ExactMoment ex_a = ExactMoment.build(probemilli);
			String astr = ex_a.asLongBasicTs(TimeZoneEnum.PST);
			
			ExactMoment ex_b = ExactMoment.fromLongBasicE(astr, TimeZoneEnum.PST);
			String bstr = ex_b.asLongBasicTs(TimeZoneEnum.PST);
			
			Util.pf("M1:\t%d\n", probemilli);
			Util.pf("M2:\t%d\n", ex_b.getEpochTimeMilli());
			
			Util.pf("A/B:\n\t%s\n\t%s\n", astr, bstr);
			
			/*
			const nowex = new ExactMoment(probemilli);
			
			const isostr = nowex.asIsoLongBasic(timezone);
			
			const backex = exactMomentFromIsoBasic(isostr, timezone);
			
			const backstr = backex.asIsoLongBasic(timezone);
			*/
			
		}
	}
	
	public static class TestAmaMail extends ArgMapRunnable
	{
		
		public void runOp() throws Exception
		{
			Util.pf("Enter the email content: \t");
			String emailContent = Util.getUserInput();
			
			WidgetMail mail = WidgetMail
								.build(WidgetUser.getDburfootUser())
								.setSubject("Hello from WebWidgets!!")
								.setRecipEmail("daniel.burfoot@gmail.com");
			
			mail.setContent(String.format("<html><body>%s</body></html>", emailContent));
			
			Map<Integer, WidgetMail> mymap = Util.treemap();
			mymap.put(444, mail);
			
			IMailSender sender = PluginCentral.getMailPlugin();

			sender.sendMailPackage(mymap, mid -> Util.pf("Email %d sent okay\n", mid));
			
			Util.pf("mailing was successful!!!\n");
		}
	}
	
	public static class CreateMailBoxWidget extends ArgMapRunnable
	{
		public void runOp()
		{
			WidgetUser wuser = WidgetUser.valueOf(_argMap.getStr("username"));
			
			MailSystem.createMailBox4User(wuser);
			
		}
		
	}
	
	public static class CreateDummyMail extends ArgMapRunnable
	{
		
		//CREATE TABLE outgoing (id int, sent_at_utc varchar(19), send_target_utc varchar(19), recipient varchar(100), subject varchar(100), email_content varchar(1000), is_text smallint, primary key(id))
		
		public void runOp()
		{
			WidgetUser wuser = WidgetUser.getDburfootUser();
			WidgetItem mailbox = new WidgetItem(wuser, "mailbox");
			String sendtarget = ExactMoment.build().asLongBasicTs(TimeZoneEnum.UTC);
			
			for(int i : Util.range(2, 10)) 
			{
				CoreDb.upsertFromRecMap(mailbox, "outgoing", 1, CoreDb.getRecMap(
					"id", i,
					"sent_at_utc", "",
					"send_target_utc", sendtarget,
					"recipient", "daniel.burfoot@gmail.com",
					"subject", "The world is ending!!",
					"email_content", "You are going to be out of the game soon, fool!!",
					"is_text", 1
					));
			}
		}
	}
	
	public static class LoadMailReadyMap extends ArgMapRunnable
	{
		
		//CREATE TABLE outgoing (id int, sent_at_utc varchar(19), send_target_utc varchar(19), recipient varchar(100), subject varchar(100), email_content varchar(1000), is_text smallint, primary key(id))
		
		public void runOp()
		{
			WidgetUser wuser = WidgetUser.getDburfootUser();
			Map<Integer, WidgetMail> readymap = MailSystem.loadReadyMailForUser(wuser);
			
			Util.pf("Have readymap %s\n", readymap);
		}
	}
	
	public static class SendSingleReadyMail extends ArgMapRunnable
	{
		public void runOp()
		{
			WidgetUser wuser = WidgetUser.getDburfootUser();
			List<String> resultlist = MailSystem.sendSingleReadyMailForUser(wuser);
			
			for(String result : resultlist)
				{ Util.pf("%s\n", result); }
		}
		
	}
	
	public static class GrantUserPermission extends ArgMapRunnable 
	{
		public void runOp() 
		{
			WidgetUser owner = WidgetUser.valueOf(_argMap.getStr("owner"));
			String widgetname = _argMap.getStr("widgetname");
			WidgetItem item = new WidgetItem(owner, widgetname);
			
			WidgetUser grantee = WidgetUser.valueOf(_argMap.get("grantee"));
			PermLevel perm = PermLevel.valueOf(_argMap.getStr("perm"));

			AuthLogic.assignPermToGrantee(item, grantee, perm);

			Util.pf("Authorization granted, remember to restart Resin\n");
		}
	}
	
	public static class JustLoadPermTable extends ArgMapRunnable 
	{
		
		public void runOp() 
		{
			AuthLogic.reloadPermTable();
			
		}
	}	
	
	public static class CheckPermForWidget extends ArgMapRunnable 
	{
		
		public void runOp() 
		{
			WidgetUser owner = WidgetUser.valueOf(_argMap.getStr("username"));
			String widgetname = _argMap.getStr("widgetname");
			WidgetItem dbitem = new WidgetItem(owner, widgetname);
			
			for(WidgetUser accessor : WidgetUser.values())
			{
				Optional<PermLevel> perm = AuthLogic.getPermInfo4Widget(dbitem).getPerm4Accessor(Optional.of(accessor));
				if(!perm.isEmpty())
					{ Util.pf("For widget %s --> grantee %s, have perm=%s\n", dbitem, accessor, perm.get()); }
			}
		}
	}		
	
	public static class UpdateSysTestBlob extends ArgMapRunnable
	{
		
		public void runOp()
		{
			WidgetItem blob = new WidgetItem(WidgetUser.getDburfootUser(), "systest");
			
			CoreDb.upsertFromRecMap(blob, "blob_test", 1, CoreDb.getRecMap(
				"id", 0,
				"base64_blob_data", 45,
				"blob_address", "/dburfoot/systest/blob_test/blob__00001",
				"blob_file_name", "FunnySentencePlayground2.jpg"
				));
		}
		
	}
	
	public static class TestBlobPullTech extends ArgMapRunnable
	{
		
		public void runOp()
		{
			WidgetItem blob = new WidgetItem(WidgetUser.getDburfootUser(), "systest");
			int recordid = _argMap.getInt("recordid");
			
			String query = String.format("SELECT * FROM blob_test WHERE id = %d", recordid);
			ArgMap onemap = QueryCollector.buildAndRun(query, blob).getSingleArgMap();
			Util.pf("loaded the arg map \n");
			// Util.pf("Result is %s\n", onemap);
			
			LiteTableInfo LTI = new LiteTableInfo(blob, "blob_test");
			
			BlobDataManager.optProcessBlobInput(LTI, Util.cast(onemap));
			
			
			CoreDb.upsertFromRecMap(blob, "blob_test", 1, convertArgMap(onemap));
			
		}
		
		private static LinkedHashMap<String, Object> convertArgMap(ArgMap record) 
		{
			LinkedHashMap<String, Object> idfirst = Util.linkedhashmap();
			
			idfirst.put("id", record.getInt("id"));
			
			for(String k : record.keySet()) 
			{
				if(!k.equals("id"))
					{ idfirst.put(k, record.get(k)); }
			}
			
			return idfirst;
		}
		
	}
	
	public static class EmailCheckAndSend extends DescRunnable implements CrontabRunnable
	{
		public String getDesc()
		{
			return 
			"This is the canonical Email check/send system\n" +    
			"It probes every WidgetUser to see if they have a MAILBOX message DB\n" + 
			"If so, runs the canonical query on the outbox table, to see if they have any ready and unsent message\n" + 
			"It sends the message and updates the DB\n" +
			"TODO: current implementation is actually a little bit wrong because it could allow multi-send of emails\n" +
			"if there is a gap between when user selects SEND NEXT MAIL from console, and when this code loads emails"; 
		}
		
		
		public void runOp() throws Exception
		{
			List<WidgetUser> mailuser = Util.filter2list(WidgetUser.values(), wuser -> MailSystem.userHasMailBox(wuser));
			
			TreeMap<Pair<WidgetUser, Integer>, WidgetMail> bigMailMap = Util.treemap();
			
			for(WidgetUser user : mailuser)
			{
				Map<Integer, WidgetMail> usermail = MailSystem.loadReadyMailForUser(user, Optional.of(MailSystem.MAX_EMAIL_PER_USER_BLOCK));
				Util.pf("Found configured mailbox for user %s, with %d ready mails\n", user, usermail.size());
				
				for(Integer mailid : usermail.keySet())
				{
					bigMailMap.put(Pair.build(user, mailid), usermail.get(mailid));
				}
			}
			
			if(bigMailMap.isEmpty())
			{
				Util.pf("No emails ready to send, quitting\n");
				return;
			}
			
			IMailSender sender = PluginCentral.getMailPlugin();
			sender.sendMailPackage(bigMailMap, idpair -> MailSystem.markMailSentAt(idpair._1, idpair._2));
			
			Util.pf("Sent %d emails successfully, first %s, last %s\n", 
				bigMailMap.size(), bigMailMap.firstKey(), bigMailMap.lastKey());
		}
	}

	public static class GoogleSyncAdmin extends DescRunnable
	{

		protected boolean opSuccess = false;

		public String getDesc()
		{
			return 
				"Run the Google Sync operation from the command line\n" + 
				"This calls the Python script as a system call\n" + 
				"Forwards any error information to the console\n";
		}

		protected WidgetItem getDbItem() 
		{
			WidgetUser user = WidgetUser.valueOf(_argMap.getStr("username"));
			String widgetname = _argMap.getStr("widgetname");
			return new WidgetItem(user, widgetname);
		}

		public void runOp()
		{
			WidgetItem witem = getDbItem();
			Util.massert(witem.getLocalDbFile().exists(), "Widget %s does not exist", witem);

			Map<Boolean, List<String>> result = GoogleSyncUtil.googleSyncWrapper(witem);
			
			for(boolean isout : result.keySet())
			{
				Util.pf("%s::\n", isout ? "OUT" : "ERR");
				
				List<String> output = result.get(isout);
				
				for(String out : output) 
					{ Util.pf("\t%s\n", out); }
				
				if(isout)
					{ opSuccess = Util.countPred(output, ln -> ln.contains("SUCCESS")) > 0;} 
			}
			
			if(opSuccess)
			{
				Util.pf("Operation apparently worked, see above\n");
				return;
			}
			
			Util.pf("Problems detected on operation, see above\n");
		}
	}    	


	public static class ArchiveDb2Cloud extends ArgMapRunnable implements HasDescription, CrontabRunnable
	{
		public String getDesc()
		{
			return "Archives the Life DATA SQLite files to S3";
		}
		
		public void runOp() throws Exception
		{
			DayCode dc = DayCode.getToday();
			
			if(_argMap.containsKey("daycode"))
			{
				// This is useful only for "backfill" purposes, 
				// To make sure we have all the backup paths the automated check code requires
				dc = DayCode.lookup(_argMap.getStr("daycode"));	
				Util.pf("Using non-standard daycode %s for backup\n", dc);
			}
			
			for(WidgetUser user : WidgetUser.values())
			{
				for(WidgetItem dbitem : user.getUserWidgetList())
				{
					File localdb = dbitem.getLocalDbFile();
					File archfile = getDbArchiveFile(dbitem, dc);
					PluginCentral.getStorageTool().uploadLocalToTarget(localdb, archfile);
				}
			}
		}

		// This is a "virtual" file, meaning that it is never actually used
		// It is just a coordinate that gets passed to the blob storage
		private static File getDbArchiveFile(WidgetItem dbitem, DayCode dc)
		{
			String localpath = Util.sprintf("%s/%s/%s/%s", CoreUtil.DB_ARCHIVE_DIR, 
				dc, dbitem.theOwner, dbitem.getLocalDbFile().getName());

			return new File(localpath);
		}
	}


	public static class GrabRecentDbArchive extends ArgMapRunnable
	{

		public void runOp() throws IOException 
		{
			DayCode daycode = DayCode.lookup(_argMap.getStr("daycode"));
			int grabCount = 0;

			String archivebase = String.format("%s/%s", CoreUtil.DB_ARCHIVE_DIR, daycode);
			Util.pf("Going to examine base directory %s\n", archivebase);

			//TODO: rebuild this to use single S3 cmd
			/*
			for(WidgetUser theUser : WidgetUser.values())
			{
				File dbdir = new File(theUser.getDbDirPath());
				if (!dbdir.exists())
				{
					dbdir.mkdir();
					Util.pf("Created DB directory %s for user\n", dbdir);
				}
			}

			for(WidgetUser theUser : WidgetUser.values())
			{

				CleverPath archdir = ArchiveDb2Cloud.getUserArchiveDir(theUser, daycode);

				List<CleverPath> kidlist = archdir.getS3KidList();

				for(CleverPath kid : kidlist)
				{

					File localfile = kid.getLocalFile();

					String filename = localfile.getName();

					// Util.pf("Kid path is %s, local file is %s\n", kid, filename);

					Util.massert(filename.endsWith("_DB.sqlite"), "Expected _DB.sqlite suffix, found %s", filename);

					String widgetname = CoreUtil.peelSuffix(filename, "_DB.sqlite").toLowerCase();

					// Util.pf("Found wiget name %s\n", widgetname);

					WidgetItem dbItem = new WidgetItem(theUser, widgetname);


					// Util.pf("Local DB file is %s\n", dbItem.getLocalDbFile());

					if(dbItem.getLocalDbFile().exists())
					{
						Util.pf("Widget file already exists, skipping : %s\n", dbItem.getLocalDbPath());
						continue;
					} else {

						Util.pf("Local DB file does NOT exist %s\n", dbItem.getLocalDbFile());
					}

					kid.downloadFromS3();

					kid.getLocalFile().renameTo(dbItem.getLocalDbFile());

					Util.massert(dbItem.getLocalDbFile().exists());

					grabCount++;

					Util.pf("Grabbed widget %s: \n\t%s\n\t%s\n", dbItem, kid.getFullS3Key(), dbItem.getLocalDbFile());

				}
			}

			Util.pf("Grabbed %d db files from S3 archive\n", grabCount);

			*/

		}

	}

	public static class BlobCacheCleaner extends DescRunnable implements CrontabRunnable
	{
		public String getDesc()
		{
			return 
				"Search through the Blob Data disk cache\n" + 
				"Find old files and delete them";
		}

		public void runOp()
		{
			int maxkill = _argMap.getInt("maxkill", 1);
			LinkedList<File> bloblist = Util.linkedlistify(CoreUtil.getAllFileList(new File(CoreUtil.WWIO_BLOB_BASE_DIR)));
			CollUtil.sortListByFunction(bloblist, f -> f.lastModified());
			Util.pf("Got %d blob files\n", bloblist.size());

			long removesize = 0L;
			int totalremove = 0;
			long cutoff = System.currentTimeMillis() - (3 * TimeUtil.DAY_MILLI);


			while(!bloblist.isEmpty())
			{
				File nextup = bloblist.poll();
				long filesize = nextup.length();
				long modtime = nextup.lastModified();

				if(modtime > cutoff)
					{ break; }

				nextup.delete();
				String tstamp = ExactMoment.build(modtime).asLongBasicTs(TimeZoneEnum.EST);
				Util.pf("Removed file %s, modtime %s EST, filesize %d\n", nextup, tstamp, filesize);

				totalremove += 1;
				removesize += filesize;

				if(totalremove >= maxkill)
					{ break; }
			}

			Util.pf("Removed %d total files, reclaimed %d bytes of disk space\n", totalremove, removesize);
		}

	}

	public static class GeneratePermDataFile extends ArgMapRunnable
	{
		public static String PERM_DATA_FILE = "/Users/burfoot/Desktop/PERM_FILE.txt";

		public void runOp()
		{

			List<String> datafile = generateFullDataRep();
			FileUtils.getWriterUtil().setFile(PERM_DATA_FILE).writeLineListE(datafile);

			Util.pf("Wrote %d lines to path %s\n", datafile.size(), PERM_DATA_FILE);

		}

		private static List<String> loadDataFile()
		{
			return FileUtils.getReaderUtil().setFile(PERM_DATA_FILE).readLineListE();
		}

		private static List<String> generateFullDataRep()
		{
			WidgetItem permdb = new WidgetItem(WidgetUser.getDburfootUser(), "master");

			QueryCollector qcol = CoreUtil.fullTableQuery(permdb, "perm_grant");

			Set<WidgetItem> dbset = Util.map2set(qcol.recList(), 
				amap -> new WidgetItem(WidgetUser.lookup(amap.getStr("owner")), amap.getStr("widget_name")));

			// Need to order these, they are not ordered by default
			TreeSet<WidgetUser> orderset = Util.treeset(WidgetUser.values());
			List<String> datafile = Util.vector();
			for(WidgetItem dbitem : dbset)
			{
				for(WidgetUser grantee : orderset)
				{

					Optional<PermLevel> optperm = AuthLogic.getPermInfo4Widget(dbitem).getPerm4Accessor(Optional.of(grantee));

					List<String> tokens = Util.listify(
						dbitem.theOwner.toString(),
						dbitem.theName,
						optperm.isPresent() ? optperm.get().toString() : "none",
						grantee.toString()
					);

					datafile.add(Util.join(tokens, "\t"));
				}
			}

			return datafile;
		}		

	}


	public static class CheckPermDataFile extends ArgMapRunnable
	{

		public void runOp()
		{

			List<String> datafile = GeneratePermDataFile.loadDataFile();
			List<String> current = GeneratePermDataFile.generateFullDataRep();

			Util.massert(datafile.equals(current), "Discrepancy detected!!!");
			Util.pf("Success, files are identical!!\n");
		}
	}

	public static class AddPermToWidget extends ArgMapRunnable
	{

		public void runOp()
		{
			WidgetItem sysitem = new WidgetItem(WidgetUser.getDburfootUser(), "systest");

			WidgetUser grantee = WidgetUser.lookup(_argMap.getStr("grantee"));

			AuthLogic.assignPermToGrantee(sysitem, grantee, PermLevel.read);

		}

	}

	public static class RevokePerm extends ArgMapRunnable
	{

		public void runOp()
		{
			WidgetItem sysitem = new WidgetItem(WidgetUser.getDburfootUser(), "systest");

			WidgetUser grantee = WidgetUser.lookup(_argMap.getStr("grantee"));

			AuthLogic.removePermFromGrantee(sysitem, grantee);

		}

	}


	public static class MarkPublicRead extends ArgMapRunnable
	{

		public void runOp()
		{
			WidgetUser user = WidgetUser.lookup(_argMap.getStr("username"));
			WidgetItem item = new WidgetItem(user, _argMap.getStr("widgetname"));

			boolean isread = _argMap.getBit("read", false);

			AuthLogic.markPublicRead(item, isread);

		}

	}	

	public static class TestIntegerError extends ArgMapRunnable
	{

		public void runOp()
		{
			ArgMap mymap = new ArgMap();
			mymap.put("danb", "1000000000000000000");

			int result = mymap.getInt("danb");
		}

	}


	public static class ShowBaseConfigInfo extends ArgMapRunnable
	{
		public void runOp()
		{
			Util.pf("Have config directory %s\n", CoreUtil.WWIO_BASE_CONFIG_DIR);
		}

	}


}




