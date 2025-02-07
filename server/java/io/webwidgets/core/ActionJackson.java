
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.util.zip.*;

import javax.servlet.*;
import javax.servlet.http.*;
import javax.servlet.annotation.MultipartConfig;

import java.util.regex.Matcher;
import java.util.regex.Pattern;


import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.FileUtils;
import net.danburfoot.shared.StringUtil;

import io.webwidgets.core.WidgetOrg.*;
import io.webwidgets.core.DataServer.*;
import io.webwidgets.core.WispFileLogic.*;


public class ActionJackson extends HttpServlet
{

	// TODO: need to make this location config-dependent!
	public static final String SERVLET_PART_SAVE_DIR = "/opt/rawdata/servlet";

	private static final String MAC_OS_DSTORE = ".DS_Store";

	// These are the varieties of Errors that the user can see when up/down-loading data from the server
	public enum LoadApiError
	{
		CodeFormatError,
		IncludeArgError,
		MailboxError,
		BlobStoreError,
		ReservedNameError,
		MissingWidgetError,
		NoSharedUserDataError,
		UploadSizeError;
	}

	public enum UploadFileType
	{
		basezip,
		widgetzip,
		sqlite;
		
		public boolean isZip()
		{
			return this.toString().endsWith("zip");
		}
		
		public String getExtension()
		{
			return isZip() ? "zip" : this.toString(); 
		}
	}
	
	interface WidgetServlet
	{
		default boolean checkAccess(ArgMap innmap)
		{
			String username = innmap.getStr(CoreUtil.USER_NAME_COOKIE, "");
			String acchash = innmap.getStr(CoreUtil.ACCESS_HASH_COOKIE, "");
			return AuthLogic.checkCredential(username, acchash);
		}
	
		default boolean okaySecure(HttpServletRequest req)
		{
			return req.isSecure();
		}
		
		default boolean checkAccessRespond(HttpServletResponse resp, ArgMap innmap) throws IOException
		{
			if(checkAccess(innmap))
				{ return true; }
			
			String mssg = "Access denied!\n";
			resp.getOutputStream().write(mssg.getBytes());
			resp.getOutputStream().close();
			return false;
		}
		
		default boolean checkSecureRespond(HttpServletRequest req, HttpServletResponse resp) throws IOException
		{
			if(okaySecure(req))
				{ return true; }
						
			String mssg = "This operation must use a secure connection!!\n";
			resp.getOutputStream().write(mssg.getBytes());
			resp.getOutputStream().close();
			return false;
		}
	}
	
	@MultipartConfig(
		fileSizeThreshold=10_000_000,
		location=SERVLET_PART_SAVE_DIR,
		maxFileSize=10_000_000,
		maxRequestSize=10_000_000
	)
	public static class Push2Me extends HttpServlet implements WidgetServlet
	{

		protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException 
		{
			try 
				{ doPostSub(request, response); }
			catch (LoaderException loadex) 
				{ sendErrorResponse(response, loadex); }
		}

		
		protected void doPostSub(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException, LoaderException 
		{

			ArgMap innmap = WebUtil.getArgMap(request);
			
			if(!checkSecureRespond(request, response))
				{ return; }

			if(!checkAccessRespond(response, innmap))
				{ return; }
			
			
			WidgetUser wuser = WidgetUser.valueOf(innmap.getStr("username"));
			String widgetname = innmap.getStr("widget");
			UploadFileType filetype = UploadFileType.valueOf(innmap.getStr("filetype"));

			Util.massert(widgetname.strip().toLowerCase().equals(widgetname),
				"Badly formatted widget name %s, should be no-whitespace, lowercase, uploader script should catch this...!", widgetname);


			if(wuser == WidgetUser.getSharedUser() && filetype == UploadFileType.sqlite)
			{
				String extra = "We do not allow upload of SHARED user data, for safety reasons, please run scripts to update data on server";
				throw new LoaderException(LoadApiError.NoSharedUserDataError, extra);
			}

			if(MailSystem.MAILBOX_WIDGET_NAME.equals(widgetname))
			{
				String extra = "You cannot upload the Widget mailbox DB, only download it. This is to prevent abuse of email system";
				throw new LoaderException(LoadApiError.MailboxError, extra);
			}

			if(!(new WidgetItem(wuser, widgetname)).dbFileExists())
			{
				// Some code-only Widget directories can be uploaded without creating the widget, notably "base"
				boolean auxokay = filetype.isZip() && CoreUtil.AUX_CODE_OKAY.contains(widgetname);

				// Special directories that are loading as-if they are admin widgets
				// boolean special = wuser.isAdmin() && getSpecialRemapDir().containsKey(widgetname);
				boolean special = PluginCentral.getGeneralPlugin().getUserUploadRemap(wuser).containsKey(widgetname);

				if(!(auxokay || special))
				{
					String extra = Util.sprintf("No widget %s found for user %s, you must create in Admin Console first", widgetname, wuser);
					throw new LoaderException(LoadApiError.MissingWidgetError, extra);
				}
			}


			int mc = 0;
			String s = "";
			CodeLocator codeloc = new CodeLocator(wuser, widgetname, filetype);
			
			{
				List<Part> payload = Util.filter2list(request.getParts(), p -> p.getName().equals("payload"));
				Util.massert(payload.size() == 1, 
					"Expected exactly 1 payload file, got %d", payload.size());

				File codefile = codeloc.getCodeFile();
				if(codefile.exists())
					{ codefile.delete(); }
				
				payload.get(0).write(codeloc.getCodeName());
			}
			
			if(filetype.isZip())
			{
				CodeExtractor codex = codeloc.getExtractor();
				if(!isCodeFormatExempt(wuser))
					{ codex.checkCodeFormat(codeloc); }

				// Snapshot of the directory before the code clean
				codex.buildCheckSumMap(false);

				codex.cleanOldCode();
				codex.extractCode(codeloc);

				// Snapshot of the directory before the code clean
				codex.buildCheckSumMap(true);
				codex.generateDiffLog();
				
				for(String log : codex.getLogList())
					{ s += log; }
			
			} else if(filetype == UploadFileType.sqlite) {
				
				checkDbUploadOkay(widgetname);

				WidgetItem witem = new WidgetItem(wuser, widgetname);
				
				s += "Saving DB file for widget " + witem + "\n";
				
				if(witem.getLocalDbFile().exists())
				{
					witem.getLocalDbFile().delete();
					s += Util.sprintf("Deleted old DB file %s\n", witem.getLocalDbFile());
				}
				
				// Now move the file.
				{
					File src = codeloc.getCodeFile();
					File dst = witem.getLocalDbFile();
					src.renameTo(dst);
					s += Util.sprintf("Copied upload file to location %s, size is %d\n", dst.toString(), dst.length());
				}

				// Rectify the Aux-Role table(s)
				{
					String message = GranularPerm.rectifyAuxRoleSetup(witem);
					s += message;
				}

				
				// Now rebuild the JS code.
				List<String> result = createCode4Widget(witem);
				for(String r : result)
					{ s += r; }
			}
						
			response.getOutputStream().write(s.getBytes());
			response.getOutputStream().close();

			// Cleanup is only necessary if the code file is still present; in the case of DB upload, it's moved
			codeloc.optCleanUp();
		}


		private boolean isCodeFormatExempt(WidgetUser user)
		{
			return user.isAdmin() || GlobalIndex.getCodeFormatExemptSet().contains(user);
		}
	}

	private static void sendErrorResponse(HttpServletResponse response, LoaderException loadex) throws IOException
	{
		String topmssg = Util.sprintf("Encountered error %s, additional details are:\n%s\n\n", loadex.theError, loadex.extraInfo);
		response.getOutputStream().write(topmssg.getBytes());
		response.getOutputStream().close();
	}
	
	static class CodeLocator
	{
		final WidgetUser _theUser;
		final String _widgetName;
		final UploadFileType _ufType;
		
		CodeLocator(WidgetUser wuser, String wname, UploadFileType uftype)
		{
			_theUser = wuser;
			_widgetName = wname;
			_ufType = uftype;
			
			{
				Set<Boolean> checkset = Util.setify(
					wname.equals("base"),
					uftype == UploadFileType.basezip
				);
				
				Util.massert(checkset.size() == 1,
					"Have widget name %s but file type %s", wname, uftype);
			}
		} 
		
		Optional<WidgetItem> getCodeTarget()
		{
			return _ufType == UploadFileType.basezip 
									? Optional.empty() 
									: Optional.of(new WidgetItem(_theUser, _widgetName));
		}

		void optCleanUp()
		{
			if(!getCodeFile().exists())
				{ return; }

			try { getCodeFile().delete(); }
			catch (Exception ex) { ex.printStackTrace(); }

		}

		File getCodeFile()
		{
			return new File(getCodePath());	
		}
		
		String getCodePath()
		{
			return SERVLET_PART_SAVE_DIR + "/" + getCodeName();
		}
		
		String getCodeName()
		{
			return Util.sprintf("%s__%s.%s",
					_theUser.toString(),
					_widgetName,
					_ufType.toString());
		}
		
		CodeExtractor getExtractor()
		{
			return _ufType == UploadFileType.basezip 
				? new BaseExtractor(_theUser) 
				: new WidgetExtractor(_theUser, _widgetName);
			
		}
	}
		
	abstract static class CodeExtractor 
	{
		protected List<String> _logList = Util.vector();

		// Map of path to checksum
		// rule: only send log info if the checksum has changed
		protected Map<String, Long> _oldCkMap = Util.treemap();
		protected Map<String, Long> _newCkMap = Util.treemap();
		
		protected void logpf(String formstr, Object... vargs)
		{
			_logList.add(Util.sprintf(formstr, vargs));	
		}

		abstract File getBaseDirectory();

		final boolean _allowSubDir;
		
		CodeExtractor(boolean okaysub)
		{
			_allowSubDir = okaysub;
		}



		
		// Delete previous files in this directory
		int cleanOldCode()
		{
			int totalkill = 0;

			File basedir = getBaseDirectory();
			Util.massert(basedir.exists(), "Base Directory %s does not exist");
			Util.massert(basedir.isDirectory(), "Not a directory: %s", basedir);
			
			LinkedList<String> pathlist = Util.linkedlist();
			recPopPathList(pathlist, basedir);

			// Collections.sort(pathlist);
			totalkill += pathlist.size();

			while(!pathlist.isEmpty())
			{
				File victim = new File(pathlist.pollLast());

				// TODO: it's not clear if this is the right thing to do. Do we allow symlinks...?
				// Maybe the key is to make widgets and/or users 100% symlinked or not symlinked at all
				// if(java.nio.file.Files.isSymbolicLink(victim.toPath()))

				victim.delete();
			}
			
			return totalkill;
		}

		private void recPopPathList(List<String> paths, File dir)
		{
			Util.massert(dir.isDirectory(), "Not a directory");

			for(File kid : dir.listFiles())
			{
				// Was previously worried about deleting WEB-INF, but if WEB-INF is in a upload-target directory,
				// you've got other problems
				// if(kid.getAbsolutePath().indexOf("WEB-INF") > -1)

				if(!kid.isDirectory())
				{
					paths.add(kid.toString());
					continue;
				}

				// Very important: if you're dealing with base, don't delete the sub-directories!!
				if(kid.isDirectory() && _allowSubDir)
				{
					paths.add(kid.toString());
					recPopPathList(paths, kid);
				}
			}
		}

		// Register the target file in the checksum snapshot
		private void registerCheckSum(File target, boolean isnew)
		{
			long cksum = target.isDirectory() ? -1L : CoreUtil.getFileCkSum(target);
			(isnew ? _newCkMap : _oldCkMap).put(target.getAbsolutePath(), cksum);
		}

		// Build a checksum snapshot, either old or new, depending on argument
		// We now support recursive directory structure for widget dirs,
		// So we need to log that
		private void buildCheckSumMap(boolean isnew)
		{
			buildCheckSumMap(getBaseDirectory(), isnew);
		}
		
		private void buildCheckSumMap(File subdir, boolean isnew)
		{
			for(File kid : subdir.listFiles())
			{
				// in recursive mode, we want to log directories and files
				// otherwise, just the files
				if(!kid.isDirectory())
				{
					registerCheckSum(kid, isnew);
					continue;
				}

				if(_allowSubDir)
				{
					registerCheckSum(kid, isnew);
					buildCheckSumMap(kid, isnew);
				}
			}
		}

		private static String getFsType(long otherck)
		{
			return otherck == -1L ? "directory" : "file";
		}

		private void generateDiffLog()
		{
			int samecount = 0;
			
			for(String pathkey : CoreUtil.combine2set(_newCkMap.keySet(), _oldCkMap.keySet()))
			{
				Long newck = _newCkMap.get(pathkey);
				Long oldck = _oldCkMap.get(pathkey);

				if(oldck == null)
				{
					logpf("Created new %s %s\n", getFsType(newck), pathkey);
					continue;
				}

				if(newck == null)
				{
					logpf("Removed %s %s\n", getFsType(oldck), pathkey);
					continue;
				}

				if(newck.longValue() != oldck.longValue())
				{
					// logpf("New CK is %d, olk CK is %s\n", newck.longValue(), oldck.longValue());
					logpf("Updated file %s\n", pathkey);
					continue;
				}

				samecount++;
			}

			logpf("Uploaded %d items, %d previous, %d unchanged\n", _newCkMap.size(), _oldCkMap.size(), samecount);
		}
		

		
		List<String> getLogList()
		{
			return _logList;
		}
		

		void checkCodeFormat(CodeLocator codeloc) throws LoaderException, IOException
		{
			ZipFile myfile = new ZipFile(codeloc.getCodeFile());
			Enumeration<? extends ZipEntry> zipen = myfile.entries();
			
			while(zipen.hasMoreElements()) {
				ZipEntry zent = zipen.nextElement();
				String zname = zent.getName();

				// TODO: as of late 2023, only dburfoot/admin should be uploading .jsp files
				// Formerly checked .jsp files here, but now only dburfoot/admin should be using .jsp files
				if(zname.endsWith(".wisp"))
				{
					List<String> srclist = FileUtils.getReaderUtil()
													.setStream(myfile.getInputStream(zent))
													.readLineListE();

					Optional<WidgetItem> optitem = codeloc.getCodeTarget();
					if(!optitem.isPresent())
					{
						String wrapmssg = ".wisp files cannot be included in base directories, use .html instead";
						throw new LoaderException(LoadApiError.CodeFormatError, wrapmssg);
					}

					WispFileFormat wff = new WispFileFormat(srclist, optitem.get());
					try {
						wff.checkCodeFormat();
					} catch (Exception ex) {
						String wrapmssg = Util.sprintf("Found error in WISP file format: %s", ex.getMessage());
						throw new LoaderException(LoadApiError.CodeFormatError, wrapmssg);
					}
				}
			}
		}

		// We are relying on the uploader to make sure there aren't 
		// any weird things in this package.
		int extractCode(CodeLocator codeloc)
		{
			File basedir = getBaseDirectory();
			Util.massert(basedir.exists(),
				"Base directory %s does not exist", basedir);
			
			try {
				Util.massert(codeloc.getCodeFile().toString().endsWith("zip"),
					"Expected to see a file ending in .zip, got %s", codeloc.getCodeFile());
				
				ZipFile myfile = new ZipFile(codeloc.getCodeFile());

				// Guard against Zip Slip
				{
					Optional<ZipEntry> badentry = CoreUtil.findZipSlipEntry(myfile);
					Util.massert(!badentry.isPresent(),
						"Zip Entry %s looks malicious, please obey rules of Zip Entry composition!!", badentry);
				}

				Enumeration<? extends ZipEntry> zipen = myfile.entries();
				
				while(zipen.hasMoreElements()) {
					ZipEntry zent = zipen.nextElement();
					
					// We will create parent directories only if they are needed by files
					if(zent.isDirectory())
						{ continue; }

					// Keep this DSTORE garbage off of my server
					String zname = zent.getName();
					if(zname.equals(MAC_OS_DSTORE))
						{ continue; }

					// ChatGPT says this works even on Windows
					File kidfile = new File(basedir, zname);

					// Create parent directory if required
					if(!kidfile.getParentFile().exists())
						{ kidfile.getParentFile().mkdirs(); }


					FileOutputStream fos = new FileOutputStream(kidfile);
					FileUtils.in2out(myfile.getInputStream(zent), fos);
					// logpf("Extracted file %s, size is %d\n", kidfile, kidfile.length());
				}
				
				return -1;
			} catch (Exception ex) {
				throw new RuntimeException(ex);
			}
		}
	}


	public static Map<String, String> getSpecialRemapDir()
	{
		Map<String, String> themap = Util.treemap();
		themap.put("admin", CoreUtil.WIDGET_ADMIN_DIR);
		themap.put("exadmin", CoreUtil.WIDGET_ADMIN_DIR.replaceAll("/admin", "/exadmin"));
		themap.put("docs", CoreUtil.WIDGET_ADMIN_DIR.replaceAll("/admin", "/docs"));
		return themap;
	}
	

	static class WidgetExtractor extends CodeExtractor
	{
		private final WidgetItem _myItem;

		WidgetExtractor(WidgetUser wuser, String wname)
		{
			this(new WidgetItem(wuser, wname));	
		}

		WidgetExtractor(WidgetItem witem)
		{
			super(true); // recursive=true

			_myItem = witem;
					
			if(!getBaseDirectory().exists())
			{
				if(_myItem.dbFileExists())
					{ getBaseDirectory().mkdir(); }
			}

			Util.massert(getBaseDirectory().exists(), "Widget does not exist %s", witem);
		}

		File getBaseDirectory()
		{
			var optspecial = getSpecialDir();
			return optspecial.map(s -> new File(s)).orElse(_myItem.getWidgetBaseDir());
		}
		
		// Special mappings from admin directories to other locations on site
		// This allows admins to use uploader tech to send data directly to 
		// given section of site.
		private Optional<String> getSpecialDir()
		{
			var remap = PluginCentral.getGeneralPlugin().getUserUploadRemap(_myItem.theOwner);
			return Optional.ofNullable(remap.get(_myItem.theName));
		}
	}
	
	
	// Extract code that is NOT attached to a widget
	static class BaseExtractor extends CodeExtractor
	{
		final WidgetUser _theUser;
		
		BaseExtractor(WidgetUser user)
		{
			super(false); // Non-recursive

			Util.massert(user != null, "Null user!");
			_theUser = user;
		}
		
		@Override
		File getBaseDirectory()
		{
			return _theUser.getUserBaseDir();
		}
	}
	
	
	// TODO: this doesn't really belong here, does it...?
	public static List<String> createCode4Widget(WidgetItem witem)
	{
		List<String> loglist = Util.vector();
		File autogendir = witem.getAutoGenJsDir();
		
		if(!autogendir.exists())
		{
			autogendir.mkdirs();
			loglist.add(Util.sprintf("Created directory %s\n", autogendir));
		}
		
		for(String dbname : witem.getDbTableNameSet())
		{
			LiteTableInfo tinfo = new LiteTableInfo(witem, dbname);
			tinfo.runSetupQuery();
			
			// dogenerate = true
			loglist.addAll(tinfo.maybeUpdateJsCode(true));
		}
		
		return loglist;
	}
	

	static void checkDbUploadOkay(String widgetname)
	{
		String checkname = widgetname.toLowerCase().trim();

		if(AdvancedUtil.RESERVED_WIDGET_NAMES.contains(widgetname))
		{
			String mssg = String.format("The Widget %s is a special system widget, it cannot be uploaded", widgetname);
			throw new RuntimeException(mssg);
		}
	}

	public static class Pull2You extends HttpServlet implements WidgetServlet {
		

		protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException 
		{
			try
				{ doGetSub(request, response); }
			catch (LoaderException loadex)
				{ sendErrorResponse(response, loadex); }
		}

		private void doGetSub( HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException, LoaderException {
			
			ArgMap innmap = WebUtil.getArgMap(request);
			
			if(!checkSecureRespond(request, response))
				{ return; }

			if(!checkAccessRespond(response, innmap))
				{ return; }
			
			WidgetUser wuser = WidgetUser.valueOf(innmap.getStr("username"));
			String widgetname = innmap.getStr("widget");
			WidgetItem witem = new WidgetItem(wuser, widgetname);
			
			if(!witem.dbFileExists())
			{
				String extra = Util.sprintf("No widget %s found for user %s, you must create in Admin Console first", widgetname, wuser);
				throw new LoaderException(LoadApiError.MissingWidgetError, extra);
			}
			
			// This should send the file to browser
			FileUtils.in2out(new FileInputStream(witem.getLocalDbFile()), response.getOutputStream());
			response.getOutputStream().close();

		}
	}




	public static class LoaderException extends Exception
	{
		public final LoadApiError theError;
		public final String extraInfo;


		LoaderException(LoadApiError error, String extra)
		{
			theError = error;
			extraInfo = extra;
		}


	}
}

