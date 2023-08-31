
package net.danburfoot.shared; 

import java.text.*; 
import java.util.*; 
import java.io.*; 

import org.w3c.dom.*;

import net.danburfoot.shared.Util.*;
import net.danburfoot.shared.CollUtil.*;
import net.danburfoot.shared.RunnableTech.*;

public class RunnableTech
{ 		

	public static abstract class ArgMapRunnable
	{
		protected ArgMap _argMap = new ArgMap();
		
		public void initFromArgMap(ArgMap amap)
		{
			_argMap = amap;	
		}
		
		public abstract void runOp() throws Exception;
	
		public void runOpE() 
		{
			try { runOp(); }
			catch (Exception ex) {
				throw new RuntimeException(ex);
			}
		}
		
		// Tests, especially UTests, can override this to 
		// specify ordering of the test:  lower numbers get run earlier
		// in the test sequence.
		public int getTestOrderHint()
		{
			return 0;	
		}
	}
	
	public static interface HasDescription
	{
		public String getDesc(); 
	}	
	
	public static abstract class DescRunnable extends ArgMapRunnable implements HasDescription {} 
	
	// Tagger interface for jobs that run in the crontab
	public interface CrontabRunnable extends HasDescription {};


	public static abstract class LogSwapRunnable extends ArgMapRunnable
	{
		protected List<String> _logResult;

		public void mypf(String formstr, Object... vargs)
		{
			String result = Util.sprintf(formstr, vargs);
			if(_logResult == null)
			{
				Util.pf("%s", result);
				return;
			}

			_logResult.add(result);
		}

		public void setLogResult(List<String> send2me)
		{
			Util.massert(send2me != null, "You must supply a non-null input list!!");
			_logResult = send2me;
		}
	}


	// Tagger interface, for showing only most important ArgMaps
	public interface TopLevel extends HasDescription { } ;
	
	public interface ArgListInfo
	{
		public int numRequired(); 
		
		// This is ORDERED because of numRequired
		// First N elements are required, where N=numRequired.
		public LinkedHashMap<String, Class> getArgInfo();
	}
	
	// Tag interface for things that run in EC2 startup scripts
	public interface StartupRunnable extends HasDescription { } ;
 	
	public interface HasDependencyList 
	{	
		// Return list of classes this RegTest depends on.
		public abstract List<Class> getDependencyList();
	}
	
	// ArgMapRunnable Classes that implement this must call 
	// argmap.isLogMode(), and then return after doing so.
	public interface LogModeRunnable {}
} 
