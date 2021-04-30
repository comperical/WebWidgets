
_DAY_CODE_MAP = {};

_DAY_CODE_LIST = [];

DAY_MILLI = (1000 * 60 * 60 * 24);

SHORT_DAY_WEEK_LIST = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

LONG_DAY_WEEK_LIST = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

const MONTH_NAMES = ["January", "February", "March", "April",  "May", "June", "July", "August", "September", "October", "November", "December"];

const TIME_ZONE_LIST = ["UTC", "EST", "PST", "CST", "GMT"];

function DayCode(longmilli, dayidx)
{
	// At this point, the TimeZone doesn't matter, we're just using the date format logic.
	const d = new Date(longmilli);
	
	this.dateItem = d;
	
	this.dayCodeIndex = dayidx;
	
	this.dateString = calcDayCodeStr(this.dateItem);
	
}

// Returns the ISO date string of the DayCode objects, eg 2020-09-10
DayCode.prototype.getDateString = function()
{
	return this.dateString;
}

// Return the day after the given object.
DayCode.prototype.dayAfter = function()
{
	return getDayCodeList()[this.dayCodeIndex+1];
}

// Day before the given object.
DayCode.prototype.dayBefore = function()
{
	return getDayCodeList()[this.dayCodeIndex-1];
}

// N Days Before this DayCode
DayCode.prototype.nDaysBefore = function(nd)
{
	return getDayCodeList()[this.dayCodeIndex-nd];
}

// N days after this DayCode
DayCode.prototype.nDaysAfter = function(nd)
{
	return getDayCodeList()[this.dayCodeIndex+nd];
}


// Number of days from this DayCode to the argument DayCode
DayCode.prototype.daysUntil = function(dc) 
{
	return dc.dayCodeIndex - this.dayCodeIndex;	
}

// Short Day of Week for this DayCode (Mon, Tue, ... Sat, Sun)
DayCode.prototype.getShortDayOfWeek = function()
{
	return SHORT_DAY_WEEK_LIST[this.dateItem.getDay()]
}

// Day of week for this day code.
DayCode.prototype.getDayOfWeek = function()
{
	return LONG_DAY_WEEK_LIST[this.dateItem.getDay()]
}

// Name of month for this DayCode.
DayCode.prototype.getMonthName = function()
{
	return MONTH_NAMES[this.dateItem.getMonth()];
}

// Get a "Nice" display for the DayCode, in the form: 
// Mon, 09-10
// Thu, 10-01
// These are a bit more palatable for dropdowns.
DayCode.prototype.getNiceDisplay = function()
{
	var nices = this.getShortDayOfWeek();
	
	nices += ", " + this.dateString.substring(5);
	
	return nices;
}

// Lookup the DayCode object from the given ISO string
function lookupDayCode(dcstr)
{
	var dcmap = getDayCodeMap(dcstr);

	return dcmap[dcstr];	
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

// DayCode for current Date.
function getTodayCode()
{
	var todaystr = calcDayCodeStr(new Date());
	return getDayCodeMap()[todaystr];	
}

// N days before today.
function getNDaysAgo(n)
{
	var dc = getTodayCode();
	
	for(var i = 0; i < n; i++)
		{ dc = dc.dayBefore(); }
	
	return dc 
}

// Utility function for padding zeros on string, needed for date formatting.
function padLeadingZeros(str2pad, reqlen)
{
	var s = str2pad;

	while(s.length < reqlen)
		{ s = "0" + s; }
	
	return s;
}



// Initialize the DayCode data.
function _maybeInitDayData()
{
	if(_DAY_CODE_LIST.length == 0)
	{
		// 2020-10-03.
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

// The earlist date that can be expressed by the DayCode system.
// As of October 2020, the system can represent all dates ranging from 
// 2013-10-03 to 2041-02-17. 
// For dates falling outside of this range, you need to do your own 
// date processing.
function getEarliestOkayDate()
{
	_maybeInitDayData();
	
	return _DAY_CODE_LIST[0];
}

// Complete list of all day codes in the system.
// In order, starting with earliest date.
function getDayCodeList()
{
	_maybeInitDayData();
	
	return _DAY_CODE_LIST;
}


// return map of ISO date code to DayCode object.
function getDayCodeMap()
{
	_maybeInitDayData();
	
	return _DAY_CODE_MAP;
}

// List of dates corresponding to the current week.
function getCurrentWeekList()
{
	return getWeekOfList(getLastMonday());
}

// Get the list of date strings corresponding to the week of the given Monday.
// The Monday will be the first day of the list.
// Argument is a DayCode.
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

// Return the DayCode that correspond to the Monday that starts the
// week that includes the given DayCode.
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

// Most recent Monday - the starting Monday for today's date.
function getLastMonday()
{
	var dc = getTodayCode();
	return getMonday4Date(dc);
}


function ExactMoment(longmilli)
{
	this.__epochTimeMilli = longmilli;
}

function exactMomentNow()
{
	const milli = new Date().getTime();
	return new ExactMoment(milli);
}

function checkTimeZoneOkay(timezone)
{
	massert(TIME_ZONE_LIST.includes(timezone), "Unknown timezone " + timezone + " options are " + TIME_ZONE_LIST);
}

function enGbToIso(engbdate)
{
	// EN GB comes in this format:
	// 10/01/2021

	const toks = engbdate.split("/");
	return toks[2] + "-" + toks[1] + "-" + toks[0];
}

function maybePad(pdstr)
{
	return pdstr.length == 1 ? "0" + pdstr : pdstr;
}

function enUsToIso(fullenus)
{

	// "1/10/2021, 9:56:58 PM"
	// console.log("Input to function is : " + fullenus);

	const date_time_apm = fullenus.replace(",", "").split(" ");

	// console.log(date_time_apm);

	const mnth_day_year = date_time_apm[0].split("/");
	const isodate = [mnth_day_year[2], maybePad(mnth_day_year[0]), maybePad(mnth_day_year[1])].join("-");

	// console.log("Date is "+ isodate);

	const hr_mn_sc = date_time_apm[1].split(":");
	const ispm = date_time_apm[2].includes("PM");
	var basehour = parseInt(hr_mn_sc[0]);
	basehour += (ispm && basehour < 12 ? 12 : 0);

	// 12 AM --> 00:
	basehour = (!ispm && basehour == 12 ? 0 : basehour);

	const isotime = [maybePad(basehour+""), hr_mn_sc[1], hr_mn_sc[2]].join(":");
	// console.log("ISO time is " + isotime);

	return [isodate, isotime].join(" ");

}

function exactMomentFromIsoBasic(timestamp, timezone)
{
	checkTimeZoneOkay(timezone);

	const millis = Date.parse(timestamp + " " + timezone);
	return new ExactMoment(millis);
}

ExactMoment.prototype.getEpochTimeMilli = function()
{
	return this.__epochTimeMilli;
}


ExactMoment.prototype.withAddedMilli = function(milli)
{
	return new ExactMoment(this.__epochTimeMilli + milli);
}



ExactMoment.prototype.asIsoLongBasic = function(timezone)
{
	massert(TIME_ZONE_LIST.includes(timezone), "Unknown timezone " + timezone + " options are " + TIME_ZONE_LIST);
	
	// console.log(event.toLocaleString('en-GB', { timeZone: 'UTC' }));
	// expected output: 20/12/2012, 03:00:00
	const date_ob = new Date(this.__epochTimeMilli);

	const enusform = date_ob.toLocaleString('en-US', { timeZone : timezone })
	return enUsToIso(enusform);


	/*
	const engbform = date_ob.toLocaleString('en-GB', { timeZone : timezone });

	const date_time = engbform.split(",");
	const isodate = enGbToIso(date_time[0]);
	return isodate + " " + date_time[1];
	*/
}




