
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.util.zip.*;

import javax.servlet.*;
import javax.servlet.http.*;
import javax.servlet.annotation.MultipartConfig;


import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.FileUtils;

import io.webwidgets.core.WidgetOrg.*;


public class ActionJackson extends HttpServlet
{	
	public static final String SERVLET_PART_SAVE_DIR = "/opt/rawdata/servlet";
	
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
			String username = innmap.getStr("username", "");
			String acchash = innmap.getStr("accesshash", "");
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
	
	// TODO: what do all these numbers mean? 
	@MultipartConfig(
		fileSizeThreshold=10_000_000,
		location=SERVLET_PART_SAVE_DIR,
		maxFileSize=10_000_000,
		maxRequestSize=10_000_000
	)
	public static class Push2Me extends HttpServlet implements WidgetServlet
	{
		
		protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {

			ArgMap innmap = WebUtil.getArgMap(request);		
			
			if(!checkSecureRespond(request, response))
				{ return; }

			if(!checkAccessRespond(response, innmap))
				{ return; }
			
			
			WidgetUser wuser = WidgetUser.valueOf(innmap.getStr("username"));
			String widgetname = innmap.getStr("widget");
			// WidgetItem witem = new WidgetItem(wuser, widgetname);
			
			int mc = 0;			
			String s = "";
			
			// Enumeration<String> headers = request.getHeaderNames();
			// while(headers.hasMoreElements()) {
				// s += Util.sprintf("%s\n", headers.nextElement());	
			// }
						
			// s += Util.sprintf("Parts are %s\n", request.getParts());
			
			// s += Util.sprintf("INNMAP : %s\n", innmap);
			
			UploadFileType filetype = UploadFileType.valueOf(innmap.getStr("filetype"));						
			List<Part> payload = Util.filter2list(request.getParts(), p -> p.getName().equals("payload"));
			Util.massert(payload.size() == 1, 
				"Expected exactly 1 payload file, got %d", payload.size());

			CodeLocator codeloc = new CodeLocator(wuser, widgetname, filetype);
			
			{
				File codefile = codeloc.getCodeFile();
				if(codefile.exists())
					{ codefile.delete(); }
				
				payload.get(0).write(codeloc.getCodeName());
				// s += Util.sprintf("Wrote upload file to path %s\n", codeloc.getCodePath());
			}
			
			if(filetype.isZip())
			{
				// s += "Extracting code for widget " + witem + "\n";
				
				CodeExtractor codex = codeloc.getExtractor();	
				codex.cleanOldCode();
				codex.extractCode(codeloc);
				codex.optAugmentAuthHeader();

				// Gotcha, the CK maps must CONTAIN the tweaks from the auth header logic,
				// so this statement must run AFTER previous one
				codex.buildNewCkMap();
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
				
				// Now rebuild the JS code.
				List<String> result = createCode4Widget(witem);
				for(String r : result)
					{ s += r; }
			}
						
			response.getOutputStream().write(s.getBytes());
			response.getOutputStream().close();
		}
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
		
		// Path to T/F recursive or not
		abstract Map<String, Boolean> getCleanDirMap();

		abstract File getBaseDirectory();
		
		CodeExtractor()
		{
		}		
		
		// Delete previous files in this directory
		int cleanOldCode()
		{
			int totalkill = 0;
			Map<String, Boolean> cleanmap = getCleanDirMap();
			
			for(String p : cleanmap.keySet())
			{
				File pdir = new File(p);
				Util.massert(pdir.exists(), "Directory %s does not exist, leave it out of the map", pdir);
				Util.massert(pdir.isDirectory(), "Not a directory: %s", pdir);
				
				boolean isrec = cleanmap.get(p);
				LinkedList<String> pathlist = Util.linkedlist();
				recPopPathList(pathlist, pdir, isrec);
				
				Collections.sort(pathlist);
				totalkill += pathlist.size();
				
				while(!pathlist.isEmpty())
				{
					File killme = new File(pathlist.pollLast());
					if(java.nio.file.Files.isSymbolicLink(killme.toPath()))
					{
						logpf("Skipping symbolic link file %s\n", killme);
						continue;
					}
					
					long cksum = killme.isDirectory() ? -1L : CoreUtil.getFileCkSum(killme);
					_oldCkMap.put(killme.getAbsolutePath(), cksum);

					// logpf("Deleted old file %s\n", killme);

					killme.delete();
				}
			}
			
			return totalkill;
		}
		
		private void buildNewCkMap()
		{
			File basedir = getBaseDirectory();

			for(File kid : basedir.listFiles())
			{
				if(kid.isDirectory())
					{ continue; }

				long cksum = CoreUtil.getFileCkSum(kid);
				_newCkMap.put(kid.getAbsolutePath(), cksum);
			}
		}

		protected boolean prependAuthTag()
		{
			return false;	
		}				
		
		// Scan all the JSP files in the output directory. 
		// If they do not include the AuthHeader tag, swap it in as the FIRST line of the line.
		private void optAugmentAuthHeader()
		{
			if(!prependAuthTag())
				{ return; }
				
			File basedir = getBaseDirectory();
			Util.massert(basedir.exists() && basedir.isDirectory(),
				"Problem with base directory %s", basedir);
			
			for(File kid : basedir.listFiles())
			{
				if(!kid.getName().endsWith(".jsp"))
					{ continue; }
				
				boolean foundtag = false;
				List<String> srclist = FileUtils.getReaderUtil().setTrim(false).setFile(kid).readLineListE();
				
				for(int i : Util.range(20))
				{
					if(i >= srclist.size())
						{ continue; }
					
					foundtag |= srclist.get(i).contains("AuthInclude.jsp_inc");
				}
				
				if(!foundtag)
				{
					LinkedList<String> newlist = new LinkedList<>(srclist);
					newlist.addFirst("<%@include file=\"../../admin/AuthInclude.jsp_inc\" %>");
					FileUtils.getWriterUtil().setFile(kid).writeLineListE(newlist);
					// _logList.add(Util.sprintf("Prepended AuthInclude tag to Widget file %s\n", kid.getName()));
				} else {
					String mssg = Util.sprintf("File %s contains AuthInclude tag; this is no longer necesary, you may remove\n", kid.getName());	
					_logList.add(mssg);
				}
			}
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
					logpf("Created new file %s\n", pathkey);
					continue;
				}

				if(newck == null)
				{
					logpf("Removed file %s\n", pathkey);
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

			logpf("Uploaded %d files, %d previous, %d unchanged\n", _newCkMap.size(), _oldCkMap.size(), samecount);

		}
		
		private void recPopPathList(List<String> paths, File dir, boolean recursive)
		{
			Util.massert(dir.isDirectory(), "Not a directory");
			
			for(File kid : dir.listFiles())
			{
				if(kid.getAbsolutePath().indexOf("WEB-INF") > -1)
				{
					logpf("Skipping WEB-INF dir %s\n", kid);
					continue;					
				}
				
				if(java.nio.file.Files.isSymbolicLink(kid.toPath()))
				{
					logpf("Skipping symbolic link file %s\n", kid);
					continue;
				}				
				
				
				if(!kid.isDirectory())
				{
					paths.add(kid.toString());
					continue;
				}
				
				if(kid.isDirectory() && recursive)
				{  
					paths.add(kid.toString());
					recPopPathList(paths, kid, true); 
				}
			}
		}
		
		List<String> getLogList()
		{
			return _logList;	
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
				Enumeration<? extends ZipEntry> zipen = myfile.entries();
				
				while(zipen.hasMoreElements()) {
					ZipEntry zent = zipen.nextElement();
					// logpf("Found entry %s\n", zent.getName());
					
					String zname = zent.getName();
					String kidpath = Util.sprintf("%s/%s", basedir.toString(), zname);
					
					if(zname.endsWith("/"))
					{
						File subdir = new File(kidpath);
						logpf("Creating directory %s\n", subdir);
						subdir.mkdir();
						continue;
					}
					
					File kidfile = new File(kidpath);
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
			String specdir = getSpecialDir();
			
			return specdir != null 
				? new File(specdir) 
				: _myItem.getWidgetBaseDir();
		}
		
		@Override
		protected boolean prependAuthTag()
		{
			if(!_myItem.theOwner.isAdmin())
				{ return true; }
		
			return !getSpecialRemapDir().containsKey(_myItem.theName);
		}
		
		// Special mappings from admin directories to other locations on site
		// This allows admins to use uploader tech to send data directly to 
		// given section of site.
		private String getSpecialDir()
		{
			if(!_myItem.theOwner.isAdmin())
				{ return null; }
			
			return getSpecialRemapDir().get(_myItem.theName);
		}
		

		
		Map<String, Boolean> getCleanDirMap()
		{	
			Map<String, Boolean> cdmap = Util.treemap();
			// recursive=true
			cdmap.put(getBaseDirectory().toString(), true);			
			return cdmap;
		}
	}	
	
	
	// Extract code that is NOT attached to a widget
	static class BaseExtractor extends CodeExtractor
	{		
		final WidgetUser _theUser;
		
		BaseExtractor(WidgetUser user)
		{
			Util.massert(user != null, "Null user!");
			_theUser = user;
		}
		
		@Override
		File getBaseDirectory()
		{
			return _theUser.getUserBaseDir();	
		}
		
		Map<String, Boolean> getCleanDirMap()
		{	
			// TODO: add the standard reserved keyword maps here.
			Map<String, Boolean> cdmap = Util.treemap();
			// recursive=false
			cdmap.put(getBaseDirectory().toString(), false);
			return cdmap;
		}
	}	
	
	
	public static List<String> createCode4Widget(WidgetItem witem)
	{
		List<String> loglist = Util.vector();
		File autogendir = WebUtil.getAutoGenJsDir(witem);
		// Util.pf("Auto gen dir is %s\n", autogendir);
		
		if(!autogendir.exists())
		{
			autogendir.mkdir();
			// Util.pf("Creating auto gen dir\n", autogendir);
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

		if(CoreUtil.RESERVED_WIDGET_NAMES.contains(widgetname))
		{
			String mssg = String.format("The Widget %s is a special system widget, it cannot be uploaded", widgetname);
			throw new RuntimeException(mssg);
		}
	}

	public static class Pull2You extends HttpServlet implements WidgetServlet {
		
		protected void doGet( HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
			
			ArgMap innmap = WebUtil.getArgMap(request);		
			
			if(!checkSecureRespond(request, response))
				{ return; }

			if(!checkAccessRespond(response, innmap))
				{ return; }	
			
			WidgetUser wuser = WidgetUser.valueOf(innmap.getStr("username"));
			String widgetname = innmap.getStr("widget");		
			WidgetItem witem = new WidgetItem(wuser, widgetname);
			
			File dbfile = witem.getLocalDbFile();
			Util.massert(dbfile.exists(),
				"DB file %s does not exist, are you sure no typo?", dbfile);
			
			// This should send the file to browser
			FileUtils.in2out(new FileInputStream(dbfile), response.getOutputStream());
			response.getOutputStream().close();

		}
	}

	public static class ConvertGrabExcel extends HttpServlet implements WidgetServlet
	{
		
		protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {

			ArgMap innmap = WebUtil.getArgMap(request);		
			
			if(!checkSecureRespond(request, response))
				{ return; }

			// Okay, currently you can only download XL for your own widgets
			Optional<WidgetUser> optuser = AuthLogic.getLoggedInUser(request);
			if(!optuser.isPresent())
			{
				String mssg = "Access denied!\n";
				response.getOutputStream().write(mssg.getBytes());
				response.getOutputStream().close();
				return;
			}
		
			WidgetUser wuser = optuser.get();
			String widgetname = innmap.getStr("widgetname");

			WidgetItem witem = new WidgetItem(wuser, widgetname);
			File result = CoreUtil.convert2Excel(witem);			

			FileUtils.in2out(new FileInputStream(result), response.getOutputStream());
		}
	}
}

