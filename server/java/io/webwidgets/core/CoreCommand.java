
package io.webwidgets.core; 

import java.io.*; 
import java.sql.*;
import java.util.*;
import java.nio.file.*;


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

	
	public static class MarkMaintenanceMode extends ArgMapRunnable implements HasDescription
	{
		
		public String getDesc()
		{
			return 
			"Put the server in maintenance mode by updating the system setting " + SystemPropEnum.MAINTENANCE_MODE;
		}
		
		public void runOp()
		{
			Optional<String> prevmode = AdvancedUtil.maintenanceModeInfo();
			if(prevmode.isPresent())
			{
				Util.pf("Server is already in maintenance mode: %s\n", prevmode.get());
				return;
			}
			
			Util.pf("Okay, this will put the server in maintenance mode so no further updates can be processed\n");
			Util.pf("Enter your message: ");
			
			String mssgtext = Util.getUserInput();
			
			GlobalIndex.updateSystemSetting(SystemPropEnum.MAINTENANCE_MODE, Optional.of(mssgtext));
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
			Optional<String> prevmode = AdvancedUtil.maintenanceModeInfo();
			if(!prevmode.isPresent())
			{
				Util.pf("Server is not in maintenance mode!!\n");
				return;
			}
			
			Util.pf("This command will clear the maintenance mode flag, so users will be able to update their widgets again\n");
			
			if(Util.checkOkay("Okay to proceed? [yes/NO]")) 
			{
				GlobalIndex.updateSystemSetting(SystemPropEnum.MAINTENANCE_MODE, Optional.empty());
				Util.pf("Maintenance Mode flag removed, remember to restart\n");
			}
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

				recid = CoreUtil.getNewDbId(WidgetItem.getMasterWidget(), MasterTable.system_setting.toString());
			}

			if(optval.isPresent())
			{
				CoreDb.upsertFromRecMap(WidgetItem.getMasterWidget(), MasterTable.system_setting.toString(), 1, CoreDb.getRecMap(
					"id", recid,
					"key_str", keystr,
					"val_str", optval.get()
				));

				Util.pf("Updated system setting for ID=%d, Key=%s, Val=%s\n", recid, keystr, optval.get());

			} else {
				CoreDb.deleteFromColMap(WidgetItem.getMasterWidget(), MasterTable.system_setting.toString(), CoreDb.getRecMap("id", recid));
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
			QueryCollector qcol = QueryCollector.buildAndRun(query, WidgetItem.getMasterWidget());
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

	public static class CreateCode4User extends DescRunnable 
	{

		public String getDesc()
		{
			return 
				"Re-creates the autogen JS code for a user's widgets from the SQLite DBs\n" + 
				"Normally the system performs this action whenever necessary\n" + 
				"But in some cases it might be necessary to re-create\n";
		}

		public void runOp()
		{
			List<WidgetUser> userlist = getWidgetUserList(_argMap);
			runForUserList(userlist);
		}

		public static void runForUserList(List<WidgetUser> userlist)
		{
			for(WidgetUser wuser : userlist)
			{
				List<WidgetItem> itemlist = WidgetItem.getUserWidgetList(wuser);
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
			

			WidgetItem witem = WidgetItem.createBlankItem(wuser, widgetname);
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
			
			Set<String> curset = Util.map2set(WidgetItem.getUserWidgetList(wuser), witem -> witem.theName);
			Util.massert(curset.contains(widgetname),
				"That widget does not exist: %s", widgetname);
			
			WidgetItem victim = new WidgetItem(wuser, widgetname);
			victim.checkAndDelete(reversed);
		}
	}
	
	public static class ImportDummyUserBase extends DescRunnable
	{
		public static final WidgetUser DUMMY_USER = WidgetUser.valueOf("rando");
		
		public String getDesc()
		{
			return 
				"Imports the base code from the dummy user to a new user's space\n" + 
				"You must run this AFTER doing folder setup\n" + 
				"This creates the DB data from SQLite dump files, and imports the JS/HTML code from the gallery";
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
			
			AdvancedUtil.hardPasswordUpdate(wuser, acchash);

			Util.pf("Updated password for user %s, now run %s to confirm password\n",
				wuser, CheckUserPassword.class.getSimpleName());
			
			Util.pf("Remember to restart web server to pick up new password data\n");
		}

		// Prompt the user for new password, or take directly from command line argument, in insecure mode
		private String getNewPass()
		{
			if(_argMap.containsKey("directpass"))
			{
				Util.massert(AdvancedUtil.allowInsecureConnection(), "This command line option is only allowed in insecure mode");
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
			WidgetItem master = WidgetItem.getMasterWidget();
			QueryCollector qcol = QueryCollector.buildAndRun(
				Util.sprintf("SELECT id FROM user_main WHERE username = '%s'", wuser), master);
			int userid = qcol.getSingleArgMap().getSingleInt();
			return userid;
		}
	}
	
	
	
	public static class AddUserMasterRecord extends LogSwapRunnable implements HasDescription
	{

		public String getDesc()
		{
			return 
				"Add a user to the master table. This creates the user record\n" + 
				"The username= is provided by the command line\n" +
				"User names must be unique\n" +
				"User IDs are assigned in linear order\n";
		}

		public void runOp()
		{
			String username = _argMap.getStr("username");
			dumbCheckUnique(username);
						
			int curmaxid = Collections.max(Util.map2list(WidgetUser.values(), user -> user.getMasterId()));
			
			CoreDb.upsertFromRecMap(WidgetItem.getMasterWidget(), MasterTable.user_main.toString(), 1, CoreDb.getRecMap(
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
				mypf("Deleted directory %s\n", rmdir);
			}

			GlobalIndex.clearUserIndexes();

			Util.massert(!WidgetUser.softLookup(username).isPresent(), "Somehow still retained a user entry for %s", username);

			mypf("Removed username %s from global index\n", username);
		}

		private void deleteMasterRecord(String username)
		{
			int numdel = CoreDb.deleteFromColMap(WidgetItem.getMasterWidget(), "user_main", CoreDb.getRecMap(
				"username", username
			));

			Util.massert(numdel == 1, "Somehow failed to delete the right number of records, expected 1, got %d", numdel);
			mypf("Deleted master record from DB\n");
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
	
	public static class AddEmailForUser extends ArgMapRunnable
	{
		public void runOp()
		{
			WidgetUser user = WidgetUser.lookup(_argMap.getStr("username"));
			ValidatedEmail email = ValidatedEmail.from(_argMap.getStr("email"));

			AdvancedUtil.addEmailAddress(user, email);

			Util.pf("Updated address for user %s, it's now %s\n", user, user.getEmailSet());
		}

	}

	public static class RemoveEmailForUser extends ArgMapRunnable
	{
		public void runOp()
		{
			WidgetUser user = WidgetUser.lookup(_argMap.getStr("username"));
			ValidatedEmail email = ValidatedEmail.from(_argMap.getStr("email"));

			AdvancedUtil.removeEmailAddress(user, email);
			Util.pf("Updated address for user %s, it's now %s\n", user, user.getEmailSet());
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
	

	public static class CheckPermForWidget extends ArgMapRunnable 
	{
		public void runOp() 
		{
			WidgetUser owner = WidgetUser.valueOf(_argMap.getStr("username"));
			String widgetname = _argMap.getStr("widgetname");
			WidgetItem dbitem = new WidgetItem(owner, widgetname);
			
			for(WidgetUser accessor : WidgetUser.values())
			{
				Optional<PermLevel> perm = GlobalIndex.getPermInfo4Widget(dbitem).getPerm4Accessor(dbitem, Optional.of(accessor));
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
			return 
				"Archives the Widget DB files to the Blob Storage system for all users\n" + 
				"The backup/archive option is generally intended to run daily\n" + 
				"If you are more paranoid, you can run it more often; but if you run it multiple times in the same day\n" + 
				"Each call will just overwrite the previous backup for the day\n" + 
				"This command uses a 'virtual' path for the DB file that does not actually exist locally and contains the date\n" + 
				"The Blob Storage should perform the local/remote mapping on the virtual path and save the file to the resulting location" + 
				"As of October 2023, the core package does not contain the option to restore from backup\n" + 
				"We expect&hope that smart sysadmins will be able to do this in rare cases when it is required";
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
			
			for(var user : WidgetUser.values())
			{
				for(var dbitem : WidgetItem.getUserWidgetList(user))
				{
					File localdb = dbitem.getLocalDbFile();
					File archfile = getDbArchiveFile(dbitem, dc);

					// This uploads the local file to a DIFFERENT target path on the blob storage
					// This is necessary for backup, since we want to keep many days worth of backups
					PluginCentral.getStorageTool().uploadLocalToTarget(localdb, archfile);
				}
			}
		}


		public static String getVirtualArchivePath(DayCode dc)
		{
			return String.format("%s/%s", CoreUtil.DB_ARCHIVE_VDIR, dc);
		}

		// This is a "virtual" file, meaning that it is never actually used
		// It is just a coordinate that gets passed to the blob storage
		public static File getDbArchiveFile(WidgetItem dbitem, DayCode dc)
		{
			String localpath = String.format("%s/%s/%s", 
				getVirtualArchivePath(dc), dbitem.theOwner, dbitem.getLocalDbFile().getName());

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
			Util.pf("Allow Insecure: %b\n", AdvancedUtil.allowInsecureConnection());
		}
	}



	public static class BuildWidgetFromDbDump extends DescRunnable
	{
		public String getDesc()
		{
			return 
				"Builds a widget from a SQLite dump file\n" + 
				"Supply username=, widgetname=, dumpfile= arguments on the command line\n" + 
				"TODO: this script should be able to infer the widget from the dumpfile name, if it follows a naming convention";
		}

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

	public static class ImportWidgetFromGallery extends LogSwapRunnable implements HasDescription
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
			String wname = _argMap.getStr("widgetname");
			runWithArgs(user, wname);
		}

		public void runWithArgs(WidgetUser user, String widgetname) throws IOException 
		{
			WidgetItem item = new WidgetItem(user, widgetname);

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
			File srcpath = new File(CoreUtil.getSubDirectory(CoreUtil.GALLERY_CODE_DIR, "StarterIndex.html"));
			Util.massert(srcpath.exists(), "Starter Index file %s not found in repo gallery, expected at %s", srcpath);

			File dstpath = new File(CoreUtil.getSubDirectory(user.getUserBaseDir().getAbsolutePath(), "index.html"));
			Util.massert(!dstpath.exists(), "Already have index file for user %s", dstpath);

            java.nio.file.Files.copy(srcpath.toPath(), dstpath.toPath());
            Util.pf("Copied starter index file to %s\n", dstpath);
		}

		private static void runCodeImport(WidgetItem item)
		{
			{
				File itemdir = item.getWidgetBaseDir();
				Util.massert(!itemdir.exists(), "Widget base dir %s already exists, you must delete first", item);
			}

			// NB: use the user's base dir, not the widget base dir, to ensure cp -r works correctly
			String copycall = Util.sprintf("cp -r %s %s", getGalleryDir(item), item.theOwner.getUserBaseDir());
			var wrapper = SyscallWrapper.build(copycall).execE();

			Util.massert(wrapper.getErrList().isEmpty(), "Have error output on copy %s", wrapper.getErrList());
			Util.massert(item.getWidgetBaseDir().exists(), "Directory should exist now");
		}

		private static File getGalleryDir(WidgetItem item)
		{
			return new File(Util.varjoin(File.separator, CoreUtil.GALLERY_CODE_DIR, item.theName));
		}

		private static void loadDbFromDump(WidgetItem newitem)
		{
			File dumpfile = CoreUtil.getDemoDataDumpFile(newitem.theName);
			Util.massert(dumpfile.exists(),
				"Could not find a DB dump file for widget named %s, expected at %s, note: not all Gallery widgets have DB dumps",
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
			boolean onlyschema = _argMap.getBit("onlyschema", false);

			Util.massert(item.getLocalDbFile().exists(), "Widget %s not found", item);

			File outputdir = new File(_argMap.getStr("outputdir"));
			Util.massert(outputdir.exists(), "Output directory %s  does not exist", outputdir);

			File outputfile = getOutputFile(outputdir, item.theName);
			Util.massert(!outputfile.exists(), "Output file %s already exists, please delete before continuing", outputfile);

			String argument = onlyschema ? ".schema" : ".dump";
			String dumpcall = Util.sprintf("sqlite3 %s %s", item.getLocalDbFile().getAbsolutePath(), argument);
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
			boolean allowins = AdvancedUtil.allowInsecureConnection();
			if(allowins)
			{
				GlobalIndex.updateSystemSetting(CoreUtil.SystemPropEnum.INSECURE_ALLOW_MODE, Optional.empty());
				Util.pf("Cleared insecure-allow setting, this will reset to no-insecure config\n");
			} else {

				if(confirmAllow())
				{
					GlobalIndex.updateSystemSetting(CoreUtil.SystemPropEnum.INSECURE_ALLOW_MODE, Optional.of(true+""));
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

	public static class CopySharedCodeFromRepo extends DescRunnable
	{
		public String getDesc()
		{

			return 
				"Pull the shared code from the repo Gallery section into the widgetserve section of the WWIO installation\n" + 
				"This is generally done when the WWIO server is initially installed\n" +
				"The shared code is then served from the /u/shared/... path of the server\n";
		}

		public void runOp() throws IOException
		{

			{
				File cssrepo = new File(CoreUtil.getSubDirectory(CoreUtil.WWIO_BASE_CONFIG_DIR, "css", 3));
				shallowDirectoryCopy(cssrepo, AdvancedUtil.SHARED_CSS_ASSET_DIR);
			}

			{
				File repodir = new File(CoreUtil.getSubDirectory(CoreUtil.WWIO_BASE_CONFIG_DIR, "jslib", 3));
				shallowDirectoryCopy(repodir, AdvancedUtil.SHARED_JSLIB_ASSET_DIR);
			}

			{
				File repodir = new File(CoreUtil.getSubDirectory(CoreUtil.WWIO_BASE_CONFIG_DIR, "image", 3));
				shallowDirectoryCopy(repodir, AdvancedUtil.SHARED_IMAGE_ASSET_DIR);
			}

			{
				File admindir = new File(CoreUtil.composeSubDirectory(CoreUtil.REPO_BASE_DIRECTORY, 0, "server", "pages", "admin"));
				shallowDirectoryCopy(admindir, new File(CoreUtil.WIDGET_ADMIN_DIR));
			}


			// Kind of annoying, this one has subdirectories, cannot use Shallow File Copy
			{
				File optjs = new File(CoreUtil.getSubDirectory(CoreUtil.WWIO_BASE_CONFIG_DIR, "optjs", 3));
				for(File subsrc : optjs.listFiles())
				{
					if(!subsrc.isDirectory())
					{
						Util.pferr("**Warning**, found non-directory subfile %s in OPTJS directory, expect only directories", subsrc);
						continue;
					}

					File subdst = new File(AdvancedUtil.SHARED_OPTJS_ASSET_DIR + File.separator + subsrc.getName());
					subdst.mkdirs();
					shallowDirectoryCopy(subsrc, subdst);
				}
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




