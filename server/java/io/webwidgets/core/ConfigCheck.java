
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 
import java.nio.file.*;

import java.time.LocalDate;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.FileUtils;


public class ConfigCheck
{ 
	private static final String BASE_INCLUDE_LINE = "<%@include file=\"../admin/AuthInclude.jsp_inc\" %>";

	private static final String AUTH_INCLUDE_LINE = "<%@include file=\"../../admin/AuthInclude.jsp_inc\" %>";
	
	private static final String ASST_INCLUDE_LINE = "<%@include file=\"../../admin/AssetInclude.jsp_inc\" %>";

	private static final String DATA_SERVER_LINE = "<%= DataServer.basicInclude(request)  %>";
	
	public static void checkServerPageConfig(File serverpage)
	{
		List<String> pagelines = FileUtils.getReaderUtil()
							.setFile(serverpage)
							.readLineListE();
		
		checkServerPageConfig(pagelines);
		
	}
	
	public static void checkServerPageConfig(List<String> pagelines)
	{
		// Util.pf("Analyzing page with %d lines\n", pagelines.size());
		for(int lineidx : Util.range(pagelines))
		{
			String line = pagelines.get(lineidx);
			
			boolean openntag = line.contains("<%");
			boolean closetag = line.contains("%>");
			
			// Util.massert(Util.setify(openntag, closetag).size() == 1,
			//	"For line %d::%s, got open=%b, close=%b", 
			//	lineidx+1, line, openntag, closetag);
			
			
			if(line.contains("<%@include"))
			{
				boolean isauth = normalizeCheck(line, AUTH_INCLUDE_LINE);
				boolean isasst = normalizeCheck(line, ASST_INCLUDE_LINE);
				boolean isbase = normalizeCheck(line, BASE_INCLUDE_LINE);
				
				Util.massert(isauth || isasst || isbase,
					"Invalid include line %s", line);				
				
			}
			
			
			// Warning, this could be a security risk.
			// Need to allow a bit of flexibility here, because there are different DataServer options
			// But don't want to allow people to run arbitrary code.
			if(line.startsWith("<%="))
			{
				boolean isbasic = normalizeCheck(line, DATA_SERVER_LINE);
				// Util.massert(isbasic, "Invalid script starting line: %s", line);
				continue;
			}
		
		}
	}
	
	private static boolean normalizeCheck(String a, String b)
	{
		String ap = a.trim().toLowerCase().replaceAll(" ", "");
		String bp = b.trim().toLowerCase().replaceAll(" ", "");
		
		return ap.equals(bp);
	}
} 

