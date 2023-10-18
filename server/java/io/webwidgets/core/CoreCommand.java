
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
			Util.sprintf("The path is %s\n", CoreUtil.MAINTENANCE_MODE_FILE);
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
						.setFile(CoreUtil.MAINTENANCE_MODE_FILE)
						.writeLineListE(Util.listify(mssgtext));
			
			Util.pf("Okay, wrote file to path %s\n", CoreUtil.MAINTENANCE_MODE_FILE);
			
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
				CoreUtil.MAINTENANCE_MODE_FILE.delete();
				Util.pf("Maintenance Mode flag deleted\n");
			}
			
			Optional<String> imempty = WebUtil.maintenanceModeInfo();
			Util.massert(imempty.isEmpty(),
				"Somehow still have a maintenance mode flag!! : %s", imempty);
		}
		
	}
	
	public static class SetupMasterDb extends DescRunnable
	{
		public String getDesc()
		{
			return 
				"This command will setup the MASTER DB under the shared user account\n" + 
				"This DB is used to store user information and other core data\n" + 
				"This command is used when setting up a new WWIO installation, as one of the first steps";
		}
		
		public void runOp()
		{
			WidgetUser shared = WidgetUser.buildBackDoorSharedUser();
			WidgetItem newmaster = new WidgetItem(shared, CoreUtil.MASTER_WIDGET_NAME);
						
			if(!shared.getDbDir().exists())
			{
				shared.getDbDir().mkdirs();
				Util.pf("Created shared user DB directory %s\n", shared.getDbDir());
			}

			Util.massert(!newmaster.dbFileExists(),
				"Already have master DB at path %s", newmaster.getLocalDbFile());
			
			newmaster.createEmptyLocalDb();
			Util.pf("Created new master DB at %s\n", newmaster.getLocalDbFile());
			
			for(MasterTable mtable : MasterTable.values())
			{
				CoreDb.execSqlUpdate(mtable.createSql, newmaster);
				Util.pf("Created MasterTable %s\n", mtable);
			}
			
			Util.pf("Created Master DB and initialized tables\n");
			
			createSharedUser(newmaster);
		}
		
		private static String getRandomInitialPass()
		{
			Random r = new Random();
			
			StringBuilder sb = new StringBuilder();
			
			sb.append("dummy");
			
			for(int i : Util.range(20))
				{ sb.append(r.nextInt(10)); }

			return sb.toString();
		}
		
		private void createSharedUser(WidgetItem newmast)
		{
			String sharedpass = getRandomInitialPass();
			
			CoreDb.upsertFromRecMap(newmast, MasterTable.user_main.toString(), 1, CoreDb.getRecMap(
				"id", 0,
				"username", WidgetUser.SHARED_USER_NAME,
				"accesshash", AuthLogic.canonicalHash(sharedpass),
				"email", ""
			));
			
			Util.pf("Created Shared user with random initial password, use %s to update if desired\n",
				UpdateUserPassWord.class.getSimpleName());
		}
	}

	public static class UpdateSystemSetting extends DescRunnable
	{
		public String getDesc()
		{
			return 
				"Update the system setting table\n" +
				"Simple key= and value= command line arguments\n" + 
				"Restart the server for these to take effect\n";
		}


		public void runOp()
		{
			String keystr = _argMap.getStr("key");
			Optional<String> optval = getValueTarget();

			Integer recid = getKeyRecordId(keystr);
			if(recid == null)
			{
				Util.pf("New system setting detected\n");
				if(!optval.isPresent())
				{ 
					Util.pf("Delete requested, but key does not exist: nothing to do\n");
					return;
				}

				recid = CoreUtil.getNewDbId(CoreUtil.getMasterWidget(), MasterTable.system_setting.toString());
			}

			if(optval.isPresent())
			{
				CoreDb.upsertFromRecMap(CoreUtil.getMasterWidget(), MasterTable.system_setting.toString(), 1, CoreDb.getRecMap(
					"id", recid,
					"key_str", keystr,
					"val_str", optval.get()
				));

				Util.pf("Updated system setting for ID=%d, Key=%s, Val=%s\n", recid, keystr, optval.get());

			} else {
				CoreDb.deleteFromColMap(CoreUtil.getMasterWidget(), MasterTable.system_setting.toString(), CoreDb.getRecMap("id", recid));
				Util.pf("Deleted system setting ID=%d, key=%s\n", recid, keystr);
			}

			Util.pf("System setting table updated, you must restart the server to pick up the change\n");
		}

		private Optional<String> getValueTarget()
		{
			Optional<String> valopt = _argMap.optGetStr("value");
			boolean delete = _argMap.getBit("delete", false);
			Util.massert(!valopt.isPresent() == delete,
				"You cannot supply both delete=true and a value= argument");

			return valopt;
		}

		private static Integer getKeyRecordId(String keystr)
		{
			String query = Util.sprintf("SELECT id FROM system_setting WHERE key_str = '%s'", keystr);
			QueryCollector qcol = QueryCollector.buildAndRun(query, CoreUtil.getMasterWidget());
			if(qcol.getNumRec() == 0)
				{ return null; }

			return qcol.getSingleArgMap().getSingleInt();
		}
	}

	public static class UpdatePluginClass extends DescRunnable
	{
		public String getDesc()
		{
			return 
				"This is a special version of the update system setting for use with Plugin classes\n" + 
				"This class converts the plugin type to the property code, and checks that the class name is valid\n";
		}


		public void runOp()
		{
			PluginType ptype = PluginType.valueOf(_argMap.getStr("plugintype"));
			String classname = _argMap.getStr("classname");

			try {
				Class<?> cls = Class.forName(classname);
				Object ob = cls.getDeclaredConstructor().newInstance(); 
				Util.pf("Successfully built plugin object of class %s\n", classname);
			} catch (Exception ex) {
				ex.printStackTrace();
				Util.pf("Failed to instantiate plugin class, did you spell it right, does it have 0-arg constructor?\n");
				return;
			}

			{
				ArgMap submap = new ArgMap();
				submap.put("key", ptype.getPropName());
				submap.put("value", classname);
				UpdateSystemSetting updater = new UpdateSystemSetting();
				updater.initFromArgMap(submap);
				updater.runOp();
			}

			Util.pf("Updated Plugin class. Run %s to test plugin loading, the reload server\n", 
				FastTest4Basic.PluginLoadCheck.class.getSimpleName());
		}

	}
	
	public static class ShowSystemSetting extends ArgMapRunnable
	{

		public void runOp()
		{
			Map<String, String> setting = GlobalIndex.getSystemSetting();
			Util.pf("Have %d system settings\n", setting.size());
			for(String k : setting.keySet())
				{ Util.pf("\t%s=%s\n", k, setting.get(k)); }
		}

	}

	public static class CreateCode4User extends ArgMapRunnable 
	{
		public void runOp()
		{
			List<WidgetUser> userlist = getWidgetUserList(_argMap);

			for(WidgetUser wuser : userlist)
			{
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
	
	public static class UpdateUserPassWord extends DescRunnable
	{
		public String getDesc()
		{
			return 
				"Update a user's password from the command line.\n" + 
				"If the app server is running, it must be restarted to pick up the changes";
		}
		
		public void runOp()
		{
			WidgetUser wuser = WidgetUser.valueOf(_argMap.getStr("username"));
			
			String acchash = AuthLogic.canonicalHash(getNewPass()).toLowerCase();
			
			wuser.hardPasswordUpdate(acchash);

			Util.pf("Updated password for user %s, now run %s to confirm password\n",
				wuser, CheckUserPassword.class.getSimpleName());
			
			Util.pf("Remember to restart web server to pick up new password data\n");
		}

		// Prompt the user for new password, or take directly from command line argument, in insecure mode
		private String getNewPass()
		{
			if(_argMap.containsKey("directpass"))
			{
				Util.massert(CoreUtil.allowInsecureConnection(), "This command line option is only allowed in insecure mode");
				Util.pf("**Warning**, setting password directly based on command line argument, this may be insecure\n");
				return _argMap.getStr("directpass");
			}

			Console console = System.console();
			Util.massert(console != null, "Somehow failed to get a console instance");
			
			char[] passwordArray = console.readPassword("Enter your secret password: ");
			return new String(passwordArray);
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
			
			CoreDb.upsertFromRecMap(CoreUtil.getMasterWidget(), MasterTable.user_main.toString(), 1, CoreDb.getRecMap(
				"id", curmaxid+1,
				"username", username,
				"accesshash", WidgetUser.getDummyHash(),
				"email", ""
			));

			// This ensures that the new user record is loaded, now that it has been inserted into the table
			GlobalIndex.clearUserIndexes();
			createUserDir(username);
			
			mypf("Added master record for user %s. This script no longer sets password, use %s to do so\n", 
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
	
	
	public static class TestTableServeTime extends DescRunnable 
	{
		public String getDesc()
		{
			return 
				"Test how long it takes to load and compose data records\n" + 
				"This is a kind of performance test; you can use it with a debugger if there is a performance issue\n" + 
				"For a given widget, the code loads each table and generates the JS data corresponding to the table\n" + 
				"This is one of the fundamental, and performance-intensive, operations of WWIO";
		}
		
		
		public void runOp()
		{
			WidgetUser user = WidgetUser.lookup(_argMap.getStr("username"));
			WidgetItem item = new WidgetItem(user, _argMap.getStr("widgetname"));
			int numload = _argMap.getInt("numload", 100);
			
			for(int i : Util.range(numload))
			{
				
				double alpha = Util.curtime();
				for(String tbl : item.getDbTableNameSet())
				{
					LiteTableInfo LTI = new LiteTableInfo(item, tbl);
					LTI.runSetupQuery();
					List<String> reclist = LTI.composeDataRecSpool();
				}
				
				Util.pf("Loaded tables, took %.03f seconds\n", (Util.curtime()-alpha)/1000);
			}
		}
	}
	
	
	public static class ShowAutoInclude extends ArgMapRunnable
	{
		public void runOp()
		{
			WidgetUser user = WidgetUser.lookup(_argMap.getStr("username"));
			WidgetItem item = new WidgetItem(user, _argMap.getStr("widgetname"));
			
			for(String s : WebUtil.getAutoIncludeStatement(item))
			{
				Util.pf("Statement is \n\t%s\n", s);
			}
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
	
	public static class LoadMailReadyMap extends ArgMapRunnable
	{
		public void runOp()
		{
			WidgetUser user = WidgetUser.valueOf(_argMap.getStr("username"));
			Map<Integer, WidgetMail> readymap = MailSystem.loadReadyMailForUser(user);
			Util.pf("Have %d items in mail map\n", readymap.size());
		}
	}
	
	public static class SendSingleReadyMail extends DescRunnable
	{
		public String getDesc()
		{
			return "Send a SINGLE ready mail for a given user";	
		}
		
		public void runOp()
		{
			WidgetUser user = WidgetUser.valueOf(_argMap.getStr("username"));
			List<String> resultlist = MailSystem.sendSingleReadyMailForUser(user);
			
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
	
	public static class RevokePermission extends ArgMapRunnable
	{

		public void runOp()
		{
			WidgetUser user = WidgetUser.lookup(_argMap.getStr("username"));
			WidgetItem item = new WidgetItem(user, _argMap.getStr("widgetname"));
			WidgetUser grantee = WidgetUser.lookup(_argMap.getStr("grantee"));
			AuthLogic.removePermFromGrantee(item, grantee);
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

					// This uploads the local file to a DIFFERENT target path on the blob storage
					// This is necessary for backup, since we want to keep many days worth of backups
					PluginCentral.getStorageTool().uploadLocalToTarget(localdb, archfile);
				}
			}
		}

		// This is a "virtual" file, meaning that it is never actually used
		// It is just a coordinate that gets passed to the blob storage
		private static File getDbArchiveFile(WidgetItem dbitem, DayCode dc)
		{
			String localpath = Util.sprintf("%s/%s/%s/%s", CoreUtil.DB_ARCHIVE_VDIR, 
				dc, dbitem.theOwner, dbitem.getLocalDbFile().getName());

			return new File(localpath);
		}
	}


	public static class ShowPluginInfo extends ArgMapRunnable
	{

		public void runOp()
		{
			for(PluginType ptype : PluginType.values())
			{
				if(!PluginCentral.havePlugin(ptype))
				{
					Util.pf("No plugin configured for ptype=%s\n", ptype);
					continue;
				}

				Object plugin = PluginCentral.getPluginSub(ptype);
				Util.pf("For plugintype=%s, found object %s\n", ptype, plugin.getClass().getName());
			}
		}
	}


	public static class GrabRecentDbArchive extends ArgMapRunnable
	{

		public void runOp() throws IOException 
		{
			DayCode daycode = DayCode.lookup(_argMap.getStr("daycode"));
			int grabCount = 0;

			// String archivebase = String.format("%s/%s", CoreUtil.DB_ARCHIVE_DIR, daycode);
			// Util.pf("Going to examine base directory %s\n", archivebase);

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


	public static class ShowBaseConfigInfo extends ArgMapRunnable
	{
		public void runOp()
		{
			Util.pf("Have config directory %s\n", CoreUtil.WWIO_BASE_CONFIG_DIR);
			Util.pf("Have DATA/DB directory %s\n", CoreUtil.WIDGET_DB_DIR);
			Util.pf("Have CODE directory %s\n", CoreUtil.WIDGET_CODE_DIR);
			Util.pf("Have JCLASS directory %s\n", CoreUtil.JCLASS_BASE_DIR);
			Util.pf("MISC_DATA_DIR: %s\n", CoreUtil.WWIO_MISC_DATA_DIR);
			Util.pf("Allow Insecure: %b\n", CoreUtil.allowInsecureConnection());
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

	public static class BuildWidgetFromDbDump extends ArgMapRunnable
	{

		public void runOp()
		{
			WidgetUser user = WidgetUser.lookup(_argMap.getStr("username"));
			String widgetname = _argMap.getStr("widgetname");

			File dumpfile = new File(_argMap.getStr("dumpfile"));
			Util.massert(dumpfile.exists(), "DB dump file %s not found");


			List<String> sql = FileUtils.getReaderUtil().setFile(dumpfile).readLineListE();

			WidgetItem newitem = new WidgetItem(user, widgetname);
			newitem.createEmptyLocalDb();

			String litecomm = Util.sprintf("sqlite3 %s", newitem.getLocalDbFile().getAbsolutePath());
			SyscallWrapper builder = SyscallWrapper.build(litecomm).setInputList(sql).execE();

			Util.pf("Success, build the DB\n");

		}

	}

	public static class ImportWidgetFromGallery extends DescRunnable
	{
		public String getDesc()
		{
			return 
				"Imports a widget for a given user, from the DB dump and the gallery code\n" + 
				"Note that not all gallery widgets have DB data\n" + 
				"This tool is mainly used in setting up the demo server, to confirm that the full system is working\n";
		}

		public void runOp() throws IOException
		{
			WidgetUser user = WidgetUser.valueOf(_argMap.getStr("username"));
			WidgetItem item = new WidgetItem(user, _argMap.getStr("widgetname"));

			if(item.theName.equals("base"))
			{
				copyStarterIndex(user);
				return;
			}


			Util.massert(!item.dbFileExists(), "Already have DB file for widget %s", item);
			loadDbFromDump(item);

			// Create the new JS code for the DB
			{
					List<String> loglist = ActionJackson.createCode4Widget(item);
					for(String log : loglist)
						{ Util.pf("%s", log); }
			}

			// Import the code from the Gallery
			runCodeImport(item);
		}


		private static void copyStarterIndex(WidgetUser user) throws IOException
		{
			File srcpath = new File(CoreUtil.getSubDirectory(CoreUtil.GALLERY_CODE_DIR, "StarterIndex.jsp"));
			Util.massert(srcpath.exists(), "Starter Index file %s not found in repo gallery, expected at %s", srcpath);

			File dstpath = new File(CoreUtil.getSubDirectory(user.getUserBaseDir().getAbsolutePath(), "index.jsp"));
			Util.massert(!dstpath.exists(), "Already have index file for user %s", dstpath);

            java.nio.file.Files.copy(srcpath.toPath(), dstpath.toPath());
            Util.pf("Copied starter index file to %s\n", dstpath);
		}

		private static void runCodeImport(WidgetItem item)
		{
			CodeLocator locator = compileTempZip(item);

			CodeExtractor codex = locator.getExtractor();

			// This stuff is al
			codex.cleanOldCode();
			codex.extractCode(locator);
			codex.optAugmentAuthHeader();
			
			for(String log : codex.getLogList())
				{ Util.pf("%s\n", log); }

			locator.getCodeFile().delete();
			Util.pf("Cleaned import file %s\n", locator.getCodeFile());
		}

		private static CodeLocator compileTempZip(WidgetItem item)
		{
			File gallerydir = new File(Util.varjoin(File.separator, CoreUtil.GALLERY_CODE_DIR, item.theName));
			Util.massert(gallerydir.exists() && gallerydir.isDirectory(),
				"Gallery directory for widget %s does not exist at expected path %s",
				item.theName, gallerydir
			);


			ImportLocator locator = new ImportLocator(item);
			zipDirectory(gallerydir, locator.getCodeFile());
			Util.pf("Generated .zip file at path %s\n", locator.getCodeFile());
			return locator;
		}

		// TODO: move this logic somewhere else, probably CoreUtil

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


		private static void loadDbFromDump(WidgetItem newitem)
		{
			File dumpfile = CoreUtil.getDemoDataDumpFile(newitem.theName);
			Util.massert(dumpfile.exists(),
				"Could not find a DB dump file for widget named %d, expected at %s, note: not all Gallery widgets have DB dumps",
				newitem.theName, dumpfile
			);

			List<String> sql = FileUtils.getReaderUtil().setFile(dumpfile).readLineListE();

			String litecomm = Util.sprintf("sqlite3 %s", newitem.getLocalDbFile().getAbsolutePath());
			SyscallWrapper builder = SyscallWrapper.build(litecomm).setInputList(sql).execE();

			Util.pf("Success, built SQLite DB for widget %s from dump file %s\n",
				newitem.theName, dumpfile);
		}
	}

	public static class WidgetDataDump extends ArgMapRunnable
	{

		public void runOp()
		{
			WidgetUser user = WidgetUser.valueOf(_argMap.getStr("username"));
			WidgetItem item = new WidgetItem(user, _argMap.getStr("widgetname"));
			Util.massert(item.getLocalDbFile().exists(), "Widget %s not found", item);

			File outputdir = new File(_argMap.getStr("outputdir"));
			Util.massert(outputdir.exists(), "Output directory %s  does not exist");

			File outputfile = getOutputFile(outputdir, item.theName);
			Util.massert(!outputfile.exists(), "Output file %s already exists, please delete before continuing");

			String dumpcall = Util.sprintf("sqlite3 %s .dump", item.getLocalDbFile().getAbsolutePath());
			SyscallWrapper wrapper = SyscallWrapper
											.build(dumpcall)
											.execE();


			List<String> result = wrapper.getOutList();
			FileUtils.getWriterUtil().setFile(outputfile).writeLineListE(result);
			Util.pf("Wrote %d lines to path %s\n", result.size(), outputfile);

		}

		private File getOutputFile(File outputdir, String widgetname)
		{
			String filename = Util.sprintf("%s_DB.sql.dump", widgetname.toUpperCase());
			String newpath =  Util.join(Util.listify(outputdir.getAbsolutePath(), filename), File.separator);
			return new File(newpath);
		}
	}

	public static class ToggleInsecureAllow extends DescRunnable
	{

		public String getDesc()
		{
			return 
				"Toggles the config setting that allows insecure connections\n" + 
				"Server must be restarted after config\n" + 
				"Do not use in production, just for demo purposes\n";
		}

		public void runOp()
		{
			boolean allowins = CoreUtil.allowInsecureConnection();
			if(allowins)
			{
				CoreUtil.INSECURE_ALLOW_FILE.delete();
				Util.pf("Cleared insecure-allow file, this will reset to no-insecure config\n");
			} else {

				if(confirmAllow())
				{
					FileUtils.getWriterUtil().setFile(CoreUtil.INSECURE_ALLOW_FILE).writeLineListE(Util.listify(""+true));
					Util.pf("Marked allow insecure, do not run in prod!\n");
				} else {
					Util.pf("Aborting\n");
					return;
				}
			}

			Util.pf("Setting toggled, run %s to confirm setting, you must restart server to pick up the config change\n", 
						ShowBaseConfigInfo.class.getSimpleName());
		}

		private boolean confirmAllow()
		{
			boolean fastconfirm = _argMap.getBit("fastconfirm", false);
			if(fastconfirm)
				{ return true; }

			return Util.checkOkay("This will configure the server to allow insecure connections, okay? ");
		}
	}

	public static class CopySharedCodeFromRepo extends ArgMapRunnable
	{
		public void runOp() throws IOException
		{

			{
				File cssrepo = new File(CoreUtil.getSubDirectory(CoreUtil.WWIO_BASE_CONFIG_DIR, "css", 3));
				shallowDirectoryCopy(cssrepo, CoreUtil.SHARED_CSS_ASSET_DIR);
			}

			{
				File repodir = new File(CoreUtil.getSubDirectory(CoreUtil.WWIO_BASE_CONFIG_DIR, "jslib", 3));
				shallowDirectoryCopy(repodir, CoreUtil.SHARED_JSLIB_ASSET_DIR);
			}

			{
				File repodir = new File(CoreUtil.getSubDirectory(CoreUtil.WWIO_BASE_CONFIG_DIR, "image", 3));
				shallowDirectoryCopy(repodir, CoreUtil.SHARED_IMAGE_ASSET_DIR);
			}

			{
				File admindir = new File(CoreUtil.composeSubDirectory(CoreUtil.REPO_BASE_DIRECTORY, 0, "server", "pages", "admin"));
				shallowDirectoryCopy(admindir, new File(CoreUtil.WIDGET_ADMIN_DIR));
			}
		}

		private static void shallowDirectoryCopy(File srcdir, File dstdir) throws IOException
		{
			Util.massert(srcdir.exists() && srcdir.isDirectory(), "Problem with source directory %s", srcdir);

			if(!dstdir.exists())
			{
				dstdir.mkdirs();
				Util.pf("Created directory %s\n", dstdir.getAbsolutePath());
			}


			for(File srcfile : srcdir.listFiles())
			{
				if(srcfile.isDirectory())
				{
					Util.pferr("**Warning**, found subdirectory %s, this operation is just a shallow copy", srcfile);
					continue;
				}

				File dstfile = new File(Util.join(Util.listify(dstdir.getAbsolutePath(), srcfile.getName()), File.separator));
	            Files.copy(srcfile.toPath(), dstfile.toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING);
	            Util.pf("Copied file %s -> %s\n", srcfile.getAbsolutePath(), dstfile.getAbsolutePath());
			}
		}
	}
}




