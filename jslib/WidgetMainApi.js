
const W = {

// Map of table name to get full item list
__getListFuncMap : {},

// table name to builder function
__buildItemFuncMap : {},

// Map of of username::widgetname --> Unix checksum for the Widget DB
// Sept 2022: removing old naive checksum technique
// __databaseCheckSum : {},

// List of tables for which the current user has read access only
__readOnlyAccess : [], 

// Map of short table name to Widget Table objects
__tableNameIndex : new Map(),

CALLBACK_URL : "/u/callback",

BULK_UPDATE_URL : "/u/bulkupdate",

__REQUEST_QUEUE : [],

__REQUEST_IN_FLIGHT : false,

__RAW_DEP_WARNING_COUNT : 0,


// https://stackoverflow.com/questions/417142/what-is-the-maximum-length-of-a-url-in-different-browsers
// Could actually be much smaller than this
MAX_GET_PARAM_VALUE : 2000,

__GLOBAL_INDEX_MAP : new Map(),

__DUMB_INDEX_DELIM : "/x/",

__DATA_LOAD_COMPLETE : false,

// Find the item with the given ID for the given table and return it.
// Error if the item does not exist, if you are uncertain whether the ID exists or not,
// call haveItem(tabname, itemid)
lookupItem : function(tabname, itemid)
{
    W.checkTableName(tabname);
    return W.__tableNameIndex.get(tabname)._dataMap.get(itemid);
},

// Get the full list of records associated with given table.
// This is one of the most fundamental operations of the framework.
// Error if the table name is not loaded on the current page.
// If you are uncertain if the table will be present, use haveTable(...) to check
getItemList : function(tabname) 
{
    W.checkTableName(tabname);
    return [... W.__tableNameIndex.get(tabname)._dataMap.values()];
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

    const theid = parseInt(record["id"]);
    massert(!W.haveItem(tabname, theid), `A record with ID ${theid} already exists in table ${tabname}`);

    return buildfunc(record);
},

// Check if the given table has an item with the given ID.
// This is logically equivalent to calling getItemList
// and checking each record to see if it has the ID, 
// but is faster because it uses the index on the table.
haveItem : function(tabname, itemid)
{
    W.checkTableName(tabname);
    return W.__tableNameIndex.get(tabname)._dataMap.has(itemid);
},

// Return true if the table is in the data for the page.
haveTable : function(tabname)
{
    return W.__tableNameIndex.has(tabname); 
},

// Return the owner of the given table
getTableOwner : function(tabname)
{
    W.checkTableName(tabname);
    return W.__tableNameIndex.get(tabname).widgetOwner;
},




// True if the current user has write access to the given table
// Widgets that serve multiple users, some of whom have write access and some of whom do not,
// should check this function before displaying UI options that will perform write actions.
// The backend will disallow such writes anyway, but it will be a less pleasing user experience
haveWriteAccess : function(tabname)
{
    return W.__readOnlyAccess.indexOf(tabname) == -1;
},


// Return the list of fields/columns in the given Table
// These correspond exactly to the columns in the underlying SQLite table
// This is basically equivalent to calling Object.keys(..) on one of the items,
// but this works even if you don't have an instance of the item
getFieldList : function(tabname)
{
    W.checkTableName(tabname);
    return W.__tableNameIndex.get(tabname).fieldList;
},


// Get all the tables that have been registered on this page.
getWidgetTableList : function()
{
    return Object.keys(W.__buildItemFuncMap);
},


// Creates a new ID for the given table name.
// In general, users should not need to call this method; it is called automatically 
// when the "id" column is not explicitly supplied in the buildItem(...) data.
// The ID is allocated by generating a random integer in the the useable range
// and checking to make sure it is not already in use in the table.
// The useable range is -2147483648 to 2147483647, with an exception for -1000 to 0
newBasicId : function(tabname)
{
    W.checkTableName(tabname);
    const datamap = W.__tableNameIndex.get(tabname)._dataMap;
    return W.createNewIdRandom(datamap);
},


// Creates a new ID for the given table name.
// The new ID is 1 greater than the previous max ID currently in the table
// This approach to ID allocation is not recommended because it can cause problems in multi-user settings
newIncrementalId : function(tabname)
{
    W.checkTableName(tabname);
    const datamap = W.__tableNameIndex.get(tabname)._dataMap;
    return W.createNewIdIncremental(datamap);
},


// Queries the server to obtain a new unused database ID for the given table
// In other words, this is a server-side version of newBasicId(...)
// It is generally better to use the client-side version. This method is intended to be used
// in cases where you do not have all the records for the given table loaded in the client
// For example, if you use the no_data=true option to load the table manager without loading any records
serverSideNewDbId : function(tabname, callback)
{ 
    W.checkTableName(tabname);

    const xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
        
        if (this.readyState == 4) {
            massert(this.status == 200, "Unexpected error code on Ajax operation: " + this.status);

            // The actual ID is in the extra_info field
            const response = JSON.parse(this.responseText);
            const newid = parseInt(response["extra_info"]);
            callback(newid);
        }
    };

    const tableObject = W.__tableNameIndex.get(tabname);
    // This URL must agree with the Java code.
    const opurl = `/u/extend?openum=GetNewDbId&widgetowner=${tableObject.widgetOwner}&widgetname=${tableObject.widgetName}&tablename=${tabname}`;
    
    xhttp.open("GET", opurl, true);
    xhttp.send();
},


// Gets the Blob Store URL for the given item
// NOTE: you should not use this function directly, instead call method with same name, but no arguments
// that is attached to the Widget Blob item
// Example : W.lookupItem("my_blob_table", itemid).getBlobStoreUrl()
getBlobStoreUrl : function(username, widgetname, tablename, recordid)
{
    return `/u/blobstore?username=${username}&widgetname=${widgetname}&tablename=${tablename}&id=${recordid}`;
},

// Checks that the given table name exists and is loaded.
// Error if it is not.
checkTableName : function(tabname)
{
    if(W.__tableNameIndex.has(tabname)) {
        return;
    }

    const tlist = [... W.__tableNameIndex.keys()];
    massert(false, "Could not find table name " + tabname + ", options are " + tlist);
},

// Bulk update of records to the given table.
// You must supply the list of IDs that are to be updated; all such IDs much correspond to real records
// To use this, first perform the desired updates on the given records
// Instead of calling syncItem on each record, call this function with the target IDs
// This method refreshes the page after the update is complete, to ensure the changes have been picked up
// Third argument is a hash that is reserved for allowing modifications to the behavior of this function
bulkUpdate : function(tablename, idlist, options)
{
    W.__bulkOpSub(tablename, idlist, false, options);
},

// Bulk delete of records to the given table.
// You must supply the list of IDs that are to be deleted; all such IDs much correspond to real records
// This method refreshes the page after the update is complete, to ensure the changes have been picked up
// Third argument is a hash that is reserved for allowing modifications to the behavior of this function
bulkDelete : function(tablename, idlist, options)
{

    // Important difference with bulkUpdate: you need to remove from indexes here
    // in bulkUpdate, the indexes are already updated from the setField(..) calls
    idlist.forEach(function(myid) {
        const myitem = W.lookupItem(tablename, myid);
        W.__removeItemFromIndexes(myitem, null);
    });


    W.__bulkOpSub(tablename, idlist, true, options);
},

__bulkOpSub : function(tablename, idlist, isdelete, options)
{

    if(W.__REQUEST_IN_FLIGHT || W.__REQUEST_QUEUE.length > 0)
    {
        const mssg = `
            There are currently other sync updates being processed.
            Please wait a while for these to be completed and try again.
            (Developers should try to avoid situations where users see this message)
        `;

        alert(mssg);
        return;
    }

    if(idlist.length == 0)
    {
        // alert("No records specified in bulk update, returning");
        return;
    }

    const itemlist = [];
    idlist.forEach(function(myid) {

        massert(W.haveItem(tablename, myid),
            `No record found for ${tablename}::${myid}, please check this condition before calling, quitting`);

        itemlist.push(W.lookupItem(tablename, myid));
    });

    const tablemaster = itemlist[0].__getTableObject();

    var xhr = new XMLHttpRequest();
    xhr.open('POST', W.BULK_UPDATE_URL, true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');

    xhr.onreadystatechange = function() {
        if (xhr.readyState === 4) { // Request is done
            if (xhr.status === 200) {
                const result = JSON.parse(xhr.responseText);
                const message = result['user_message'];
                console.log(message);

                // Notify user code when the update is complete
                // This is actually quite important, because the bulk updates can take longer standard widget sync/delete ops
                if(options != null && "callback" in options)
                {
                    const callback = options["callback"];
                    callback(tablename, idlist, isdelete);
                }

            } else {
                alert(`Bulk update failed with ${xhr.statusText}, please report this message to developer/admin and refresh page`);
            }
        }
    };

    // These table coords are setup in the proper way for the update
    const fullpackage = W.__getTableCoords(tablemaster);
    if(isdelete)
        { fullpackage["delete_id_list"] = idlist.join(","); }
    else
        { fullpackage["bulkpayload"] = JSON.stringify(itemlist); }

    xhr.send(encodeHash2QString(fullpackage));

    // Need to perform all appropriate updates to the local copy of the data
    itemlist.forEach(function(item) {
        if(isdelete)
            { tablemaster._dataMap.delete(item.getId());} 
        else
            { tablemaster.register(item); }
    });
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
        const relpms = v.length > W.MAX_GET_PARAM_VALUE ? combined.biggpms : combined.smllpms;
        relpms[k] = v;
    }

    // Sept 2022 : remove checksum
    // const cksumkey = combined.smllpms["wowner"]+ "::" + combined.smllpms["wname"];
    // const cksumval = W.__databaseCheckSum[cksumkey];
    // combined.smllpms["checksum"] = cksumval;

    return combined;

},



__getTableCoords : function(tablemaster)
{
    return {
        "wowner" : tablemaster.widgetOwner,
        "wname" : tablemaster.widgetName,
        "tablename" : tablemaster.tableName
    };
},


// Create an index on the given table
// fnamelist is a list of field names in the table that you want to index
createIndexForTable : function(tablename, fnamelist)
{

    // Okay there's a carve-out here, in case the data loads have not yet finished
    // If you create a bad index name in the user-include code, you will get an error in 
    // __badIndexCreationCheck below
    if(!W.__DATA_LOAD_COMPLETE)
        { W.__registerTableIndexEntry(tablename);}
    else
        { W.checkTableName(tablename); }

    const indexname = W.__composeInternalIndexName(fnamelist);
    massert(!W.__GLOBAL_INDEX_MAP.get(tablename).has(indexname),
        `You have already defined an index ${fnamelist.join("--")} on table ${tablename}, do not redefine`);

    W.__GLOBAL_INDEX_MAP.get(tablename).set(indexname, new Map());

    // If the table has not yet been registered yet, we're done:
    // The items will be placed in the index when they are registered
    if(!W.getWidgetTableList().includes(tablename))
        { return; }

    // If the table HAS been registered, we need to add the records to the new index
    W.getItemList(tablename).forEach(function(item) {
        W.__placeItemInIndexes(item, [indexname]);
    });
},


// Same as createIndexForTable, but if the index is already present, return early
createIndexIfAbsent : function(tablename, fnamelist)
{
    const indexname = W.__composeInternalIndexName(fnamelist);
    const submap = W.__GLOBAL_INDEX_MAP.get(tablename);
    if(submap != null && submap.has(indexname))
        { return; }

    W.createIndexForTable(tablename, fnamelist);
},


// This is the main exposed API call
// The tablename is a normal Widget tablename
// Lookup is a JS has with K/V pairs corresponding to the query
// Eg to lookup everyone who lives in California, use { state : "CA" } as lookup
// You will get an error if the lookup specifies keys that do not match an index
// (But they do not need to match the WHOLE prefix)
lookupFromIndex : function(tablename, lookup)
{
    const relidx = W.__findRelevantIndex(tablename, lookup);

    massert(relidx != null, `No index found for table ${tablename} and lookup keys ${Object.keys(lookup)}`);

    const mapresult = W.__followIndexFarAsPossible(tablename, relidx, lookup);

    const hits = [];

    W.__recursiveMapLookup(mapresult, hits);

    return hits;
},

__composeInternalIndexName : function(fnamelist)
{
    return fnamelist.join(W.__DUMB_INDEX_DELIM);
},

__findRelevantIndex : function(tablename, lookup)
{
    // Okay, there is no notion of order for a set of lookup keys
    // If you don't write them in the right order, it's not a big deal
    const kcols = [... Object.keys(lookup)].sort();

    const haveallprefs = function(idxname)
    {
        const fnlist = idxname.split(W.__DUMB_INDEX_DELIM).slice(0, kcols.length).sort();

        return fnlist.toString() == kcols.toString();
    }

    // First need to find an index that will be relevant
    const relidxes = [... W.__GLOBAL_INDEX_MAP.get(tablename).keys()].filter(idxname => haveallprefs(idxname));

    return relidxes.length > 0 ? relidxes[0] : null;
},


__recursiveMapLookup : function(themap, resultholder)
{
    if(themap == null)
        { return; }

    [... themap.values()].forEach(function(hit) {

        if(hit instanceof Map)
        {
            W.__recursiveMapLookup(hit, resultholder);
            return;
        }

        resultholder.push(hit);
    });
},


__indexUpdateProcess : function(item, fieldname, ispre)
{
    const hits_index = function(indexname)
    {
        const indexcol = indexname.split(W.__DUMB_INDEX_DELIM);
        return indexcol.includes(fieldname);
    }

    const tablename = item.__getTableObject().tableName;

    // List of indexes that are impacted
    const impacted = [... W.__GLOBAL_INDEX_MAP.get(tablename).keys()].filter(hits_index);

    // Either remove the item (pre) or place the item (post)
    const action = ispre ? W.__removeItemFromIndexes : W.__placeItemInIndexes;

    action(item, impacted);
},


// Note: for these three functions, indexes = null => all indexes for the table
__finalIndexUpdateSub : function(item, updatefunc, indexes)
{
    const tablename = item.__getTableObject().tableName;

    const relidxes = indexes == null ? [... W.__GLOBAL_INDEX_MAP.get(tablename).keys()] : indexes;

    relidxes.forEach(function(idxname) {
        const finalmap = W.__getCreateFinalIndexMap(tablename, idxname, item);
        // Okay, final level is just an ID -> item map
        updatefunc(finalmap);
    });
},

__registerTableIndexEntry : function(tablename)
{
    if(!W.__GLOBAL_INDEX_MAP.has(tablename))
        { W.__GLOBAL_INDEX_MAP.set(tablename, new Map()); }
},

__placeItemInIndexes : function(item, indexes)
{
    const updater = function(fmap) { fmap.set(item.getId(), item); }

    W.__finalIndexUpdateSub(item, updater, indexes);
},

__removeItemFromIndexes : function(item, indexes)
{
    const updater = function(fmap) { fmap.delete(item.getId()); }

    W.__finalIndexUpdateSub(item, updater, indexes);
},


__getCreateFinalIndexMap : function(tablename, indexname, item)
{
    const fnamelist = indexname.split(W.__DUMB_INDEX_DELIM);
    var ptrmap = W.__GLOBAL_INDEX_MAP.get(tablename).get(indexname);

    // follows ptrs down the list of FNames
    fnamelist.forEach(function(fname) {
        const v = item.getField(fname);

        // Set default
        if(!ptrmap.has(v))
            { ptrmap.set(v, new Map()); }

        ptrmap = ptrmap.get(v);
    });

    return ptrmap;
},

__followIndexFarAsPossible : function(tablename, indexname, lookup)
{
    const fnamelist = indexname.split(W.__DUMB_INDEX_DELIM);
    var ptrmap = W.__GLOBAL_INDEX_MAP.get(tablename).get(indexname);

    // follows ptrs down the list of FNames
    fnamelist.forEach(function(fname) {

        if(!lookup.hasOwnProperty(fname) || ptrmap == null)
            { return; }

        const v = lookup[fname];

        ptrmap = ptrmap.get(v);

    });

    // This may be null, a shallow map, or a wide map, caller must understand how to deal with each one
    return ptrmap;
},

__badIndexCreationCheck: function()
{
    const okaylist = W.getWidgetTableList();
    const okaystr = okaylist.join(", ");

    [... W.__GLOBAL_INDEX_MAP.keys()].forEach(function(tablename) {

        massert(okaylist.includes(tablename),
            `Index created for table name ${tablename}, but it has not been loaded, tables are ${okaystr}`);
    });

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

createNewIdBasic : function(datamap)
{
    return W.createNewIdRandom(datamap);
},


// Create a new ID by generating a random integer in the the useable range
// and checking to make sure it is not already in use.
// The useable range is -2147483648 to 2147483647, with an exception for -1000 to 0
createNewIdRandom : function(datamap) 
{
    // Gotcha!! Don't use 'try' as a variable name!!
    //for(var try = 0; try < 10; try++)

    for(var attempt = 0; attempt < 10; attempt++)
    {
        // These numbers are Java Integer MAX_VALUE and MIN_VALUE
        const max =  2147483647;
        const min = -2147483648;
        const newid = Math.floor(Math.random() * (max - min) + min);

        // Reserve this small range for "magic" ID numbers like -1
        if(-1000 <= newid && newid <= 0)
            { continue; }

        if(!datamap.has(newid))
            { return newid; }
    }

    massert(false, "Could not find new unused ID after ten tries, maybe your table is too big, size = " + datamap.size);
},

createNewIdIncremental : function(datamap) 
{
    if(datamap.size == 0) {
        return 1;
    }

    const maxid = [... datamap.keys()].reduce(function(a, b) {
        return Math.max(a, b);
    });
    
    return maxid+1;
},

__submitNewRequest : function(opurl, opname, itemid) 
{
    const reqlist = [opurl, opname, itemid];
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
    const combinedParams = W.__augmentWithCheckSum(reqlist[0]);
    const opurl = W.CALLBACK_URL + "?" + encodeHash2QString(combinedParams.smllpms);

    // console.log(reqlist[0]);
    // console.log(opurl);
    const opname = reqlist[1];
    const itemid = reqlist[2];
    
    var xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
        
        // This block of code is actually called several times before
        // It is ready. readyState == 4 implies the request completed.
        if (this.readyState == 4) {         
            massert(this.status == 200, "Unexpected error code on Ajax operation: " + this.status);
            W.__checkAjaxResponse(opname, itemid, this.responseText);
            W.__REQUEST_IN_FLIGHT = false;


            // This allows user widget to take actions when the sync's finish
            if (typeof ajaxRequestUserCallBack == "function") 
                { ajaxRequestUserCallBack(opurl, opname, itemid); }

            W.__maybeSendNewRequest();
        }
    };

    const havebig = Object.keys(combinedParams.biggpms).length > 0;

    if (havebig) {

        const bigparamstr = encodeHash2QString(combinedParams.biggpms);
        xhttp.open("POST", opurl, true);

        // Send the proper header information along with the request
        xhttp.setRequestHeader('Content-type', 'application/x-www-form-urlencoded');
        xhttp.send(bigparamstr);

    } else {
        xhttp.open("GET", opurl, true);
        xhttp.send();    
    }
},

__checkAjaxResponse : function(op, itemid, rtext)
{
    // console.log(rtext);
    const response = JSON.parse(rtext);
    
    if(response.status_code == "okay")
    {
        const logmssg = `AjaxOp for itemid ${itemid} worked`;
        console.log(logmssg);
        return;     
    }
    
    // Something went wrong, try to give user as informative a message as possible.
    const fcode = response.failure_code;
    const umssg = response.user_message;
    const einfo = response.extra_info;

    // Special error message for this one
    if (fcode == "SyncError")
    {
        const syncmssg = `
            Error: your update was rejected because the widget data has been modified by another user.
            
            Please reload the page and try again.
        `;

        alert(syncmssg);
        throw syncmssg;
    }
    
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








