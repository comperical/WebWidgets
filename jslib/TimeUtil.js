
_DAY_CODE_MAP = {};

_DAY_CODE_LIST = [];

DAY_MILLI = (1000 * 60 * 60 * 24);

SHORT_DAY_WEEK_LIST = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

LONG_DAY_WEEK_LIST = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

const MONTH_NAMES = ["January", "February", "March", "April",  "May", "June", "July", "August", "September", "October", "November", "December"];

function DayCode(longmilli, dayidx)
{
	// At this point, the TimeZone doesn't matter, we're just using the date format logic.
	const d = new Date(longmilli);
	
	this.dateItem = d;
	
	this.dayCodeIndex = dayidx;
	
	this.dateString = calcDayCodeStr(this.dateItem);
	
}

DayCode.prototype.getDateString = function()
{
	//return calcDayCodeStr(this.dateItem);
	
	return this.dateString;
}

DayCode.prototype.dayAfter = function()
{
	return getDayCodeList()[this.dayCodeIndex+1];
}

DayCode.prototype.dayBefore = function()
{
	return getDayCodeList()[this.dayCodeIndex-1];
}

DayCode.prototype.nDaysBefore = function(nd)
{
	return getDayCodeList()[this.dayCodeIndex-nd];
}

DayCode.prototype.nDaysAfter = function(nd)
{
	return getDayCodeList()[this.dayCodeIndex+nd];
}


DayCode.prototype.daysUntil = function(dc) 
{
	return dc.dayCodeIndex - this.dayCodeIndex;	
}

DayCode.prototype.getShortDayOfWeek = function()
{
	return SHORT_DAY_WEEK_LIST[this.dateItem.getDay()]
}

DayCode.prototype.getDayOfWeek = function()
{
	return LONG_DAY_WEEK_LIST[this.dateItem.getDay()]
}

DayCode.prototype.getMonthName = function()
{
	return MONTH_NAMES[this.dateItem.getMonth()];
}

DayCode.prototype.getNiceDisplay = function()
{
	var nices = this.getShortDayOfWeek();
	
	nices += ", " + this.dateString.substring(5);
	
	return nices;
}



function calcDayCodeStr(dateitem)
{
	// Ugh, MONTH is zero-indexed, but DATE is 1-indexed!!
	var ds = dateitem.getFullYear() + "-" + padLeadingZeros((dateitem.getMonth()+1)+"", 2) + "-" + padLeadingZeros(dateitem.getDate()+"", 2);	
	return ds;	
}

function calcTimeHourStr(dateitem)
{
	var ds = padLeadingZeros(dateitem.getHours()+"", 2) + ":" + padLeadingZeros(dateitem.getMinutes()+"", 2) + ":" + padLeadingZeros(dateitem.getSeconds()+"", 2);
	return ds;	
}

function calcFullLogTimeStr(dateitem)
{
	return calcDayCodeStr(dateitem) + " " + calcTimeHourStr(dateitem);	
}

function getTodayCode()
{
	var todaystr = calcDayCodeStr(new Date());
	return getDayCodeMap()[todaystr];	
}

function getNDaysAgo(n)
{
	var dc = getTodayCode();
	
	for(var i = 0; i < n; i++)
		{ dc = dc.dayBefore(); }
	
	return dc 
}

function padLeadingZeros(str2pad, reqlen)
{
	var s = str2pad;

	while(s.length < reqlen)
		{ s = "0" + s; }
	
	return s;
}


function lookupDayCode(dcstr)
{
	var dcmap = getDayCodeMap(dcstr);

	return dcmap[dcstr];	
}

function _maybeInitDayData()
{
	if(_DAY_CODE_LIST.length == 0)
	{
		var startmilli = 1380847199792;
		
		for(var di = 0; di < 10000; di++)
		{
			var daymilli = startmilli + (di * DAY_MILLI);
			
			var dc = new DayCode(daymilli, di);
			
			_DAY_CODE_MAP[dc.getDateString()] = dc;
			
			_DAY_CODE_LIST[di] = dc;
		}		
	}
}

function getEarliestOkayDate()
{
	_maybeInitDayData();
	
	return _DAY_CODE_LIST[0];
}

function getDayCodeList()
{
	_maybeInitDayData();
	
	return _DAY_CODE_LIST;
}


function getDayCodeMap()
{
	_maybeInitDayData();
	
	return _DAY_CODE_MAP;
}

function getCurrentWeekList()
{
	return getWeekOfList(getLastMonday());
}

function getWeekOfList(mondaycode)
{
	massert(mondaycode.getShortDayOfWeek() == "Mon");
	
	var weeklist = [];
	var dc = mondaycode;

	while(weeklist.length < 7)
	{
		weeklist.push(dc.getDateString());
		dc = dc.dayAfter();
	}
		
	return weeklist;	
}

function getMonday4Date(dc) 
{
	for(var i = 0; i < 10; i++)
	{
		if(dc.getShortDayOfWeek() == "Mon")
			{ return dc; }
		
		dc = dc.dayBefore();
	}
	
	massert(false, "Failed to find a good Monday!!!");	
}

function getLastMonday()
{
	var dc = getTodayCode();
	
	return getMonday4Date(dc);
}




