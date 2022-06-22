
const W = {

// Map of table name to get full item list
__getListFuncMap : {},

// table name to builder function
__buildItemFuncMap : {},

// table name to newBasicId function
__newBasicFuncMap : {},

// table name to Item lookup
__itemLookupFuncMap : {},

// table name to haveItem func
__haveItemFuncMap : {},

// Map of of username::widgetname --> Unix checksum for the Widget DB
__databaseCheckSum : {},    

CALLBACK_URL : "/u/callback",

__REQUEST_QUEUE : [],

__REQUEST_IN_FLIGHT : false,

__RAW_DEP_WARNING_COUNT : 0,

// Find the item with the given ID for the given table and return it.
// Error if the item does not exist, if you are uncertain whether the ID exists or not,
// call haveItem(tabname, itemid)
lookupItem : function(tabname, itemid)
{
    W.checkTableName(tabname);
    return W.__itemLookupFuncMap[tabname](itemid);
},

// Get the full list of records associated with given table.
// This is one of the most fundamental operations of the framework.
// Error if the table name is not loaded on the current page.
// If you are uncertain if the table will be present, use haveTable(...) to check
getItemList : function(tabname) 
{
    W.checkTableName(tabname);
    const itemfunc = W.__getListFuncMap[tabname];
    return itemfunc();        
}, 

// Create a new record for the given table.
// The record argument is a hash with keys corresponding to the column names of the table.
// It is optional to provide the "id" column, if you do not provide it, the framework
// will allocate a new id and assign it to the record.
// Other than the id column, all columns must be explicitly provided.
// IMPORTANT: this method creates the record but does not sync it to the server.
// To sync, call syncItem on the returned JS representation of the record.
buildItem : function(tabname, record)
{
    W.checkTableName(tabname);
    const buildfunc = W.__buildItemFuncMap[tabname];    

    // Jan 2021: you no longer need to call newBasicId(...) yourself and put it in the record
    // This method will do it for you.
    if(!record.hasOwnProperty("id"))
        { record["id"] = W.newBasicId(tabname); }

    return buildfunc(record);   
},

// Check if the given table has an item with the given ID.
// This is logically equivalent to calling getItemList
// and checking each record to see if it has the ID, 
// but is faster because it uses the index on the table.
haveItem : function(tabname, itemid)
{
    W.checkTableName(tabname);
    const havefunc = W.__haveItemFuncMap[tabname];
    return havefunc(itemid);
},

// Return true if the table is in the data for the page.
haveTable : function(tabname)
{
    return tabname in W.__buildItemFuncMap;   
},

// Get all the tables that have been registered on this page.
getWidgetTableList : function()
{
    return Object.keys(W.__buildItemFuncMap);
},


// Creates a new ID for the given table name.
// This method is no longer recommended, you should let the framework
// assign a new ID and then call getId() on the resulting object.
newBasicId : function(tabname)
{
    W.checkTableName(tabname);
    const idfunc = W.__newBasicFuncMap[tabname];
    return idfunc();    
},

getHaveItemFunc : function(tabname)
{
    W.checkTableName(tabname);    
    return W.__haveItemFuncMap[tabname];  
},

// Checks that the given table name exists and is loaded.
// Error if it is not.
checkTableName : function(tabname)
{
    // Trying to be very careful here with older browsers.
    if(W.__haveItemFuncMap.hasOwnProperty(tabname)) {
        return;
    }

    var tlist = [];
    for(tname in W.__haveItemFuncMap) {
        tlist.push(tname);
    }

    massert(false, "Could not find table name " + tabname + ", options are " + tlist);
},

// Look up the widget owner and name from the url
// Use that info to find the current checksum value
// This needs to be looked up just-in-time, before the request is sent,
// AFTER it is enqueued
__augmentWithCheckSum : function(opurl)
{
    massert(opurl.indexOf(W.CALLBACK_URL) == 0, 
        "Expected OP URL to start with callback URL, found " + W.CALLBACK_URL);

    const querystring = opurl.substring((W.CALLBACK_URL + "?").length);
    // console.log("Query string is " + querystring);

    // TODO: these decoded/encode functions should be in a namespace also
    const allparams = decodeQString2Hash(querystring);
    // console.log(params);

    const combined = new Object();
    combined.smllpms = new Object();
    combined.biggpms = new Object();

    for(var k in allparams) 
    {
        const v = allparams[k];
        const relpms = v.length > MAX_GET_PARAM_VALUE ? combined.biggpms : combined.smllpms;
        relpms[k] = v;
    }

    const cksumkey = params["wowner"]+ "::" + params["wname"];
    const cksumval = W.__databaseCheckSum[cksumkey];
    combined.smllpms["checksum"] = cksumval;


    return W.CALLBACK_URL + "?" + encodeHash2QString(params);
},


// Destructure the OPURL back into the params that were used to compose it
__paramsFromCallBackUrl : function(opurl)
{
    massert(opurl.indexOf(W.CALLBACK_URL) == 0, 
        "Expected OP URL to start with callback URL, found " + W.CALLBACK_URL);

    const querystring = opurl.substring((W.CALLBACK_URL + "?").length);
    // console.log("Query string is " + querystring);

    // TODO: these decoded/encode functions should be in a namespace also
    return decodeQString2Hash(querystring);
}

__getTableCoords : function(tablemaster)
{
    return {
        "wowner" : tablemaster.widgetOwner,
        "wname" : tablemaster.widgetName,
        "tablename" : tablemaster.tableName
    };
},


genericUpsertUrl : function(tablemaster, item, keylist)
{
    var subpack = W.__getTableCoords(tablemaster);
    
    for (var i in keylist)
    {
        var onekey = keylist[i];
        subpack[onekey] = item[onekey];
    }
    
    massert(!("ajaxop" in subpack), "Shouldn't have an ajaxop!!");
    subpack["ajaxop"] = "upsert";
    return W.CALLBACK_URL + "?" + encodeHash2QString(subpack);
},

genericDeleteUrl : function(tablemaster, item, keylist)
{
    var subpack = W.__getTableCoords(tablemaster);
    
    for (var i in keylist)
    {
        var onekey = keylist[i];
        subpack[onekey] = item[onekey];
    }
    
    massert(!("ajaxop" in subpack), "Shouldn't have an ajaxop!!");  
    subpack["ajaxop"] = "delete";
    return W.CALLBACK_URL + "?" + encodeHash2QString(subpack);
},

createNewIdBasic : function(datamap, idcol)
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
},


__submitNewRequest : function(opurl, opname, itempk) 
{
    const reqlist = [opurl, opname, itempk];
    W.__REQUEST_QUEUE.push(reqlist);  
    W.__maybeSendNewRequest();
},

__maybeSendNewRequest : function()
{
    if(W.__REQUEST_IN_FLIGHT)
        { return; }
    
    if(W.__REQUEST_QUEUE.length == 0)
        { return; }
    
    W.__REQUEST_IN_FLIGHT = true;
    
    const reqlist = W.__REQUEST_QUEUE.shift();

    // This needs to be augmented just-in-time
    const opurl = W.__augmentWithCheckSum(reqlist[0]);
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
            W.__checkAjaxResponse(opname, itempk, this.responseText);
            W.__REQUEST_IN_FLIGHT = false;
            W.__maybeSendNewRequest();
        }
    };
    
    xhttp.open("GET", opurl, true);
    xhttp.send();
},

__checkAjaxResponse : function(op, itemid, rtext)
{
    // console.log(rtext);
    const response = JSON.parse(rtext);
    
    if(response.status_code == "okay")
    {
        // Read out the new CKSUM data from the response.
        // These field names must match Java code.
        const cksumkey = response.checksum_key;
        const cksumval = parseInt(response.checksum_val);
        W.__databaseCheckSum[cksumkey] = cksumval;

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
},

showRawFunctionWarning : function(funcname) {

    if (W.__RAW_DEP_WARNING_COUNT < 3) {
        console.log(`**Warning**, use of raw function ${funcname} is deprecated and may be removed in future version, please use W.${funcname}`);            
    }

    W.__RAW_DEP_WARNING_COUNT++;
}
};








