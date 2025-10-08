package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 
import java.net.URLConnection;

import javax.servlet.*;
import javax.servlet.http.*;

import java.util.Base64;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.FileUtils;
import net.danburfoot.shared.CollUtil.*;
import net.danburfoot.shared.CoreDb.QueryCollector;

import io.webwidgets.core.CoreUtil.*;
import io.webwidgets.core.AuthLogic.*;
import io.webwidgets.core.PluginCentral.*;

public class BlobDataManager
{
	public static final String BLOB_CONVERT_COMPLETE = "b10bf00d";
	
	public static final String GET_BLOB_STORE_METHOD = "getBlobStoreUrl";
	
	public enum BlobInfoColumn
	{
		base64_blob_data,
		blob_file_name;
	}
	
	private static Set<String> _BLOB_COLUMN_SET = Util.map2set(Util.listify(BlobInfoColumn.values()), bc -> bc.toString());
	
	private static String _BLOB_BASE_DIR = null;

	public static String getBlobBaseDir()
	{
		if(_BLOB_BASE_DIR == null)
		{
			Optional<String> rawdata = GlobalIndex.getSystemSetting(SystemPropEnum.RAW_DATA_BASE_DIR);
			Util.massert(rawdata.isPresent(),
				"You must configure the %s system property to use the Blob Data Manager",
				SystemPropEnum.RAW_DATA_BASE_DIR);

			_BLOB_BASE_DIR = Util.varjoin(File.separator, rawdata.get(), "wwio", "blob");
		}


		return _BLOB_BASE_DIR;
	}

	
	static String getBlobFileName(int recordid)
	{
		String basic = (recordid+"").replaceAll("-", "");
		
		StringBuilder sb = new StringBuilder(basic);
		
		while(sb.length() < 10)
			{ sb.insert(0, "0"); }
		
		// Insert N/P depending on whether the original record was negative
		sb.insert(0, recordid < 0 ? "N" : "P");
		sb.insert(0, "blob__");
		return sb.toString();
		
		
		// This approach based on number formatting doesn't work because
		// the negative sign is included in the final padded length
		// int negrecord = recordid > 0 ? -recordid : recordid;
		// String result = String.format("blob__%010d", negrecord);
		// return result.replace("-", recordid >= 0 ? "P" : "N");
	}
	
	public static String getStandardBlobAddress(WidgetItem dbitem, String tablename, int recordid)
	{
		String blobfile = getBlobFileName(recordid);
		
		return String.format("/%s/%s/%s/%s", dbitem.theOwner, dbitem.theName, tablename, blobfile);
	}
	
	public static File getFullBlobLocalPath(String blobaddr)
	{
		return new File(getBlobBaseDir() + blobaddr);
	}
	
	static boolean isBlobStorageTable(Set<String> columnset)
	{
		int blobhits = Util.countPred(columnset, k -> _BLOB_COLUMN_SET.contains(k));
		
		Util.massert(blobhits == 0 || blobhits == BlobInfoColumn.values().length,
			"For handling blob data, you must use exactly %d blob columns: %s, found %s", 
			_BLOB_COLUMN_SET.size(), _BLOB_COLUMN_SET, columnset);
		
		return blobhits > 0;
	}
	
	public static void optProcessBlobInput(LiteTableInfo LTI, Map<String,  Object> payload)
	{
		if(!LTI.isBlobStoreTable())
			{ return; }
		
		// In this situation, we're just doing edits on the shell record
		String base64 = stripPrefix(Util.cast(payload.get(BlobInfoColumn.base64_blob_data.toString())));
		if(base64 == null || "".equals(base64) || base64.startsWith(BLOB_CONVERT_COMPLETE))
			{ return; }
		
		int recordid = Integer.valueOf(payload.get("id").toString());
		String blobaddr = getStandardBlobAddress(LTI.dbTabPair._1, LTI.dbTabPair._2, recordid);
		byte[] filedata = Base64.getDecoder().decode(base64);
		
		try {
			File fullpath = getFullBlobLocalPath(blobaddr);
			FileUtils.getWriterUtil().setFile(fullpath).writeBytes(filedata);
			
			PluginCentral.getStorageTool().uploadLocalPath(fullpath);
			
		} catch (IOException ioex) {
			throw new RuntimeException(ioex);
		}
		
		payload.put(BlobInfoColumn.base64_blob_data.toString(), getBlobStatusCode(filedata.length));
	}
	
	static void optProcessDelete(LiteTableInfo LTI, LinkedHashMap<String, Object> payload)
	{
		if(!LTI.isBlobStoreTable())
			{ return; }
		
		int recordid = Integer.valueOf(payload.get("id").toString());
		String blobaddr = getStandardBlobAddress(LTI.dbTabPair._1, LTI.dbTabPair._2, recordid);
		
		try {
			File localfile = getFullBlobLocalPath(blobaddr);

			if(localfile.exists())
				{ localfile.delete(); }

			PluginCentral.getStorageTool().deleteFromLocalPath(localfile);
			
		} catch (IOException ioex) {
			throw new RuntimeException(ioex);
		}
	}
	
	public static String getBlobStatusCode(long flen)
	{
		return Util.sprintf("%s::%d", BLOB_CONVERT_COMPLETE, flen);
	}
	
	public static String stripPrefix(String base64)
	{
		// First digits are data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAASABIAAD/4QBMRXhpZgAATU0AKgAAAAgAAgESA
		
		String probe = base64.length() < 100 ? base64 : base64.substring(0, 100);
		
		int commapos = probe.indexOf(",");
		
		return commapos > 0 
					? base64.substring(commapos+1)
					: base64;
		
	}

	public static Optional<String> getFileExtension(String bfilename) 
	{
		String[] tokens = bfilename.split(".");
		return tokens.length == 2 ? Optional.of(tokens[1]) : Optional.empty();
	}

	public static class BlobStorageServlet extends HttpServlet {
		
		public BlobStorageServlet() {}
		
		protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
			
			ArgMap reqparam = WebUtil.getArgMap(request);
			boolean download = reqparam.getBit("download", true);
			
			WidgetItem dataitem = lookupDataItem(reqparam);


			AuthChecker checker = AuthChecker.build().userFromRequest(request).directDbWidget(dataitem);
			Util.massert(checker.allowRead(),
				"User does not have read permission for Widget %s", dataitem);
			
			String tablename = reqparam.getStr("tablename");
			int recordid = reqparam.getInt("id");


			{
				LiteTableInfo LTI = LiteTableInfo.buildAndSetup(dataitem, tablename);
				if(LTI.hasGranularPerm())
				{
					var accessor = AuthLogic.getLoggedInUser(request);
					var optperm = GranularPerm.singleRecordPermCheck(dataitem, tablename, recordid, accessor);

					if(!optperm.isPresent() || optperm.get().ordinal() < PermLevel.read.ordinal())
					{
						throw new RuntimeException(
							"This widget is configured for granular permissions, and user lacks access" + accessor);
					}
				}
			}



			ArgMap blobrecord = getBlobRecord(dataitem, tablename, recordid);
			String blobaddr = getStandardBlobAddress(dataitem, tablename, recordid);
			
			String filename = blobrecord.getStr(BlobInfoColumn.blob_file_name.toString());
			{
				String mimetype = filename == null ? null : URLConnection.guessContentTypeFromName(filename.trim());
				Util.pf("Setting mimetype %s for filename %s\n", mimetype, filename);
				response.setContentType(mimetype == null ? "application/octet-stream" : mimetype);
			}
			
			// Okay, if you choose download=false, it will try to open it in browser
			// In that case filename is ignored
			response.setHeader("Content-Disposition",
				String.format("%s; filename=\"%s\"", download ? "attachment" : "inline", filename));
						
			File blobfile = getFullBlobLocalPath(blobaddr);
			
			if(!blobfile.exists())
			{
				IBlobStorage blobtool = PluginCentral.getStorageTool();
				Util.massert(blobtool.blobPathExists(blobfile),
						"Widget blob sync error: full blob path %s does not exist in blob storage", blobfile);

				blobtool.downloadToLocalPath(blobfile);
			}


			java.nio.file.Files.copy(blobfile.toPath(), response.getOutputStream());
			response.getOutputStream().flush();
		}
		
		private static WidgetItem lookupDataItem(ArgMap amap)
		{
			WidgetUser owner = WidgetUser.valueOf(amap.getStr("username"));
			return new WidgetItem(owner, amap.getStr("widgetname"));
		}
		
		private static ArgMap getBlobRecord(WidgetItem dbitem, String tablename, int recordid)
		{
			// Prevent SQL injection in tablename argument, comes from goddam query string
			Util.massert(dbitem.getDbTableNameSet().contains(tablename),
				"Invalid table name %s for Widget %s", tablename, dbitem);
			
			String query = String.format("SELECT * FROM %s WHERE id = %d", tablename, recordid);
			QueryCollector qcol = QueryCollector.buildAndRun(query, dbitem);
			
			Util.massert(qcol.getNumRec() > 0, "No record found for Widget %s, table %s, ID %d", dbitem, tablename, recordid);
			return qcol.getSingleArgMap();
		}
	}
}
