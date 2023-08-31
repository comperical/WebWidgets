
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 

import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;


import net.danburfoot.shared.Util;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.TimeUtil.*;
import net.danburfoot.shared.RunnableTech.*;
import net.danburfoot.shared.Util.SyscallWrapper;
import net.danburfoot.shared.CoreDb.QueryCollector;

import io.webwidgets.core.WidgetOrg.*;


public class GoogleSyncUtil
{ 	
	public static final String GDOC_TSV_TABLE = "gdoc_tsv_upload";

	public static final String GDOC_SCRIPT_DIR = LifeUtil.SCRIPT_DIR + "/gdocs";	
	
	public static final String CREDENTIAL_PATH = "/home/ec2-user/.ssh/gcp-api-widget-quickstart.json";
	
	// Map of user to Google Drive sync dirs
	public static Map<WidgetUser, String> getGoogleDriveFolder()
	{
		Map<WidgetUser, String> result = Util.treemap();
		String query = "SELECT * FROM user_main";
		QueryCollector qcol = QueryCollector.buildAndRun(query, LifeUtil.getMasterWidget());
		
		for(ArgMap amap : qcol.recList())
		{
			WidgetUser wuser = WidgetUser.valueOf(amap.getStr("username"));
			String gdrive = amap.getStr("gdrive_folder");
			
			if(gdrive != null && gdrive.length() > 0)
			{
				Util.massert(gdrive.length() > 10, 
					"Expected these strings to be longish, got %s", gdrive);
				
				result.put(wuser, gdrive);
			}
		}
		
		return result;
	}	

	public static Map<Boolean, List<String>> googleSyncWrapper(WidgetItem witem)
	{
		Util.massert(witem.getLocalDbFile().exists(),
			"Widget %s does not exist locally");
		
		String syscall = Util.sprintf("python3 %s/entry.py SyncWidget litepath=%s", 
			GDOC_SCRIPT_DIR, witem.getLocalDbFile().toString());
		
		Util.pf("Syscall is %s\n", syscall);
		
		SyscallWrapper syswrap = SyscallWrapper.build(syscall).execE();
		
		Map<Boolean, List<String>> result = Util.treemap();
		result.put(true, syswrap.getOutList());
		result.put(false, syswrap.getErrList());
		return result;
	}	
	
	
	public static class ShowGoogleDriveInfo extends DescRunnable
	{
		public String getDesc()
		{
			return "Just shows the current mapping of user/GDrive folder";	
		}
		
		
		public void runOp()
		{
			Map<WidgetUser, String> drivemap = GoogleSyncUtil.getGoogleDriveFolder();
			
			for(WidgetUser wuser : drivemap.keySet())
			{
				Util.pf("For user=%s, found GDrive folder %s\n",
					wuser, drivemap.get(wuser));
			}
		}
	}
	
	public static class UpdateGoogleDriveInfo extends DescRunnable 
	{
		public String getDesc()
		{
			return 
				"Update the google drive for a user\n" +
				"Arguments are username and syncfolder\n" + 
				"The sync folder is a Google drive ID that you get from Google docs\n" +
				"It is the ID of the subfolder of WidgetSync that has the same name as the user\n" + 
				"And is shared with him/her";
			
			
		}
		
		
		public void runOp()
		{
			String username = _argMap.getStr("username");
			String syncfolder = _argMap.getStr("syncfolder");
			
			String query = String.format("SELECT id FROM user_main WHERE username = '%s'", username);
			QueryCollector qcol = QueryCollector.buildAndRun(query, LifeUtil.getMasterWidget());
			int userid = qcol.getSingleArgMap().getSingleInt();
			
			CoreDb.upsertFromRecMap(LifeUtil.getMasterWidget(), "user_main", 1, CoreDb.getRecMap(
				"id", userid,
				"gdrive_folder", syncfolder
			));
			
			Util.pf("Okay, updated record for id=%d, user=%s, to %s\n", userid, username, syncfolder);
		}	
	}

	public static class RunTsvUpload extends ArgMapRunnable implements CrontabRunnable
	{

        // Wanted to run this every 2 hours, but cron tech doesn't support every N minutes bigger than 60!!
        public static final int MINUTES_BETWEEN_SEND = 30;

		public String getDesc()
		{
			return "Upload any GDoc tab separated data records that need upload\n" + 
					"Basically trust the user to only mark need_upload when appropriate\n" + 
					"Finds WidgetItems that have GDoc TSV data by looking for tables named " + GDOC_TSV_TABLE + "\n" +
					"By checking for presence of appropriately named table";
		}

		public void runOp()
		{
			int failcount = 0;

			List<WidgetItem> itemlist = findGdocUploadList();
			Util.massert(itemlist.size() >= 2, "Expected at least two hits, found %s", itemlist);

			for(WidgetItem witem : itemlist)
			{

				Util.pf("Checking Widget %s\n", witem);

				List<Integer> idlist = getNeedUploadList(witem);
				if(idlist.isEmpty())
				{
					Util.pf("No records found needing update, quitting\n");
					continue;
				}

				for(int oneid : idlist)
				{
					String pycall = getPythonCommand(witem, oneid);
					SyscallWrapper syswrap = SyscallWrapper.build(pycall).execE();
					
					if(syswrap.getErrList().size() > 0)
					{
						String errinfo = Util.join(syswrap.getErrList(), "\n");
						Util.pferr("Got error info for Widget %s, ID %d:\nSyscall:\n\t%s\n%s\n", witem, oneid, pycall, errinfo);
						failcount++;
						continue;
					}

					Optional<String> success = syswrap.getOutList().stream().filter(s -> s.contains("SUCCESS")).findFirst();
					if(!success.isPresent())
					{
						Util.pf("Failed to find success tag in output\n");
						failcount++;
						continue;					
					}

					Util.pf("%s\n", success.get());
					String utcnow = ExactMoment.build().asLongBasicTs(TimeZoneEnum.UTC);
					CoreDb.upsertFromRecMap(witem, "gdoc_tsv_upload", 1, CoreDb.getRecMap(
						"id", oneid,
						"need_upload", 0,
						"uploaded_on_utc", utcnow
					));

					Util.pf("Updating record %d with timestamp %s\n", oneid, utcnow);
				}

				Util.massert(failcount == 0, "Got errors, see above");
			}

		}

		static List<WidgetItem> findGdocUploadList()
		{
			List<WidgetItem> result = Util.vector();

			for(WidgetUser user : WidgetUser.values())
			{
				for(WidgetItem item : user.getUserWidgetList())
				{
					Set<String> tableset = item.getDbTableNameSet();
					if(tableset.contains(GDOC_TSV_TABLE))
						{ result.add(item); }
				}
			}

			return result;
		}

		private static List<Integer> getNeedUploadList(WidgetItem witem)
		{
			QueryCollector qcol = QueryCollector.buildAndRun("SELECT id FROM gdoc_tsv_upload WHERE need_upload = 1", witem);
			return Util.map2list(qcol.recList(), amap -> amap.getSingleInt());
		}

		private static String getPythonCommand(WidgetItem witem, int recordid)
		{
			return Util.sprintf("python3 %s/entry.py TabSepUpload litepath=%s record_id=%d", 
				GDOC_SCRIPT_DIR, witem.getLocalDbFile().toString(), recordid);
		}

		public static Map<Boolean, List<String>> googleSyncWrapper(WidgetItem witem)
		{
			return null;
		}		

	}

	public static class ShowTsvData extends DescRunnable
	{

		private String _columnDelim;
		private String _lineDelim;

		public String getDesc()
		{
			return 
				"Show contents of TSV Upload table in console\n" + 
				"Use to debug/analyze problems with TSV uploader\n" + 
				"Arguments are username, widgetname, and recordid in TSV table\n" + 
				"TODO: update/complete this";

		}

		public void runOp()
		{
			WidgetUser user = WidgetUser.lookup(_argMap.getStr("username"));
			WidgetItem dbitem = new WidgetItem(user, _argMap.getStr("widgetname"));
			int recordid = _argMap.getInt("recordid");


			ArgMap dbrecord = QueryCollector.buildAndRun(Util.sprintf("SELECT * FROM %s WHERE id = %d", GDOC_TSV_TABLE, recordid), dbitem)
												.getSingleArgMap();


			setupOptInfo(dbrecord);
			showHeaderInfo(dbrecord);
			showTableInfo(dbrecord);
		}

		private void showHeaderInfo(ArgMap dbrec)
		{


		}

		private void showTableInfo(ArgMap dbrec)
		{
			Util.massert(_lineDelim != null);

			String tabdata = dbrec.getStr("tab_separated_data");

			for(String onerow : tabdata.split("_lineDelim"))
			{
				String toprint = onerow.replaceAll(_columnDelim, "\t");
				Util.pf("%s\n", toprint);
			}
		}	

		private void setupOptInfo(ArgMap dbrec)
		{
			HashMap<String, String> opts = Util.cast(getJsonInfo(dbrec));
			_columnDelim = opts.getOrDefault("column_delim", "\t");
			_lineDelim = opts.getOrDefault("line_delim", "\n");
		}

		private static JSONObject getJsonInfo(ArgMap dbrec)
		{
			try {
				JSONParser parser = new JSONParser();
				String optstr = dbrec.getStr("options");
				return Util.cast(parser.parse(optstr));
			} catch (Exception ex) {
				throw new RuntimeException(ex);
			}
		}	
	}
} 
