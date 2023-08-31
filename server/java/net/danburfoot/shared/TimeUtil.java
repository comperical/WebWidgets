

package net.danburfoot.shared;

import java.util.*;
import java.io.*;
import java.net.*;
import java.util.regex.*;

import java.text.*;

import net.danburfoot.shared.Util.*;

public class TimeUtil
{
	// If mod times differ by more than this amount, we assume it's
	// an actual change to the file and not just slackness in modtime calc
	public static final long MOD_TIME_SLACK_MILLI = 5000L;
	
	public static final long DAY_MILLI = (1000 * 60 * 60 * 24);
	
	public static final String PG_STANDARD_TS_TYPE = "character(19)";
	
	public enum TimeZoneEnum { 
		
		UTC, EST, PST;
		
		// PDT just doesn't work!!!
		/* PDT */
		
		TimeZone _tzone;
		
		TimeZoneEnum()
		{
			_tzone = TimeZone.getTimeZone(toString());
			
		}
		
		public TimeZone getTimeZone() { return _tzone; }
		
	};
	
	public static long DAY_IN_MILLIS = 1000*60*60*24;
	
	public enum TimeFormat
	{
		LongBasic("yyyy-MM-dd HH:mm:ss"),
		ShortBasic("yyyy-MM-dd"),
		Minimalist("MM-dd HH:mm");
		
		private String _strForm;
		
		TimeFormat(String s)
		{
			_strForm = s;	
		}
		
		public String format(Date d)
		{
			SimpleDateFormat sdf = new SimpleDateFormat(_strForm);
			return sdf.format(d);
		}
		
		public String format(Calendar cal)
		{
			return format(cal.getTime());	
		}
	}
	
	
	
	public static String longDayCodeNow()
	{
		return cal2LongDayCode(new GregorianCalendar());	
	}
	
	public static String dayCodeNow()
	{
		return cal2DayCode(new GregorianCalendar());	
	}	
	
	public static String timeStampNow()
	{
		return cal2TimeStamp(new GregorianCalendar());
	}
	
	public static int daysBetween(DayCode a, DayCode b)
	{
		Util.massert(a.compareTo(b) <= 0, 
			"By convention A must be before B, found A=%s B=%s", a, b);
		
		
		DayCode gimp = a;
		
		for(int gap = 0; gap < 10000; gap++)
		{
			if(gimp.equals(b))
				{ return gap; }
			
			gimp = gimp.dayAfter();
		}
		
		Util.massert(false, "Too manys days between A=%s and B=%s", a, b);
		return -1;
	}
	
	// db = 0 --> Today, T
	// db = 1 --> Yest, Y
	// db = 2 --> DayBeforeYest, YY
	// db = N --> NY
	public static String minDayInfoString(int daysbefore)
	{
		if(daysbefore == 0)
			{ return "T"; }
		
		if(daysbefore == 1)
			{ return "Y"; }
		
		if(daysbefore == 2)
			{ return "YY"; }
		
		return Util.sprintf("%dY", daysbefore);
		
	}
	
	
	
	public static String cal2DayCode(Calendar cal)
	{
		SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");
		return sdf.format(cal.getTime());
	}	
	
	// Note, DateFormat objects are not synchronized, recommendation is to use
	// separate objects for each operation.
	public static String cal2LongDayCode(Calendar cal)
	{
		SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
		return sdf.format(cal.getTime());
	}		
	
	public static String cal2TimeStamp(Calendar cal)
	{
		SimpleDateFormat sdf = new SimpleDateFormat("HH:mm:ss");
		return sdf.format(cal.getTime());		
	}	
	
	public static Calendar tstamp2Cal(String timestamp, SimpleDateFormat dform)
        {
                try {
                        synchronized (dform) 
                        {
                                Calendar cal = new GregorianCalendar();
                                cal.setTime(dform.parse(timestamp));
                                return cal;
                        }
                } catch(java.text.ParseException pex) {
                        throw new RuntimeException(pex);
                }                
        }	
        
        public static Date tstamp2Date(String timestamp, SimpleDateFormat dform)
        {
        	synchronized (dform) 
        	{
        		try { return dform.parse(timestamp); }
        		catch (Exception ex) { throw new RuntimeException(ex); }
        	}
        }

        public static String getShortDayOfWeek(DayCode dc)
        {
        	Calendar c = dc.getCalendar();
        	
        	SimpleDateFormat sdf = new SimpleDateFormat("EEE", Locale.US); 
        	String asweek = sdf.format(c.getTime());
        	
        	return asweek;
        }
        
        public static String getLongDayOfWeek(DayCode dc)
        {
        	Calendar c = dc.getCalendar();
        	
        	SimpleDateFormat sdf = new SimpleDateFormat("EEEEEEEEEEE", Locale.US); 
        	String asweek = sdf.format(c.getTime());
        	
        	return asweek;
        }
         
        public static TimeZone getUtcTimeZone()
        {
        	return TimeZone.getTimeZone("UTC");	
        	
        }
        
        public static class TimeSpan
        {
        	private final long _timeMilli;
        	
        	private TimeSpan(long a, long b)
        	{
        		_timeMilli = b - a;
        		
        		Util.massert(_timeMilli >= 0, "Found negative timespan, you must order arguments so B > A");
        	}
        	
        	public String getHourMinSec()
        	{
        		ExactMoment epochex = new ExactMoment(_timeMilli);
        		
        		return epochex.asBasicHrMnSc(TimeZoneEnum.UTC);
        	}
        }
        
        // Okay, fuck Java Date/Calendar bullshit
        public static class ExactMoment 
        {
        	private Long _exMilli;
        	
        	public GregorianCalendar getCal(TimeZone tz)
        	{
        		return null;	
        	}
        	
        	public ExactMoment()
        	{
        		_exMilli = System.currentTimeMillis();	
        	}
        	
        	
        	public ExactMoment(long milli)
        	{
        		_exMilli = milli;	
        	}
        	
        	public static ExactMoment build()
        	{
        		return new ExactMoment();	
        	}
        	
        	public static ExactMoment build(long mill)
        	{
        		return new ExactMoment(mill);	
        	}
        	
        	
        	public TimeSpan timeSince(ExactMoment prev)
        	{
        		return new TimeSpan(prev._exMilli, this._exMilli);
        	}
        	
        	public java.sql.Timestamp getSqlTimestamp()
        	{
        		return new java.sql.Timestamp(_exMilli);
        	}
        	
        	public Long getEpochTimeMilli()
        	{
        		return _exMilli;
           	}
        	
        	public String asLongBasicTs(TimeZoneEnum tze)
        	{
        		GregorianCalendar gcal = new GregorianCalendar();
        		gcal.setTimeInMillis(_exMilli);
        		
        		SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        		sdf.setTimeZone(tze.getTimeZone());
        		
        		return sdf.format(gcal.getTime());
        	}
        	
        	public String asBasicTs(TimeZoneEnum tze)
        	{
        		GregorianCalendar gcal = new GregorianCalendar();
        		gcal.setTimeInMillis(_exMilli);
        		
        		SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");
        		sdf.setTimeZone(tze.getTimeZone());
        		
        		return sdf.format(gcal.getTime());
        	}        	
        	
        	public String asBasicHrMnSc(TimeZoneEnum tze)
        	{
        		GregorianCalendar gcal = new GregorianCalendar();
        		gcal.setTimeInMillis(_exMilli);
        		
        		SimpleDateFormat sdf = new SimpleDateFormat("HH:mm:ss");
        		sdf.setTimeZone(tze.getTimeZone());
        		
        		return sdf.format(gcal.getTime());
        	}        	        	
        	
        	
        	public int numDaysBefore(DayCode dc, TimeZoneEnum tze)
        	{
        		DayCode myday = DayCode.lookup(asBasicTs(tze));
        		
        		return DayCode.daysBetween(myday, dc);
        	}
        	
        	public static ExactMoment fromSqlResponseE(java.sql.Timestamp sqltime, TimeZoneEnum tze)
        	{
        		try { return fromSqlResponse(sqltime, tze); }
        		catch (ParseException pex) { throw new RuntimeException(pex); }
        	}
        	
        	public static ExactMoment fromSqlResponse(java.sql.Timestamp sqltime, TimeZoneEnum tze) throws ParseException
        	{
        		String ts = sqltime.toString();
        		ts = ts.substring(0, ts.length()-2);
        		return fromLongBasic(ts, tze);
        	}
        	
        	public static ExactMoment fromLongBasic(String tstamp, TimeZoneEnum tze) throws ParseException
        	{
        		SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        		sdf.setTimeZone(tze.getTimeZone());        		
        		
        		Date gimp = sdf.parse(tstamp);
        		return new ExactMoment(gimp.getTime());
        	}
        	
        	public static ExactMoment fromLongBasicE(String tstamp, TimeZoneEnum tze)
        	{
        		try { return fromLongBasic(tstamp, tze); }
        		catch (ParseException parsex) {
        			throw new RuntimeException(parsex);	
        		}
        	}        	
        	
        	// Postgres will give you back strings that look like this: 
        	// 2015-08-07 21:32:00.204294
        	public static ExactMoment fromLongPgFormat(String pgformat, TimeZoneEnum tze) throws ParseException
        	{
        		String[] long_decimal = pgformat.split("\\.");
        		return fromLongBasic(long_decimal[0], tze);
        	}        	
        	
        	public static ExactMoment fromLongPgFormatE(String pgformat, TimeZoneEnum tze)
        	{
        		try { return fromLongPgFormat(pgformat, tze); }
        		catch (ParseException pex) { throw new RuntimeException(pex); }
        	}             	
        	
        	public static ExactMoment fromS3Response(String s3response) throws ParseException
        	{
        		SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm");
        		sdf.setTimeZone(TimeZoneEnum.UTC.getTimeZone());               		
        		
        		Date gimp = sdf.parse(s3response);
        		return new ExactMoment(gimp.getTime());        
        	}
        	
        	public static ExactMoment fromDateFormat(String tstamp, SimpleDateFormat sdf) throws ParseException
        	{
        		Date gimp = sdf.parse(tstamp);
        		return new ExactMoment(gimp.getTime());
        	}
        }
        
        public static class TimeDiff
        {
        	public final long S;
        	public final long E;
        	
        	public TimeDiff(long a, long b)
        	{
        		S = a;
        		E = b;
		}
				
		private ExactMoment getGimpMoment()
		{
			return new ExactMoment(E-S);	
		}
        	
        }
        
        public static class SimpleTimer 
        {
        	private double _sTimeMilli;
        	private double _eTimeMilli;
        	
        	public SimpleTimer() {}
        	
        	public static SimpleTimer buildAndStart()
        	{
        		SimpleTimer st = new SimpleTimer();
        		st.start();
        		return st;
        	}
        	
        	public SimpleTimer start()
        	{
        		_sTimeMilli = Util.curtime();
        		return this;
        	}
        	
        	public SimpleTimer stop()
        	{
        		_eTimeMilli = Util.curtime();
        		return this;
        	}
        	
        	public double getTimeSinceStartSec()
        	{
        		return (Util.curtime() - _sTimeMilli)/1000;	
        		
        	}
        	
        	public double getTimeSec()
        	{
        		return (_eTimeMilli - _sTimeMilli)/1000;	
        	}
        }
}
