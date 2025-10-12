


// Map of ISO date strings to DayCode Objects.
const __DAY_CODE_MAP = {};

// List of all DayCode objects available in the system.
// This list contains about 15K records, about plus/minus ten years from the present date.
const __DAY_CODE_LIST = [];

// Regex to match ISO "basic" timestamps.
// Unlike standard one, do not use the central "T"
const __LONG_ISO_BASIC_PATTERN = /\d{4}-[01]\d-[0-3]\d [0-2]\d:[0-5]\d:[0-5]\d/;

const DAY_MILLI = (1000 * 60 * 60 * 24);

const SHORT_DAY_WEEK_LIST = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

const LONG_DAY_WEEK_LIST = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

const MONTH_NAMES = ["January", "February", "March", "April",  "May", "June", "July", "August", "September", "October", "November", "December"];

const TIME_ZONE_OFFSET_MAP = {
    "UTC" : 0,
    "AST" : -4,
    "EST" : -5,
    "PST" : -8,
    "PDT" : -7,
    "GMT" : 0
}


const TIME_ZONE_LIST = Object.keys(TIME_ZONE_OFFSET_MAP);

// This is the main way to create DayCodes.
// The input argument is an ISO formatted string of the form YYYY-MM-DD, such as 2021-01-10
// This method returns an immutable DayCode object from the internal pool.
function lookupDayCode(dcstr)
{
    W.showRawFunctionWarning("lookupDayCode");
    return U.lookupDayCode(dcstr);
}

// True if we have a day code for the given string
// This can be used as a form of primitive date format checking
function haveDayCodeForString(dcstr)
{
    W.showRawFunctionWarning("haveDayCodeForString");
    return U.haveDayCodeForString(dcstr);
}


// DayCode for current Date.
function getTodayCode()
{
    W.showRawFunctionWarning("getTodayCode");
    return U.getTodayCode();
}



function DayCode(longmilli, dayidx)
{
    // At this point, the TimeZone doesn't matter, we're just using the date format logic.
    const d = new Date(longmilli);
    
    this.dateItem = d;
    
    this.dayCodeIndex = dayidx;
    
    this.dateString = __calcDayCodeStr(this.dateItem);
    
}

// Returns the ISO date string of the DayCode objects, eg 2020-09-10
DayCode.prototype.getDateString = function()
{
    return this.dateString;
}

// True if THIS DayCode object is before the argument DayCode
DayCode.prototype.isBefore = function(other)
{
    return this.getDateString() < other.getDateString();
}

// True if THIS DayCode object is AFTER the argument DayCode
DayCode.prototype.isAfter = function(other)
{
    return this.getDateString() > other.getDateString();
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



// Internal method that composes an ISO YYYY-MM-DD timestamp from a JavaScript Date object.
function __calcDayCodeStr(dateitem)
{
    // Ugh, MONTH is zero-indexed, but DATE is 1-indexed!!
    var ds = dateitem.getFullYear() + "-" + padLeadingZeros((dateitem.getMonth()+1)+"", 2) + "-" + padLeadingZeros(dateitem.getDate()+"", 2);   
    return ds;
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
function __maybeInitDayData()
{
    if(__DAY_CODE_LIST.length == 0)
    {
        // 2020-10-03.
        var startmilli = 1380847199792;
        
        for(var di = 0; di < 10000; di++)
        {
            var daymilli = startmilli + (di * DAY_MILLI);
            
            var dc = new DayCode(daymilli, di);
            
            __DAY_CODE_MAP[dc.getDateString()] = dc;
            
            __DAY_CODE_LIST[di] = dc;
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
    __maybeInitDayData();
    
    return __DAY_CODE_LIST[0];
}

// Complete list of all day codes in the system.
// In order, starting with earliest date.
function getDayCodeList()
{
    __maybeInitDayData();
    
    return __DAY_CODE_LIST;
}


// return map of ISO date code to DayCode object.
function getDayCodeMap()
{
    __maybeInitDayData();
    return __DAY_CODE_MAP;
}

// List of dates corresponding to the current week.
function getCurrentWeekList()
{
    return getWeekOfList(getLastMonday());
}

// Get the list of date strings corresponding to the week of the given Monday.
// The Monday will be the first day of the list.
// Argument is a DayCode
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
// See getMonday4Date method above
function getLastMonday()
{
    var dc = getTodayCode();
    return getMonday4Date(dc);
}

function checkTimeZoneOkay(timezone)
{
    massert(TIME_ZONE_LIST.includes(timezone), "Unknown timezone " + timezone + " options are " + TIME_ZONE_LIST);
}

function maybePad(pdstr)
{
    return pdstr.length == 1 ? "0" + pdstr : pdstr;
}



// Construct an exact Moment using the given millisecond argument.
// This is the number of milliseconds since the Unix epoch.
// https://en.wikipedia.org/wiki/Unix_time
function ExactMoment(longmilli)
{
    this.__epochTimeMilli = longmilli;
}

// Create an Exact Moment representing the current instant of time.
// This is one of the main ways to create an ExactMoment.
function exactMomentNow()
{
    // const milli = new Date().getTime();
    const milli = Date.now();
    return new ExactMoment(milli);
}

ExactMoment.prototype.getEpochTimeMilli = function()
{
    return this.__epochTimeMilli;
}


// Return a new ExactMoment that is the given amount of milliseconds in the future.
// This is a simple approach to converting times. Say you want to add a 1/2 hour to the current time.
// const nowex = exactMomentNow(); 
// const futex = nowex.withAddedMilli(30*60*1000); // half hour in milliseconds
// const timestr = futex.asIsoLongBasic("PST"); // this is a timestamp
ExactMoment.prototype.withAddedMilli = function(milli)
{
    return new ExactMoment(this.__epochTimeMilli + milli);
}


// Create an ISO "long basic" timestamp string of the form  YYYY-MM-DD HH:MM:SS
// Example: 2020-05-15 14:21:45
// Use the given timezone to produce the timestamp
ExactMoment.prototype.asIsoLongBasic = function(timezone)
{
    massert(timezone in TIME_ZONE_OFFSET_MAP, "Unknown timezone " + timezone + " options are " + TIME_ZONE_OFFSET_MAP);
    
    const hourmod = TIME_ZONE_OFFSET_MAP[timezone];

    const mydate = new Date(this.__epochTimeMilli + (hourmod * 3600 * 1000));

    const isoformat = mydate.toISOString().substring(0, "2022-04-14T21:20:00".length).replace("T", " ");
    return isoformat;
}


// Return true if the given timestamp is a valid "Long basic" ISO timestamp
// The pattern is "YYYY-MM-DD HH:MM:SS", note there is whitespace between the date and time fields (not a T)
// This check is implemented as a regular expression
// If this test returns true, the given string should be successfully converted to an ExactMoment
// Using the exactMomentFromIsoBasic method below
function isLongIsoTimeValid(timestamp)
{
    return __LONG_ISO_BASIC_PATTERN.test(timestamp);
}


// Convert a timestamp, timezone pair into an ExactMoment object
// This is the canonical conversion from timestamp/TZ info into ExactMoments
// The timestamp must be a valid "Long ISO basic" string, of the form "YYYY-MM-DD HH:MM:SS"
// The timezone must be present in the TIME_ZONE_MAP structure
function exactMomentFromIsoBasic(timestamp, timezone)
{
    const hourmod = TIME_ZONE_OFFSET_MAP[timezone];
    massert(hourmod != null, 
        `Time Zone string ${timezone} not present in the time zone map, options are\n${TIME_ZONE_LIST}`);

    massert(isLongIsoTimeValid(timestamp),
        `The timestamp string ${timestamp} is not valid, format is YYYY-MM-DD HH:MM:SS`);

    // Don't use replaceAll, it's not widely supported
    const tstampmod = timestamp.replace(" ", "T");

    const str2parse = tstampmod + "-00:00";
    // console.log(str2parse);

    const utcmillis = Date.parse(str2parse);

    return new ExactMoment(utcmillis - (hourmod * 3600 * 1000));
}


