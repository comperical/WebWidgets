
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 
import java.net.*; 
import java.util.function.BiFunction;

import org.json.simple.*;
import org.json.simple.parser.*;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.FileUtils;

import net.danburfoot.shared.RunnableTech.*;
import net.danburfoot.shared.Util.SyscallWrapper;
import net.danburfoot.shared.CoreDb.QueryCollector;

import	io.webwidgets.core.WebUtil.*;
import	io.webwidgets.core.CoreUtil.*;
import	io.webwidgets.core.WidgetOrg.*;
import	io.webwidgets.core.AuthLogic.*;
import	io.webwidgets.core.MailSystem.*;
import	io.webwidgets.core.DataServer.*;
import	io.webwidgets.core.PluginCentral.*;
import	io.webwidgets.core.ActionJackson.*;
import	io.webwidgets.core.WispFileLogic.*;
import	io.webwidgets.core.BlobDataManager.*;

public class FastTest4Basic
{
	private static Set<WidgetUser> getAdminUserSet()
	{
		return Util.filter2set(WidgetUser.values(), user -> user.isAdmin());
	}

	public static class SimpleIndexLoadTest extends DescRunnable
	{

		public String getDesc()
		{
			return 
				"Simple test load of global indexes\n" + 
				"Useful for local testing, when you don't want to blow up your system";
		}

		public void runOp()
		{
			Map<String, WidgetUser> sysmap = GlobalIndex.getUserLookup();

			Util.pf("Have %d widget users\n", sysmap.size());


			Util.pf("System settings are:\n\t%s\n", GlobalIndex.getSystemSetting());

		}

	}

	public static class CheckUserHardReference extends DescRunnable
	{
		public String getDesc()
		{
			return 
				"WidgetUser objects are immutable and unique\n" + 
				"This test checks that if you load a WidgetUser object twice, you get the same object back";
		}


		public void runOp()
		{
			WidgetUser testuser1 = WidgetUser.valueOf("testuser");
			WidgetUser testuser2 = WidgetUser.valueOf("testuser");
			Util.massert(testuser1 == testuser2, "WidgetUser objects must be unique, hard equals must work");

			WidgetItem testlinks = new WidgetItem(testuser1, "links");


			for(WidgetUser tuser : Util.listify(testuser1, testuser2))
			{
				Util.massert(tuser == testlinks.theOwner);
				boolean allowedit = AuthChecker.build().directSetAccessor(tuser).directDbWidget(testlinks).allowWrite();
				Util.massert(allowedit, "Must allow access to owner");
			}

			for(WidgetUser admin : getAdminUserSet())
			{
				boolean allowedit = AuthChecker.build().directSetAccessor(admin).directDbWidget(testlinks).allowWrite();
				Util.massert(allowedit, "Must allow access to ADMIN");
			}
		}
	}

	public static class AccessCheck extends DescRunnable
	{
		public String getDesc()
		{
			return 
				"Checks that authentication logic is working properly for a couple of hardcoded pages\n" + 
				"For Heather's pages, requires that dburfoot and heather can access\n" + 
				"For dburfoot pages, requires that only dburfoot can access";
			
		}
		
		public void runOp()
		{
			WidgetUser testuser = WidgetUser.valueOf("testuser");
			Set<WidgetUser> adminset = getAdminUserSet();
			
			for(WidgetUser wuser : WidgetUser.values())
			{
				WidgetItem probe = new WidgetItem(testuser, "links");
				boolean allow = AuthChecker.build().directSetAccessor(wuser).directDbWidget(probe).allowRead();
				boolean expect = wuser == testuser || adminset.contains(wuser);
				Util.massert(allow == expect,
					"Got allow=%s but expected %s for wuser=%s", allow, expect, wuser);
			}
			
			for(WidgetUser wuser : WidgetUser.values())
			{
				String page = getTestUserPage();
				boolean allow = AuthChecker.build().widgetFromUrl(page).directSetAccessor(wuser).allowRead();
				boolean expect = wuser == testuser || adminset.contains(wuser);
				Util.massert(allow == expect,
					"Got allow=%s but expected %s for wuser=%s", allow, expect, wuser);
			}
		}
		
		private String getTestUserPage() 
		{
			return "https://webwidgets.io/u/testuser/links/widget.jsp";
		}
	}

	public static class MainUserConfigCheck extends DescRunnable
	{
		public String getDesc()
		{
			return "Checks the following 3 sets are equal:\n" + 
				"The user_name records in the MASTER database\n" + 
				"The folders in the widget base DB directory\n" + 
				"The folders in the widget base code directory\n";
		}
		
		public void runOp()
		{

			Set<String> codeset = getFolderKidSet(new File(CoreUtil.getWidgetCodeDir()));
			{
				codeset.remove("docs");
				codeset.remove("admin");
				codeset.remove("exadmin");
				codeset.remove("resin-data");
				codeset.remove("WEB-INF");
			}

			{
				Set<String> checkset = getFolderKidSet(new File(CoreUtil.WIDGET_DB_DIR));
				Util.massert(checkset.equals(codeset), "Have Check set:\n%s\nCode set:\n%s\n", checkset, codeset);
				Util.pf("Success, DB set equals code-dir set, have %d items\n", checkset.size());
			}

			{
				Set<String> checkset = Util.map2set(WidgetUser.values(), user -> user.toString());
				Util.massert(checkset.equals(codeset), "Have Check set:\n%s\nCode set:\n%s\n", checkset, codeset);
				Util.pf("Success, WidgetUser set equals code-dir set, have %d items\n", checkset.size());
			}
		}

		private static Set<String> getFolderKidSet(File basedir)
		{
			Util.massert(basedir.exists() && basedir.isDirectory(), "Basedir must be a directory");
			return Util.map2set(Util.listify(basedir.listFiles()), file -> file.getName());
		}
	}


	public static class MailboxConfigurationTest extends DescRunnable
	{

		public String getDesc()
		{
			return "If the installation has any mailbox-enabled users, it must have a valid Mail Sender plugin";
		}

		public void runOp()
		{
			List<WidgetUser> mailuser = Util.filter2list(WidgetUser.values(), wuser -> MailSystem.userHasMailBox(wuser));
			if(mailuser.isEmpty())
			{
				Util.pf("No mailboxes detected, quitting\n");
				return;
			}

			Util.massert(PluginCentral.havePlugin(PluginType.mail_sender),
				"Error: found %d mail-enabled users, but no Mailbox plugin is configured for this installation", mailuser.size());

			IMailSender plugin = PluginCentral.getMailPlugin();

			Util.pf("Success, have %d mailbox users with mail plugin %s\n", mailuser.size(), plugin.getClass().getName());
		}

	}

	// This is really just a foreign key check for the Perm Grant table
	// The Perm-loading code is cautious to make sure it doesn't break when the FKey here is invalid,
	// But we don't want to have invalid references hanging around
	public static class PermGrantPermissionTest extends ArgMapRunnable
	{
		public void runOp()
		{
			for(String colname : Util.listify("owner", "grantee"))
			{
				String query = String.format("SELECT %s FROM perm_grant", colname);
				QueryCollector qcol = QueryCollector.buildAndRun(query, WidgetItem.getMasterWidget());

				for(ArgMap rec : qcol.recList())
				{
					String username = rec.getSingleStr();
					if(username.equals(AuthLogic.PUBLIC_READ_GRANTEE))
						{ continue; }

					Util.massert(WidgetUser.softLookup(username).isPresent(),
						"User %s specified in perm grant table is not actually a user!!", username);
				}
				Util.pf("Success, checked %d records for column %s\n", qcol.getNumRec(), colname);
			}
		}
	}


	public static class TestUserEntryLookup extends ArgMapRunnable
	{
		public void runOp()
		{
			int okaycount = 0;

			for(WidgetUser user : WidgetUser.values())
			{ 
				Util.massert(user.haveUserEntry(), "Did not find USER entry for user %s", user); 
				okaycount++;
			}

			Util.pf("Success, found user entries for all %d WidgetUser records\n", okaycount);
		}
	}


	// At some point, had an issue where I copied the AutoGen from one user to another
	// That is bad news, because now I'm updating a different user's data!!!
	public static class TestUserNameAutoGen extends DescRunnable
	{

		int _lineCount = 0;
		int _fileCount = 0;
		int _userCount = 0;

		public String getDesc()
		{
			return "Test that the username of the widget Owner is present in all of the autogen JS files";
		}


		public void runOp()
		{
			for(WidgetUser user : WidgetUser.values())
				{ checkUser(user); }

			Util.pf("Checked %d users, %d files, %d lines\n", _userCount, _fileCount, _lineCount);
		}

		private void checkUser(WidgetUser user)
		{
			if(user == WidgetUser.getSharedUser())
				{ return; }

			String deftag = String.format("widgetOwner : \"%s\"", user.toString());

			for(WidgetItem dbitem : WidgetItem.getUserWidgetList(user))
			{
				File jsdir = dbitem.getAutoGenJsDir();
				Util.massert(jsdir.exists() && jsdir.isDirectory(), "Problem with autogen JS dir %s", jsdir);

				for(File jsfile : jsdir.listFiles())
				{
					List<String> jslist = FileUtils.getReaderUtil().setFile(jsfile).readLineListE();
					int hits = Util.countPred(jslist, js -> js.contains(deftag));
					Util.massert(hits >= 1, "Failed to find expected tag %s in autogen file %s", deftag, jsfile);
					_fileCount++;
					_lineCount += jslist.size();
				}
			}

			_userCount++;
		}
	}


	
	public static class CheckUserDirExist extends DescRunnable
	{
		public String getDesc()
		{
			return "Check that the user base dir exists for all the current WidgetUsers";
		}
		
		public void runOp()
		{
			for(WidgetUser wuser : WidgetUser.values())
			{
				File basedir = wuser.getUserBaseDir();
				Util.massert(basedir.exists(),
					"Base directory for user %s does not exist", basedir);
			}

			Util.pf("Success, found base directory for all %d WidgetUsers\n", WidgetUser.values().size());
		}
	}

	public static class PluginLoadCheck extends DescRunnable
	{
		public String getDesc()
		{
			return 
				"Check that the plugins can load without any misconfiguration errors\n" + 
				"Errors are things like class name typos, missing constructors, etc";
		}


		public void runOp()
		{
			if(PluginCentral.havePlugin(PluginType.blob_store))
			{
				IBlobStorage blobtool = PluginCentral.getStorageTool();
				Util.pf("Loaded blob storage tool %s\n", blobtool.getClass().getName());
			}


			if(PluginCentral.havePlugin(PluginType.mail_sender))
			{
				IMailSender mailtool = PluginCentral.getMailPlugin();
				Util.pf("Loaded mail plugin %s\n", mailtool.getClass().getName());
			}

			if(PluginCentral.havePlugin(PluginType.general))
			{
				GeneralPlugin general = PluginCentral.getGeneralPlugin();
				Util.pf("Loaded general plugin %s\n", general.getClass().getName());
			}

			int loadcount = 0;
			for(PluginType ptype : PluginType.values())
			{
				if(!PluginCentral.havePlugin(ptype))
					{ continue; }

				Object ob = PluginCentral.getPluginSub(ptype);
				Util.massert(ob != null, "Failed to load plugin for PType %s", ptype);
				loadcount++;
			}

			Util.pf("Loaded %d plugins successfully\n", loadcount);
		}
	}
	
	public static class DeleteGimpTable extends DescRunnable
	{
		public String getDesc()
		{
			return "Delete the dumb old gimp files";
		}
		
		public void runOp()
		{
			boolean modokay = _argMap.getBit("modokay", false);
			
			List<WidgetItem> problist = Util.vector();
			
			for(var wuser : WidgetUser.values())
			{
				for(var witem : WidgetItem.getUserWidgetList(wuser))
				{
					Set<String> nameset = CoreDb.getLiteTableNameSet(witem);
					
					Set<String> badset = Util.filter2set(nameset, name -> name.contains("gimp"));
					
					if(!badset.isEmpty())
					{
						Util.pf("Found badset %s for %s\n", badset, witem);	
						problist.add(witem);
					}
				}
			}
			
			if(problist.isEmpty())
			{
				Util.pf("Success, No bad Widgets found\n");
				return;
			}
			
			Util.massert(modokay, "Found %d errors, see above", problist.size());
			
			Util.pf("Going to delete from %d Widgets as above, okay?", problist.size());
			if(!Util.checkOkay("Okay to delete?"))
			{
				Util.pf("Quitting\n");
				return;
			}
			
			for(WidgetItem witem : problist)
			{
				String dropper = Util.sprintf("DROP TABLE __gimp");
				CoreDb.execSqlUpdate(dropper, witem);
				
				
				Util.pf("Fixed Widget %s\n", witem);
			}
			
		}
	}	
	
	public static class CheckUserAutoGen extends DescRunnable
	{
		public String getDesc()
		{
			return "Check that the JS autogen file exists for all widgets\n"  + 
				"Also checks that the LiteTableInfo data spool code runs for all widgets\n" + 
				"The point is to check that there is no config issues or naming issues in the DB files";
		}
		
		public void runOp()
		{
			int errcount = 0;
			int tablecount = 0;
			int widgetcount = 0;
			
			for(WidgetUser wuser : WidgetUser.values())
			{
				if(wuser == WidgetUser.getSharedUser())
					{ continue; }

				if(!wuser.haveLocalDb())
					{ continue; }
				
				List<WidgetItem> itemlist = WidgetItem.getUserWidgetList(wuser);
				for(WidgetItem witem : itemlist)
				{
					for(String dbname : witem.getDbTableNameSet())
					{
						if(dbname.startsWith("__"))
							{ continue; }
						
						// nodatamode = true, this makes it run much faster
						LiteTableInfo tinfo = new LiteTableInfo(witem, dbname);
						tinfo.withNoDataMode(true);

						Optional<File> autofile = tinfo.findAutoGenFile();
						Util.massert(autofile.isPresent(),
							"JS data path for widget %s::%s does not exist", witem, dbname);
						
						try {
							tinfo.runSetupQuery();
							List<String> datalist = tinfo.composeDataRecSpool();
						} catch (Exception ex) {
						
							Util.pferr("Got exception on widget %s, table %s\n", witem, dbname);
							ex.printStackTrace();
							errcount++;
						}

						tablecount++;
					}
				}

				widgetcount += itemlist.size();
			}
			
			Util.massert(errcount == 0, "Got %d errors, see above", errcount);
			Util.pf("Checked %d tables for %d widgets and %d users\n", tablecount, widgetcount, WidgetUser.values().size());
		}
	}
	
	public static class SuiteRunner extends DescRunnable implements CrontabRunnable
	{
		public static final String FAST_TEST_MARKER = CoreUtil.peelSuffix(FastTest4Basic.class.getSimpleName(), "Basic");

		public String getDesc()
		{
			return 
				"Inspects to find the other inner classes in this class\n" + 
				"And runs them as unit tests\n" + 
				"Any ArgMapRunnable inner class you put in this file will run as a unit test";
		}
		
		public void runOp() throws Exception
		{
			Set<String> skipset = lookupSkipSet();

			for(ArgMapRunnable amr : getTestList())
			{
				if(amr.getClass().getName().contains("UnitTest"))
					{ continue; }

				if(skipset.contains(amr.getClass().getSimpleName()))
				{ 
					Util.pf("Skipping test %s\n", amr.getClass().getSimpleName()); 
					continue;
				}
				

				Util.pf("Running test: %s\n", amr.getClass().getSimpleName());
				amr.initFromArgMap(new ArgMap());
				amr.runOp();
			}
		}
		
		private Set<String> lookupSkipSet()
		{

			if(!_argMap.containsKey("skipset"))
				{ return Util.setify(); }

			return Util.setify(_argMap.getStr("skipset").split(","));

		}


		@SuppressWarnings( "deprecation" )
		public List<ArgMapRunnable> getTestList()
		{
			// TODO: this does not pick up new classes if we are creating them and deploying them with PackageShip
			List<String> allclass = Util.loadClassNameListFromDir(new File(CoreUtil.JCLASS_BASE_DIR));

			List<String> biglist = Util.filter2list(allclass, s -> s.contains(FAST_TEST_MARKER));
			
			List<ArgMapRunnable> amrlist = Util.map2list(biglist, s -> {
				try {
					ArgMapRunnable amr = (ArgMapRunnable) Class.forName(s).newInstance();
					return amr;
				} catch (Exception ex) { return null; }
			});
			
			return Util.filter2list(amrlist, amr -> amr != null && amr.getClass() != this.getClass());
		}
	}


	public static class BlobDirSetupCheck extends DescRunnable
	{

		private List<File> _requiredList = Util.vector();

		public String getDesc()
		{
			return
				"Ensure/Require that all blob-store DB tables have an appropriate directory configured\n" +
				"It is possible that this check is unnecessary and the blob storage logic should create the directory OD\n" +
				"But as of Sept 2024, it seems harmless to do it this way";

		}


		public void runOp()
		{
			boolean modokay = _argMap.getBit("modokay", false);
			boolean fastconfirm = _argMap.getBit("fastconfirm", false);

			setupRequiredList();

			if(_requiredList.isEmpty())
			{
				Util.pf("All Blob-Configured DB tables have appropriate directories\n");
				return;
			}

			Util.massert(modokay, "Found %d required directories, see above, run with modokay=true to fix", _requiredList.size());

			Util.pf("Will create the following directories:\n");

			for(File f : _requiredList)
			{
				Util.pf("\t%s\n", f.getAbsolutePath());
			}

			if(fastconfirm || Util.checkOkay("Okay to create?"))
			{
				for(File f : _requiredList)
				{
					f.mkdirs();
					Util.pf("Created directory %s\n", f.getAbsolutePath());
				}
			}
		}

		private void setupRequiredList()
		{
			int blobcount = 0;

			for(var user : WidgetUser.values())
			{
				for(var dbitem : WidgetItem.getUserWidgetList(user))
				{
					for(String table : dbitem.getDbTableNameSet())
					{
						var LTI = new LiteTableInfo(dbitem, table);
						LTI.runSetupQuery();

						if(!LTI.isBlobStoreTable())
							{ continue; }

						blobcount++;

						// Util.pf("Found blob-store DB table %s::%s\n", dbitem, table);

						String probepath = BlobDataManager.getStandardBlobAddress(dbitem, table, 10_000);
						File attachdir = BlobDataManager.getFullBlobLocalPath(probepath).getParentFile();

						if(!attachdir.exists())
						{
							Util.pferr("**Blob attachment directory is missing: %s\n", attachdir);
							_requiredList.add(attachdir);
						} else {
							Util.massert(attachdir.isDirectory(), "File is not a directory!!! %s", attachdir);
						}
					}
				}
			}

			Util.massert(blobcount >= 1, "Expected at least 1 blob-configured directories, found %d", blobcount);
			Util.pf("Found %d blob-configured DB tables\n", blobcount);
		}
	}


	public static class CheckMailBoxConfig extends DescRunnable
	{
		public String getDesc()
		{
			return "For all WidgetUsers with a mailbox, check that the mailbox is properly configured";
		}

		public void runOp()
		{

			// CREATE TABLE outgoing (id int, sent_at_utc varchar(19), send_target_utc varchar(19), recipient varchar(100), 
			// subject varchar(100), email_content varchar(1000), is_text smallint, primary key(id));

			Set<String> expectedcol = Util.setify("id", "sent_at_utc", "send_target_utc", "recipient", "subject", "email_content", "is_text");

			for(WidgetUser probe : WidgetUser.values())
			{
				if(!MailSystem.userHasMailBox(probe))
					{ continue; }

				WidgetItem mailbox = new WidgetItem(probe, MailSystem.MAILBOX_WIDGET_NAME);

				if(!mailbox.getLocalDbFile().exists())
					{ continue; }

				Util.pf("Found mailbox for user %s, checking configuration\n", probe);

				QueryCollector qcol = CoreUtil.tableQuery(mailbox, MailSystem.MAILBOX_DB_TABLE, Optional.of(10));

				for(ArgMap onemap : qcol.recList())
				{
					for(String col : expectedcol) 
						{ Util.massert(onemap.keySet().contains(col), "Missing expected column %s", col); }
				}
			}
		}
	}

	public static class CheckPrimaryKeyConfig extends DescRunnable
	{
		public String getDesc()
		{
			return "Check that every Widget table has a single primary Key 'id'";
		}

		public void runOp()
		{
			var expected = Arrays.asList("id");
			var badcount = 0;
			var okaycount = 0;

			for(var user : WidgetUser.values())
			{
				for(var item : WidgetItem.getUserWidgetList(user))
				{
					if(user.toString().equals("dburfoot") && item.theName.equals("life"))
						{ continue; }


					for(var table : item.getDbTableNameSet())
					{
						var LTI = new LiteTableInfo(item, table);
						LTI.runSetupQuery();
						if(!LTI.getPkeyList().equals(expected))
						{
							Util.pferr("Have PK list %s for %s :: %s\n", LTI.getPkeyList(), item, table);
							badcount += 1;
						} else {
							okaycount += 1;
						}
					}
				}
			}

			Util.massert(badcount == 0, "Got %d errors, see above", badcount);
			Util.pf("Checked %d tables okay\n", okaycount);
		}
	}



	
	public static class TestGuessMimeType extends DescRunnable
	{

		public String getDesc()
		{
			// https://stackoverflow.com/questions/19845213/how-to-get-the-methodinfo-of-a-java-8-method-reference
			return 
				"Simple test of the method java.net.URLConnection::guessContentTypeFromName" + 
				"Blob Storage code relies on this method to assign mime types based on file names";
		}

		public void runOp()
		{
			LinkedList<String> data = buildInputData();

			while(!data.isEmpty())
			{
				String input = data.poll();
				String expected = data.poll();
				String observed = java.net.URLConnection.guessContentTypeFromName(input);

				Util.massertEqual(expected, observed, "Expected %s but found %s for input %s", input);

			}
		}

		private static LinkedList<String> buildInputData() 
		{
			return Util.linkedlistify(
				"myImg.jpg", "image/jpeg",
				"DumbBookStoreSign.jpeg", "image/jpeg",
				"Dans' Great Picture.png", "image/png",
				"Dans' Great Picture.pdf", "application/pdf",
				// "2_2022 0806 Andeesheh Open House Agenda for distribution.xlsx", "...",
				// "DansSmartDocument.doc", "application/msword"
				"Dans' Great Picture.gif", "image/gif",
				"Dans' Great Picture.mp3", "audio/mpeg"

			);
		}

	}

	public static class CheckNewBlobAddress extends DescRunnable
	{
		public String getDesc()
		{
			return "Simple Check of new blob address tech";
		}
		
		
		public void runOp()
		{
			LinkedList<Object> input = buildInputData();
			
			while(!input.isEmpty())
			{
				int recordid = Util.cast(input.poll());
				String expected = Util.cast(input.poll());
				
				String observed = BlobDataManager.getBlobFileName(recordid);
				
				Util.massertEqual(expected, observed, "Expected/Observed: \n\t%s\n\t%s");
			}
			
			Random myrand = new Random();
			for(int attempt : Util.range(1000))
			{
				int probe = myrand.nextInt();
				String bfile = BlobDataManager.getBlobFileName(probe);
				Util.massert(bfile.length() == "blob__P0000000005".length(),
					"Result was %s", bfile);
				
				
				String search = (probe+"").replaceAll("-", "");
				Util.massert(bfile.contains(search));
			}
			
			Util.pf("Success, blob formatting worked okay\n");
		}
		
		private static LinkedList<Object> buildInputData() 
		{
			return Util.linkedlistify(
				5,    		"blob__P0000000005",
				1_426_625_285, 	"blob__P1426625285",
				-1_426_625_285, "blob__N1426625285",
				426_625_285,    "blob__P0426625285",
				-426_625_285, 	"blob__N0426625285",
				100,  		"blob__P0000000100",
				-100, 		"blob__N0000000100",
				0,    		"blob__P0000000000",
				Integer.MAX_VALUE, "blob__P" + Integer.MAX_VALUE,
				Integer.MIN_VALUE, ("blob__N" + Integer.MIN_VALUE).replaceAll("-", "")
			);
		}
	}

	public static class Base64EncodeTest extends DescRunnable
	{
		public String getDesc()
		{
			return "Test of Base 64 encode / decode";

		}

		public void runOp()
		{
			backAndForthTest("daniel.burfoot@gmail.com");
			backAndForthTest("/opt/homebrew/opt/ffmpeg/bin/ffmpeg -i Sept29.mp4 -ss 0:24 -to 11:53 -c:v copy -c:a");
			backAndForthTest("For plugintype=admin_extend, found object io.webwidgets.extend.AdminExtender");
		}

		private static void backAndForthTest(String original)
		{

			String encoded = CoreUtil.base64Encode(original);
			String decoded = CoreUtil.base64Decode(encoded);

			Util.massert(decoded.equals(original), "Encoded %s but decoded %s", original, decoded);
		}

	}


	
	public static class TestLoadPluginInfo extends DescRunnable
	{
		public String getDesc()
		{
			return "Confirm that the Plugin config and classes can be successfully loaded";
		}

		public void runOp()
		{
			var classmap = PluginCentral.getPluginClassMap();
			Util.pf("Success, loaded plugins successfully, map is %s\n", classmap);
		}
		
	}

	public static class CheckDataIncludeError extends DescRunnable
	{
		private int _goodCount = 0;
		private int _baddCount = 0;

		public String getDesc()
		{
			return "Confirm that the DataInclude parser behaves as appropriate, including errors when bad data is passed";
		}

		public void runOp()
		{
			checkResult("");

			checkResult("tables=my_table", DataIncludeArg.tables);
			checkResult("widgetname=danstuff&tables=my_table", DataIncludeArg.tables, DataIncludeArg.widgetname);
			checkResult("no_data=true&widgetname=dantench", DataIncludeArg.widgetname, DataIncludeArg.no_data);

			checkError("table=my_table", "Invalid DataServer include");
			checkError("no_data", "invalid Key=Value term");
			checkError("tables=dantech&tables=mytech", "Duplicate DataServer include argument __tables__");

			Util.pf("Success, got %d good and %d bad expected results\n", _goodCount, _baddCount);
		}


		private void checkError(String query, String messagetag)
		{

			try {
				var amap = DataServer.buildIncludeMap(query);
				Util.massert(false, "Failed to throw exception as expected");

			} catch (Exception ex) {
				Util.massert(ex.getMessage().contains(messagetag), 
					"Failed to find tag %s in error %s", messagetag, ex.getMessage());
			}

			_baddCount++;
		}

		private void checkResult(String query, DataIncludeArg... expect)
		{
			Map<DataIncludeArg, String> amap = DataServer.buildIncludeMap(query);
			Util.massert(amap.size() == expect.length);

			for(DataIncludeArg darg : expect) {
				Util.massert(amap.containsKey(darg), "Missing argument %s", darg);
			}

			_goodCount++;
		}

	}
	
	public static class CheckMasterDbSetup extends DescRunnable
	{
		public String getDesc()
		{
			return 
				"Checks that the MASTER DB is setup properly\n" + 
				"The file must exist in the right place, and have SQL statements\n" +
				"That agree with what is specified in the Java code";
		}
		
		public void runOp()
		{
			WidgetUser shared = WidgetUser.buildBackDoorSharedUser();
			WidgetItem master = new WidgetItem(shared, CoreUtil.MASTER_WIDGET_NAME);
			
			{
				File dbfile = master.getLocalDbFile();
				Util.massert(dbfile.exists(), "Master DB file expected at %s, does not exist", dbfile);
			}

			String query = "SELECT * FROM sqlite_master";
			QueryCollector qcol = QueryCollector.buildAndRun(query, master);
			Map<String, String> create = Util.map2map(qcol.recList(), amap -> amap.getStr("name"), amap -> amap.getStr("sql"));		

			for(MasterTable mtable : MasterTable.values())
			{
				String observed = create.getOrDefault(mtable.toString(), "Not Present");
				String expected = mtable.createSql;
				
				Util.massert(observed.equals(expected),
					"For table %s, have DB SQL vs expected SQL:\n\t%s\n\t%s", 
					mtable, observed, expected
				);
			}
			
			Util.pf("Success, checked %d MasterTable definitions\n", MasterTable.values().length);
		}
	}


	public static class WispTagParseTest extends ArgMapRunnable
	{

		Map<String, Integer> _okayCount = Util.treemap();

		public void runOp()
		{
			Util.pf("Going to run wisp tag parse\n");


			checkOkayBasic();
			checkBadBasic();
			checkOkayEmpty();
			checkBadConvert();
			checkOkayConvert();

			Util.pf("Checked all the data okay, result is %s\n", _okayCount);
		}

		private void checkOkayEmpty()
		{
			String code = "OkayEmpty";

			for(String fixt : loadFixtureData(code))
			{
				Map<String, String> attmap = WispTagParser.parse2AttributeMap(fixt);
				Util.massert(attmap != null && attmap.isEmpty());
				Util.incHitMap(_okayCount, code);
			}
		}



		private void checkOkayBasic()
		{
			String code = "OkayBasic";

			for(String fixt : loadFixtureData(code))
			{
				Map<String, String> attmap = WispTagParser.parse2AttributeMap(fixt);
				Util.massert(attmap != null && attmap.containsKey("tables"),
					"Failed to parse okay fixture %s, attmap is %s", fixt, attmap);
				Util.incHitMap(_okayCount, code);
			}
		}


		private void checkBadBasic()
		{
			String code = "BadBasic";

			for(String fixt : loadFixtureData(code))
			{
				Map<String, String> attmap = WispTagParser.parse2AttributeMap(fixt);
				Util.massert(attmap == null);
				Util.incHitMap(_okayCount, code);
			}
		}


		private void checkBadConvert()
		{
			String code = "BadConvert";

			for(String fixt : loadFixtureData(code))
			{
				try {
					Map<DataIncludeArg, String> incmap = WispTagParser.parse2DataMap(fixt);
					Util.massert(false, "This should throw an exception");

				} catch (IllegalArgumentException illex) {
				}
				Util.incHitMap(_okayCount, code);
			}
		}

		private void checkOkayConvert()
		{
			String code = "OkayConvert";

			for(String fixt : loadFixtureData(code))
			{
				Map<DataIncludeArg, String> incmap = WispTagParser.parse2DataMap(fixt);
				Util.incHitMap(_okayCount, code);
			}
		}

		private static List<String> loadFixtureData(String codename)
		{
			List<String> tokens = Arrays.asList(
				CoreUtil.REPO_BASE_DIRECTORY,
				"server", "testdata", "wisptag",
				Util.sprintf("%s.txt", codename)
			);

			String inputfile = Util.join(tokens, File.separator);
			Util.massert((new File(inputfile)).exists(), "Could not find test fixture data %s", inputfile);

			// Allow comments
			List<String> data = FileUtils.getReaderUtil().setFile(inputfile).readLineListE();
			return Util.filter2list(data, line -> line.trim().length() > 0 && !line.trim().startsWith("//"));
		}

	}

	public static class TestJsonTypeConvert extends ArgMapRunnable
	{

		public void runOp() throws Exception
		{
			for(boolean isgood : Util.listify(true, false))
			{
				List<String> intlist = isgood ? getOkayIntList() : getBadIntList();
				for(String s : intlist)
				{
					boolean okay = true;
					try {
						JSONObject jsonob = Util.cast((new JSONParser()).parse(s));
						Integer info = Util.cast(LiteTableInfo.getJsonPayLoad("info", "INT", jsonob));
						Util.pf("Got int %s\n", info);
					} catch (Exception ex) {
						okay = false;
					}

					Util.massert(okay == isgood, "Got okay=%b but expected %b for %s", okay, isgood, s);

				}

				List<String> dbllist = isgood ? getOkayDblList() : getBadDblList();
				for(String s : dbllist)
				{
					boolean okay = true;
					try {
						JSONObject jsonob = Util.cast((new JSONParser()).parse(s));
						Double info = Util.cast(LiteTableInfo.getJsonPayLoad("info", "REAL", jsonob));
						Util.pf("Got double %s\n", info);
					} catch (Exception ex) {
						okay = false;
					}

					Util.massert(okay == isgood, "Got okay=%b but expected %b for %s", okay, isgood, s);
				}
			}
		}


		private static List<String> getBadIntList()
		{
			return Util.listify(
				"{ \"info\" : 454.2343 } ",
				"{ \"info\" : \"x1\" } "
			);

		}

		private static List<String> getOkayIntList()
		{
			return Util.listify(
				"{ \"info\" : null } ",
				"{ \"info\" : 5 } "
			);


		}

		private static List<String> getOkayDblList()
		{
			return Util.listify(
				// "{ \"info\" : null } ",
				"{ \"info\" : 5.4234 } ",
				"{ \"info\" : 0 } ",
				"{ \"info\" : 45 } "
			);
		}

		private static List<String> getBadDblList()
		{
			return Util.listify(
				"{ \"info\" : \"another\" } ",
				"{ \"info\" : \"x1\" } "

			);
		}
	}


	public static class TestDefaultExtractor extends ArgMapRunnable
	{

		public void runOp()
		{

			for(var pr : getGoodExpected().entrySet())
			{

				var result = LiteTableInfo.extractDefaultInfo(pr.getKey());

				Util.massertEqual(result.get(), pr.getValue(),
					"Observed %s but expected %s for input %s", pr.getKey());
			}

			for(var bad : getDistractorList())
			{
				var result = LiteTableInfo.extractDefaultInfo(bad);

				Util.massert(!result.isPresent(), "Got result %s when expecting no result for input %s", result, bad);
			}

		}

		private List<String> getDistractorList() 
		{

			return Util.listify(
				"VARCHAR(100) DEFAULT 'Unknown",
				"real DEFAULT 4...5",
				"boolean DEFAULT tru",
				"boolean DEFAULT falsey",
				// TODO: eventually, we should deal with default null
				"boolean DEFAULT null"
			);
		}

		private LinkedHashMap<String, Object> getGoodExpected() 
		{

			return CoreDb.getRecMap(
				"VARCHAR(100) DEFAULT 'Unknown'", "Unknown",
				"VARCHAR(10) defAuLT 'xyz'", "xyz",
				"real defAuLT \"xyz\"", "xyz",
				"boolean DEFAULT FALSE NOT NULL", false,
				"real DEFAULT 4.5", 4.5,
				"integer DEFAULT 878", 878,
				"integer DEFAULT 878 NULL", 878,
				"boolean DEFAULT true", true,
				"boolean DEFAULT FALSE", false
			);
		}
	}

	public static class FindPreferredGalleryTest extends ArgMapRunnable
	{
		public void runOp()
		{
			File galldir = new File(CoreUtil.GALLERY_CODE_DIR);
			Util.massert(galldir.exists() && galldir.isDirectory(), 
				"Problem with gallery directory %s", CoreUtil.GALLERY_CODE_DIR);

			for(File subdir : galldir.listFiles())
			{
				if(!subdir.isDirectory())
					{ continue; }

				Optional<File> prefer = CoreUtil.findPreferredWidgetFile(subdir);
				Util.massert(prefer.isPresent(),
					"Failed to find preferred widget file gallery directory %s", subdir);


				Util.pf("Success, found preferred file %s for gallery %s\n", prefer.get().getName(), subdir.getName());
			}
		}
	}
}

