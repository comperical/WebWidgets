
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 

import java.time.LocalDate;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.FileUtils;

import io.webwidgets.core.*;
import io.webwidgets.core.WidgetOrg.*;
import io.webwidgets.core.CoreUtil.*;


public class JsDocExtractor
{ 
	private JsDocExtractor() {}
	
	public static List<File> getJsFileList(File directory)
	{
		Util.massert(directory.exists() && directory.isDirectory(),
			"Problem with directory %s", directory);
		
		return Util.filter2list(directory.listFiles(), f -> f.getName().endsWith(".js"));
	}
	
	public static Map<String, List<String>> getDocMap4File(File jsfile)
	{
		Util.massert(jsfile.getName().endsWith(".js"),
			"Expected a .js file, got %s", jsfile);
		
		List<String> sourcedata = FileUtils
						.getReaderUtil() 
						.setTrim(false)
						.setFile(jsfile)
						.readLineListE();
		
		Util.pf("Read %d lines from file %s\n", sourcedata.size(), jsfile);
		Map<String, List<String>> docmap = Util.linkedhashmap();
		
		// Okay, put all the private methods AFTER all the public methods.
		for(boolean wantpriv : Util.listify(false, true))
		{
			LinkedList<String> lines = new LinkedList<String>(sourcedata);
			while(!lines.isEmpty())
			{
				List<String> peelblock = peelCommentBlock(lines);
				
				if(lines.isEmpty())
					{ break; }
				
				if(peelblock.isEmpty())
				{ 
					lines.poll(); 
					continue;
				}
				
				String next = lines.poll().trim();
				boolean ispriv = isPrivateMarker(next);
				
				if(wantpriv == ispriv)
					{ docmap.put(next, peelblock); }
			}			
		}
		
		return docmap;		
	}
	
	private static boolean isPrivateMarker(String funcline)
	{
		List<String> tokens = Util.listify(funcline.split(" "));
		return Util.countPred(tokens, tok -> tok.startsWith("__")) > 0;
	}
	
	// Okay, to include in autodoc, block must START with // without no whitespace
	private static List<String> peelCommentBlock(LinkedList<String> lines)
	{
		Util.massert(!lines.isEmpty());
		List<String> result = Util.vector();
		
		while(!lines.isEmpty() && lines.peek().startsWith("//"))
		{
			result.add(lines.poll().trim().substring(2));
		}
		
		return result;
	}

} 

