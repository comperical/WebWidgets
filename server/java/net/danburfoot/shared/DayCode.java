

package net.danburfoot.shared;

import java.util.*;
import java.io.*;
import java.net.*;
import java.util.regex.*;

import java.text.SimpleDateFormat;

import net.danburfoot.shared.Util.*;

public class DayCode implements Comparable<DayCode>
{
	private static TreeMap<String, DayCode> _DAY_CODE_MAP;
	
	private static long OCTOBER_THIRD_2013 = 1380847199792L;
	
	public static final String DAY_CODE_REG_EXP = "(?<year>\\d{4})-(?<month>\\d{2})-(?<day>\\d{2})";
	
	private String _strForm;
	
	private DayCode _prevDay;
	private DayCode _nextDay;
	
	public static DayCode lookup(String s)
	{
		DayCode dcode = getCodeMap().get(s);
		
		Util.massert(dcode != null, "Invalid daycode string %s", s);
		
		return dcode;
	}
	
	public static DayCode lookup(int year, int month, int day)
	{
		String isostr = Util.sprintf("%d-%s-%s",
			year, StringUtil.padLeadingZeros(month+"", 2), StringUtil.padLeadingZeros(day+"", 2));
		
		return lookup(isostr);
		
	}	
	
	public static List<DayCode> findInList(List<String> linelist, boolean require)
	{
		List<DayCode> mylist = Util.vector();
		
		Pattern dcpatt = Pattern.compile(DAY_CODE_REG_EXP);
		
		for(String oneline : linelist)
		{
			Matcher m = dcpatt.matcher(oneline);
			
			boolean didfind = m.find();
			
			if(!didfind)
			{
				Util.massert(!require, "Failed to find DayCode pattern in record %s", oneline);
				continue; 
			}
			
			mylist.add(lookup(m.group()));
		}
		
		return mylist;
	}
	
	
	public static DayCode valueOf(String s)
	{
		return lookup(s);
	}
	
	public static boolean haveDayCode(String s)
	{
		return getCodeMap().containsKey(s);	
	}
	
	public static DayCode getToday()
	{
		return lookup(TimeUtil.dayCodeNow());	
	}
	
	private DayCode(String dcstr)
	{
		_strForm = dcstr;
		
		int dy = getYear();
		int dm = getMonth();
		int dd = getDay();
		
		Util.massert(1 <= dm && dm <= 12);
		Util.massert(1 <= dd && dd <= 31);
		Util.massert(2000 <= dy && dy <= 2050);
	}
	
	
	public DayCode dayAfter()
	{
		return _nextDay;
	}
	
	public DayCode nDaysAfter(int n)
	{
		DayCode curday = this;
		
		for(int i : Util.range(n))
			{ curday = curday.dayAfter(); }
		
		return curday; 
	}
	
	public DayCode dayBefore()
	{
		return _prevDay;	
	}
	
	public DayCode nDaysBefore(int n)
	{
		DayCode curday = this;
		
		for(int i : Util.range(n))
			{ curday = curday.dayBefore(); }
		
		return curday; 
	}
	
	public static int daysBetween(DayCode a, DayCode b)
	{
		boolean a_early = a.compareTo(b) < 0;
		
		DayCode early = (a_early ? a : b);
		DayCode latly = (a_early ? b : a);
		
		for(int n : Util.range(1000))
		{
			if(early.nDaysAfter(n).equals(latly))
				{ return n; }
		}
		
		Util.massert(false, 
			"This method can only handle differences up to 1000 days, found %s %s", a, b);
		
		return -1;
	}
	
	public static List<DayCode> getDayRange(DayCode start, int ndays)
	{
		List<DayCode> daylist = Util.vector();
		DayCode curday = start;
		
		for(int i : Util.range(ndays))
		{
			daylist.add(curday);
			curday = curday.dayAfter();
		}
		
		return daylist;
	}
	
	public static List<DayCode> getDayRange(DayCode start, DayCode end)
	{
		Util.massert(start.compareTo(end) < 0,
			"Must have start %s before end %s", start, end);
		
		List<DayCode> daylist = Util.vector();
		
		for(int i = 0; i < 10000; i++)
		{
			daylist.add(start);
			
			if(start.equals(end))
				{ return daylist; }
			
			start = start.dayAfter();
		}
		
		throw new RuntimeException("error");
	}	
	
	
	
	public static DayCode getMinDay()
	{
		return _DAY_CODE_MAP.firstEntry().getValue();	
	}
	
	public static DayCode getMaxDay()
	{
		return _DAY_CODE_MAP.lastEntry().getValue();	
	}
	
	private static void join(DayCode a, DayCode b)
	{
		a._nextDay = b;
		b._prevDay = a;
	}
	
	public Calendar getCalendar()
	{
		SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");
		return TimeUtil.tstamp2Cal(_strForm, sdf);
	}
	
	// 
	public static synchronized SortedMap<String, DayCode> getCodeMap()
	{
		if(_DAY_CODE_MAP == null)
		{
			_DAY_CODE_MAP = Util.treemap();
			
			SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");
			
			Calendar cal = new GregorianCalendar();
			
			DayCode prvday = null;
			
			long milli = OCTOBER_THIRD_2013;
			for(int i : Util.range(4000))
			{ 
				milli -= TimeUtil.DAY_IN_MILLIS;
			}
			
			
			for(int i : Util.range(8000))
			{
				cal.setTimeInMillis(milli);
				
				String dcstr = sdf.format(cal.getTime());
				DayCode newday = new DayCode(dcstr);
				
				Util.putNoDup(_DAY_CODE_MAP, newday.toString(), newday);
				
				if(prvday != null)
					{ join(prvday, newday); }
				
				prvday = newday;
				
				milli += TimeUtil.DAY_IN_MILLIS;
			}
		}
		
		return Collections.unmodifiableSortedMap(_DAY_CODE_MAP);
	}
	
	public int compareTo(DayCode that)
	{
		return this._strForm.compareTo(that._strForm);	
	}
	
	public String toString()
	{
		return _strForm;
	}
	
	public int getYear()
	{
		return getIntField(0);	
	}
	
	public int getMonth()
	{
		return getIntField(1);	
	}
	
	public int getDay()
	{
		return getIntField(2);	
	}
	
	private int getIntField(int x)
	{
		return Integer.valueOf(_strForm.split("-")[x]);
	}
}
