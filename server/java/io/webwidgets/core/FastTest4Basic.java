
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 
import java.net.*; 
import java.util.function.BiFunction;


import net.danburfoot.shared.Util;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.FileUtils;

import net.danburfoot.shared.RunnableTech.*;
import net.danburfoot.shared.Util.SyscallWrapper;
import net.danburfoot.shared.CoreDb.QueryCollector;


import	io.webwidgets.core.LifeUtil.*;
import	io.webwidgets.core.WidgetOrg.*;
import	io.webwidgets.core.AuthLogic.*;
import	io.webwidgets.core.MailSystem.*;
import	io.webwidgets.core.PluginCentral.*;
import	io.webwidgets.core.BlobDataManager.*;

public class FastTest4Basic
{

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
			WidgetUser heather1 = WidgetUser.valueOf("heather");
			WidgetUser heather2 = WidgetUser.valueOf("heather");
			// Util.pf("H1 = %s, H2 = %s\n", heather1, heather2);
			Util.massert(heather1 == heather2, "WidgetUser objects must be unique, hard equals must work");

			WidgetItem moodlog = new WidgetItem(WidgetUser.valueOf("heather"), "mood");
			Util.massert(heather1 == moodlog.theOwner);

			boolean allow = AuthChecker.build().directSetAccessor(heather1).directDbWidget(moodlog).allowRead();
			Util.massert(allow, "Must allow access to owner");
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
			Set<WidgetUser> adminheather = Util.setify(WidgetUser.getDburfootUser(), WidgetUser.valueOf("bettworld"), WidgetUser.valueOf("heather"));
			
			for(WidgetUser wuser : WidgetUser.values())
			{
				WidgetItem probe = new WidgetItem(WidgetUser.valueOf("heather"), "mood");			
				boolean allow = AuthChecker.build().directSetAccessor(wuser).directDbWidget(probe).allowRead();
				boolean expect = adminheather.contains(wuser);
				Util.massert(allow == expect,
					"Got allow=%s but expected %s for wuser=%s", allow, expect, wuser);
			}
			
			for(WidgetUser wuser : WidgetUser.values())
			{
				String page = getHeatherPage();
				boolean allow = AuthChecker.build().widgetFromUrl(page).directSetAccessor(wuser).allowRead();
				boolean expect = adminheather.contains(wuser);
				Util.massert(allow == expect,
					"Got allow=%s but expected %s for wuser=%s", allow, expect, wuser);
			}
			
			for(WidgetUser wuser : WidgetUser.values())
			{
				String page = getDburfootPage();
				boolean allow = AuthChecker.build().widgetFromUrl(page).directSetAccessor(wuser).allowRead();
				boolean expect = wuser == WidgetUser.getDburfootUser();
				Util.massert(allow == expect,
					"Got allow=%s but expected %s for wuser=%s", allow, expect, wuser);
			}			
		}
		
		private String getHeatherPage() 
		{
			return "https://webwidgets.io/u/heather/mood/main.jsp";	
		}
		
		private String getDburfootPage()
		{
			return "https://webwidgets.io/u/dburfoot/life/main.jsp";	
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

			Set<String> codeset = getFolderKidSet(new File(LifeUtil.WIDGETS_DIR));
			{
				codeset.remove("admin");
				codeset.remove("exadmin");
				codeset.remove("resin-data");
				codeset.remove("WEB-INF");
			}

			{
				Set<String> checkset = getFolderKidSet(new File(LifeUtil.WIDGET_DB_DIR));
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


	public static class TestWuserDataLoad extends ArgMapRunnable
	{

		public void runOp()
		{
			for(WidgetUser user : WidgetUser.values())
				{ Util.massert(user.haveUserEntry(), "Did not find USER entry for user %s", user); }

			WidgetUser dburfoot = WidgetUser.lookup("dburfoot");
			Util.massert(dburfoot.isAdmin());
			Util.massertEqual(dburfoot.getEmail(), "daniel.burfoot@gmail.com",
				"Dburfoot email is reported as %s but expected %s");

			Util.pf("Success, found user entries for all WidgetUser records\n");
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
			String deftag = String.format("widgetOwner : \"%s\"", user.toString());

			for(WidgetItem dbitem : user.getUserWidgetList())
			{
				File jsdir = WebUtil.getAutoGenJsDir(dbitem);
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



	public static class ServerPageAuthInclude extends DescRunnable
	{
		int _okayCount = 0;
		int _errCount = 0;
		
		public String SEARCH_TAG = "../admin/AuthInclude.jsp_inc";
		
		public String getDesc()
		{
			return "Check that all the JSPs in the directory  " + LifeUtil.WIDGETS_DIR + "\n"  +
				"Contain the Auth Include tag " + SEARCH_TAG + "\n" + 
				"This is the crucial include file to ensure proper authentication checks";
		}
		
		public void runOp()
		{
			File startdir = new File(LifeUtil.WIDGETS_DIR);
			
			recurseCheck(startdir, 0);
			
			Util.massert(_errCount == 0, "Got %d error paths, see above", _errCount);
			Util.massert(_okayCount > 20, "Should have at least 20 JSP checks");
			
			Util.pf("Success, checked %d JSP files\n", _okayCount);	
		}
		
		private void recurseCheck(File thefile, int depth)
		{			
			if(thefile.getAbsolutePath().contains(LifeUtil.WIDGET_ADMIN_DIR))
				{ return; }

			if(thefile.getAbsolutePath().contains("dburfoot/docview"))
				{ return; }

			
			if(thefile.isDirectory())
			{
				for(File sub : thefile.listFiles())
					{  recurseCheck(sub, depth+1); }				
			}

			if(!thefile.getAbsolutePath().endsWith(".jsp"))
				{ return; }

			// These are base-level .JSPs
			if(depth <= 2)
				{ return; }

			for(String special : Util.listify("docview", "biz"))
			{
				String search = "dburfoot/" + special;
				
				if(thefile.getAbsolutePath().contains(search))
					{ return; }
			}			
			
			List<String> data = FileUtils.getReaderUtil()
							.setFile(thefile)
							.readLineListE();
			
			int cp = Util.countPred(data, s -> s.indexOf(SEARCH_TAG) > -1);
			Util.massert(cp <= 1, "Got MULTIPLE %d hits for file %s", cp, thefile);
			


			for(String special : Util.listify("LogIn"))
			{
				if(thefile.getAbsolutePath().endsWith(special + ".jsp"))
				{
					Util.massert(cp == 0, "Expected ZERO Auths in special file %s", thefile.getAbsolutePath());
					return;
				}
			}			
			
			if(cp == 1)
			{ 	
				_okayCount += 1; 
				return;
			}
			
			_errCount += 1;
			Util.pferr("Failed to find AuthInclude in JSP file %s\n", thefile);
		}
	}	
	
	public static class DbInfoTest extends DescRunnable
	{
		public String getDesc()
		{
			return "Ensures for DBurfoot databases only that \n" + 
				"There is no overlap in table names between Widgets";
		}
		
		
		public void runOp()
		{
			boolean modokay = _argMap.getBit("modokay", false);
			Map<String, List<String>> datamap = Util.treemap();
			
			for(WidgetItem witem : WidgetUser.getDburfootUser().getUserWidgetList())
			{
				Set<String> tableset = witem.getDbTableNameSet();	
				// Util.pf("Found tableset %s :: %s\n", witem.theName, tableset);
				
				for(String tbl : tableset)
				{
					datamap.putIfAbsent(tbl, Util.vector());
					datamap.get(tbl).add(witem.theName);
				}
			}
			
			int errcount = 0;
			LinkedList<String> lifemove = Util.linkedlist();			
			for(String tbl : datamap.keySet())
			{
				List<String> wlist = datamap.get(tbl);
				
				if(wlist.size() != 1)
				{
					Util.pf("Found multiple widgets with table names %s :: %s\n", tbl, wlist);
					
					if(wlist.contains("life"))
						{ lifemove.add(tbl); }
					
					errcount++;
				}
			}
			
			if(errcount == 0)
			{
				Util.pf("No misconf'ed tables found, quitting\n");
				return;
				
			}
			
			if(lifemove.isEmpty())
				{ return; }

			Util.massert(modokay || lifemove.size() == 0,
				"Have move proposals, rerun with modokay=true to fix");


			
			Util.pf("Found %d move proposals\n", lifemove.size());
			String moveme = lifemove.poll();
			
			String update = Util.sprintf("ALTER TABLE %s RENAME TO __%s", moveme, moveme);
			
			Util.pf("Propose to run this command in LIFE db:\n");
			Util.pf("\t%s\n", update);
			
			if(Util.checkOkay("Okay to move?"))
			{
				WidgetItem lifewidget = new WidgetItem(WidgetUser.getDburfootUser(), "life");	
				CoreDb.execSqlUpdate(update, lifewidget);
				Util.pf("Obsoleted table %s, rerun to continue with next table\n", moveme);	
			}
			
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
			IBlobStorage blobtool = PluginCentral.getStorageTool();
			Util.pf("Loaded blob storage tool %s\n", blobtool.getClass().getName());

			IMailSender mailtool = PluginCentral.getMailPlugin();
			Util.pf("Loaded mail plugin %s\n", mailtool.getClass().getName());

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
			
			for(WidgetUser wuser : WidgetUser.values())
			{
				for(WidgetItem witem : wuser.getUserWidgetList())
				{
					// This doens't work, filters out the __ prefixes
					// Set<String> nameset = witem.getDbTableNameSet();
					
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
				if(!wuser.haveLocalDb())
					{ continue; }
				
				List<WidgetItem> itemlist = wuser.getUserWidgetList();
				for(WidgetItem witem : itemlist)
				{
					for(String dbname : witem.getDbTableNameSet())
					{
						if(dbname.startsWith("__"))
							{ continue; }
						
						// nodatamode = true, this makes it run much faster
						LiteTableInfo tinfo = new LiteTableInfo(witem, dbname, true);
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
		public static final String FAST_TEST_MARKER = LifeUtil.peelSuffix(FastTest4Basic.class.getSimpleName(), "Basic");

		public String getDesc()
		{
			return 
				"Inspects to find the other inner classes in this class\n" + 
				"And runs them as unit tests\n" + 
				"Any ArgMapRunnable inner class you put in this file will run as a unit test";
		}
		
		public void runOp() throws Exception
		{
			for(ArgMapRunnable amr : getTestList())
			{
				Util.pf("Running test: %s\n", amr.getClass().getSimpleName());		
				amr.initFromArgMap(new ArgMap());
				amr.runOp();
			}
		}
		
		@SuppressWarnings( "deprecation" )
		public List<ArgMapRunnable> getTestList()
		{
			
			List<String> allclass = Util.loadClassNameListFromDir(new File(LifeUtil.JCLASS_BASE_DIR));

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

	public static class CredentialFileCheck extends DescRunnable 
	{
		public String getDesc()
		{
			return "Checks that all of the credential files exist";
		}

		public void runOp()
		{
			checkPath(GoogleSyncUtil.CREDENTIAL_PATH);

			checkPath(LifeUtil.PYTHON_AUTOGEN_DOC);
		}

		private void checkPath(String path) 
		{
			checkFile(new File(path));
		}

		private void checkFile(File file)
		{
			Util.pf("Checking file path %s\n", file);

			Util.massert(file.exists(), "Config file %s does not exist", file.getAbsolutePath());
		}
	}


	public static class PythonConfigCheck extends DescRunnable 
	{
		public static final String PYTHON_SCRIPT_CONFIG_SUCCESS = "PY_SCRIPT_OKAY";

		public String getDesc() 
		{
			return 
				"Calls the Python scripts to make sure they are working properly\n" + 
				"The scripts must emit a special tag on successful completion\n" + 
				"The tag is : " + PYTHON_SCRIPT_CONFIG_SUCCESS;
		}

		public static final List<String> SCRIPT_LIST = Util.listify(
			// "Lite2Excel"
			"MarkDownCheck",
			"GoogleApiCheck",
			"ClubDataGrabber"
		);

		public static final Set<String> VIMS_SCRIPT_SET = Util.setify("ClubDataGrabber");

		public static String getFullPyPath(String base) 
		{
			String folder = VIMS_SCRIPT_SET.contains(base) ? "vims" : "utility";

			// TODO: this should not be a hardcoded path
			return String.format("%s/%s/%s.py", LifeUtil.SCRIPT_DIR, folder, base);
		}

		public void runOp() 
		{
			for(String pybase : SCRIPT_LIST)
			{
				String pypath = getFullPyPath(pybase);

				Util.massert((new File(pypath)).exists(), "Python script %s does not exist", pypath);

				String pycall = Util.sprintf("python3 %s configcheck=true", pypath);

				SyscallWrapper syswrap = SyscallWrapper.build(pycall).execE();

				if(!syswrap.getErrList().isEmpty())
				{
					Util.pferr("** Errors Detected!! : \n");
					for(String err : syswrap.getErrList()) 
						{ Util.pferr("\t%s\n", err); }
				}


				for(String out : syswrap.getOutList()) {
					Util.pf("\t%s\n", out);
				}

				List<String> hits = Util.filter2list(syswrap.getOutList(), s -> s.contains(PYTHON_SCRIPT_CONFIG_SUCCESS));

				Util.massert(hits.size() >= 1, "Failed to find success confirm tag in output, see above");

				Util.pf("Script %s.py checked successfully\n", pybase);
			}

			Util.pf("Success, checked %d Python scripts okay\n", SCRIPT_LIST.size());
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
				WidgetItem mailbox = new WidgetItem(probe, MailSystem.MAILBOX_WIDGET_NAME);

				if(!mailbox.getLocalDbFile().exists())
					{ continue; }

				Util.pf("Found mailbox for user %s, checking configuration\n", probe);

				QueryCollector qcol = LifeUtil.tableQuery(mailbox, MailSystem.MAILBOX_DB_TABLE, Optional.of(10));

				for(ArgMap onemap : qcol.recList())
				{
					for(String col : expectedcol) 
						{ Util.massert(onemap.keySet().contains(col), "Missing expected column %s", col); }
				}
			}
		}
	}

	public static class CheckUrlWidgetLookup extends DescRunnable
	{

		public String getDesc()
		{
			return "Check logic of looking up WidgetItem from URL";
		}

		public void runOp()
		{

			{
				WidgetItem dbbase = WidgetUser.getDburfootUser().baseWidget();
				for(String baseurl : getDbBaseList()) 
				{
					WidgetItem probe = WebUtil.getWidgetFromUrl(baseurl);
					Util.massert(dbbase.equals(probe), "Wanted %s but got %s", dbbase, probe);
				}
			}

			LinkedList<String> otherlist = Util.linkedlistify(getOtherList());

			while(!otherlist.isEmpty())
			{
				String url = otherlist.poll();
				WidgetUser wuser = WidgetUser.valueOf(otherlist.poll());
				WidgetItem witem = new WidgetItem(wuser, otherlist.poll());

				WidgetItem probe = WebUtil.getWidgetFromUrl(url);
				Util.massert(witem.equals(probe), "Expected %s but got %s", witem, probe);
			}

		}

		private List<String> getDbBaseList() 
		{
			return Arrays.asList(
				"https://webwidgets.io/u/dburfoot/",
				"https://webwidgets.io/u/dburfoot",				
				"https://webwidgets.io/u/dburfoot/index.jsp",
				"https://webwidgets.io/u/dburfoot/widget.jsp"
			);
		}

		private List<String> getOtherList()
		{
			return Arrays.asList(
				"https://webwidgets.io/u/d57tm/index.jsp",
				"d57tm",
				"base",
				"https://webwidgets.io/u/dburfoot/links/widget.jsp",
				"dburfoot",
				"links"
				/*
				"https://webwidgets.io/u/dburfoot/links/",
				"dburfoot",
				"links"				
				*/
			);
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

	public static class GoogleSyncTest extends LifeCli.GoogleSyncAdmin
	{
		WidgetItem DB_CHORE_WIDGET = new WidgetItem(WidgetUser.getDburfootUser(), "chores");

		public String getDesc()
		{
			return 
				"Test version of the GoogleSyncAdmin\n" + 
				"Uploads the Widget " + DB_CHORE_WIDGET;
		}

		public void runOp()
		{
			super.runOp();
			Util.massert(opSuccess, "Sync operation failed");
		}	

		@Override
		public WidgetItem getDbItem()
		{
			return DB_CHORE_WIDGET;
		}
	}

	public static class EmailComposeLinkMagic extends DescRunnable
	{
		public String getDesc()
		{
			return "Test that the reflection magic works";
		}

		public void runOp()
		{
			{
				BiFunction<ValidatedEmail, WidgetUser, String> myfunc = MailSystem.getEmailComposeLink();
				String result = myfunc.apply(ValidatedEmail.from("daniel.burfoot@gmail.com"), WidgetUser.getDburfootUser());
				Util.pf("Result is %s\n", result);
			}


			{
				BiFunction<ValidatedEmail, WidgetUser, Boolean> myfunc = MailSystem.getEmailControlSend();
				boolean result = myfunc.apply(ValidatedEmail.from("daniel.burfoot@gmail.com"), WidgetUser.getDburfootUser());
				Util.pf("Result is %s\n", result);
			}
		}

	}
	
	public static class Base64EncodeTest extends DescRunnable
	{
		public String getDesc()
		{
			return "Test of Base 64 encode / decode";

		}

		// TODO: add more data here, including maybe Chinese, etc
		public void runOp()
		{

			backAndForthTest("daniel.burfoot@gmail.com");

		}

		private static void backAndForthTest(String original)
		{

			String encoded = LifeUtil.base64Encode(original);
			String decoded = LifeUtil.base64Decode(encoded);

			Util.massert(decoded.equals(original), "Encoded %s but decoded %s", original, decoded);
		}

	}

	public static class PingWwioSite extends DescRunnable
	{

		public String getDesc()
		{	
			return "Just ping the WWIO site, get a simple page";
		}

		public void runOp() throws Exception
		{
			for(String relpath : getRelativePathList())
			{
				String fullurl = String.format("https://%s%s", WebUtil.WWIO_DOMAIN, relpath);
				URLConnection connection = new URL(fullurl).openConnection();
				InputStream response = connection.getInputStream();

				ByteArrayOutputStream baos = new ByteArrayOutputStream();
				FileUtils.in2out(response, baos);

				int rsize = baos.size();
				Util.massert(rsize > 1000, "Got only %d bytes of response data", rsize);
				Util.pf("Success, pinged page %s and received %d bytes of response\n", fullurl, rsize);
			}
		}

		private static List<String> getRelativePathList() 
		{
			return Arrays.asList(
				"",
				"/u/admin/EmailControl.jsp?sender=dburfoot",
				"/docs/JsFileDoc.jsp",
				"/docs/PythonDoc.jsp",
				"/docs/WidgetSetup.jsp",
				"/docs/GoogleExport.jsp",
				"/u/admin/AdminMain.jsp",
				"/u/admin/ImportWidget.jsp",
				"/u/admin/ChangePass.jsp",
				"/u/admin/Bounce2Home.jsp",
				"/u/admin/MailRunner.jsp",
				"/u/admin/GoogleSyncMain.jsp"
			);
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
} 

