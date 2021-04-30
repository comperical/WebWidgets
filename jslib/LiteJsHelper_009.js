

// Map of table name to get full item list
__getListFuncMap = {};

// table name to builder function
__buildItemFuncMap = {};

// table name to newBasicId function
__newBasicFuncMap = {};

// table name to Item lookup
__itemLookupFuncMap = {};

// table name to haveItem func
__haveItemFuncMap = {};

// Map of of username::widgetname --> Unix checksum for the Widget DB
__databaseCheckSum = {};

// Get all the tables that have been registered on this page.
function getWidgetTableList()
{
	return Object.keys(__buildItemFuncMap);
}

// Return true if the table is in the data for the page.
function haveTable(tabname)
{
    return tabname in __buildItemFuncMap;   
}

function haveItem(tabname, itemid)
{
    checkTableName(tabname);
    const havefunc = __haveItemFuncMap[tabname];
    return havefunc(itemid);
}

function getItemList(tabname)
{
    checkTableName(tabname);
    var itemfunc = __getListFuncMap[tabname];
    return itemfunc();
}

function buildItem(tabname, record)
{
    checkTableName(tabname);
    var buildfunc = __buildItemFuncMap[tabname];    

    // Jan 2021: you no longer need to call newBasicId(...) yourself and put it in the record
    // This method will do it for you.
    if(!record.hasOwnProperty("id"))
        { record["id"] = newBasicId(tabname); }

    return buildfunc(record);   
}

function newBasicId(tabname)
{
    checkTableName(tabname);
    var idfunc = __newBasicFuncMap[tabname];
    return idfunc();    
}

function lookupItem(tabname, k1, k2, k3, k4) 
{
    checkTableName(tabname);
    return __itemLookupFuncMap[tabname](k1, k2, k3, k4);
}

function getHaveItemFunc(tabname)
{
    checkTableName(tabname);    
    return __haveItemFuncMap[tabname];  
}

function checkTableName(tabname)
{
    // Trying to be very careful here with older browsers.
    if(__haveItemFuncMap.hasOwnProperty(tabname)) {
        return;
    }

    var tlist = [];
    for(tname in __haveItemFuncMap) {
        tlist.push(tname);
    }

    massert(false, "Could not find table name " + tabname + ", options are " + tlist);
}


// Shorthand for decodeURIComponent, save a bit of bandwidth
function __duric(s)
{
    return decodeURIComponent(s);
}


// ----------------
// For Sql2Js

const CALLBACK_URL = "/u/callback";

function getTableCoords(tablemaster)
{
    return {
        "wowner" : tablemaster.widgetOwner,
        "wname" : tablemaster.widgetName,
        "tablename" : tablemaster.tableName
    };
}

// Look up the widget owner and name from the url
// Use that info to find the current checksum value
// This needs to be looked up just-in-time, before the request is sent,
// AFTER it is enqueued
function __augmentWithCheckSum(opurl)
{
    massert(opurl.indexOf(CALLBACK_URL) == 0, 
        "Expected OP URL to start with callback URL, found " + CALLBACK_URL);

    const querystring = opurl.substring((CALLBACK_URL + "?").length);
    // console.log("Query string is " + querystring);

    const params = decodeQString2Hash(querystring);
    // console.log(params);

    const cksumkey = params["wowner"]+ "::" + params["wname"];
    const cksumval = __databaseCheckSum[cksumkey];
    params["checksum"] = cksumval;
    return CALLBACK_URL + "?" + encodeHash2QString(params);
}


function genericUpsertUrl(tablemaster, item, keylist)
{
    var subpack = getTableCoords(tablemaster);
    
    for (var i in keylist)
    {
        var onekey = keylist[i];
        subpack[onekey] = item[onekey];
    }
    
    massert(!("ajaxop" in subpack), "Shouldn't have an ajaxop!!");
    subpack["ajaxop"] = "upsert";
    return CALLBACK_URL + "?" + encodeHash2QString(subpack);
}

function genericDeleteUrl(tablemaster, item, keylist)
{
    var subpack = getTableCoords(tablemaster);
    
    for (var i in keylist)
    {
        var onekey = keylist[i];
        subpack[onekey] = item[onekey];
    }
    
    massert(!("ajaxop" in subpack), "Shouldn't have an ajaxop!!");  
    subpack["ajaxop"] = "delete";
    return CALLBACK_URL + "?" + encodeHash2QString(subpack);
}

function createNewIdBasic(datamap, idcol)
{
    var idlist = Object.keys(datamap).map(function(k) {
        return datamap[k][idcol];   
    });
    
    if(idlist.length == 0)
        { return 0; }
    
    var maxid = idlist.reduce(function(a, b) {
        return Math.max(a, b);      
    });
    
    return maxid+1;
}

function syncSingleItem(item)
{
    __submitNewRequest(item.getUpsertUrl(), "sync", item.getPkeyStr());
}

function deleteSingleItem(item)
{
    __submitNewRequest(item.getDeleteUrl(), "delete", item.getPkeyStr());
}


const __REQUEST_QUEUE = [];

var __REQUEST_IN_FLIGHT = false;

function __submitNewRequest(opurl, opname, itempk) 
{
    const reqlist = [opurl, opname, itempk];
    __REQUEST_QUEUE.push(reqlist);  
    __maybeSendNewRequest();
}

function __maybeSendNewRequest()
{
    if(__REQUEST_IN_FLIGHT)
        { return; }
    
    if(__REQUEST_QUEUE.length == 0)
        { return; }
    
    __REQUEST_IN_FLIGHT = true;
    
    const reqlist = __REQUEST_QUEUE.shift();

    // This needs to be augmented just-in-time
    const opurl = __augmentWithCheckSum(reqlist[0]);
    // console.log(reqlist[0]);
    // console.log(opurl);
    const opname = reqlist[1];
    const itempk = reqlist[2];
    
    // console.log("sending new request, queue length is now " + __REQUEST_QUEUE.length);
    // console.log("Opname " + opname + ", PK: " + itempk);
    
    var xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
        
        // This block of code is actually called several times before
        // It is ready. readyState == 4 implies the request completed.
        if (this.readyState == 4) {         
            massert(this.status == 200, "Unexpected error code on Ajax operation: " + this.status);
            __checkAjaxResponse(opname, itempk, this.responseText);
            __REQUEST_IN_FLIGHT = false;
            __maybeSendNewRequest();
        }
    };
    
    xhttp.open("GET", opurl, true);
    xhttp.send();
}

function __checkAjaxResponse(op, itemid, rtext)
{
    // console.log(rtext);
    const response = JSON.parse(rtext);
    
    if(response.status_code == "okay")
    {
        // Read out the new CKSUM data from the response.
        // These field names must match Java code.
        const cksumkey = response.checksum_key;
        const cksumval = parseInt(response.checksum_val);
        __databaseCheckSum[cksumkey] = cksumval;

        const logmssg = `AjaxOp for itemid ${itemid} worked, new val for key ${cksumkey} is ${cksumval}`;
        console.log(logmssg);
        return;     
    }
    
    // Something went wrong, try to give user as informative a message as possible.
    const fcode = response.failure_code;
    const umssg = response.user_message;
    const einfo = response.extra_info;
    
    var errmssg = `Problem with sync operation: ${fcode} \n ${umssg}`;
    
    if(einfo.length > 0) {
    	errmssg += `\nAdditional info:\n${einfo}`;	    
    }
    
    massert(false, errmssg);
}



