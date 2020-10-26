

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

// ----------------
// For Sql2Js

const CALLBACK_URL = "/life/callback";

function getTableCoords(tablemaster)
{
	return {
		"wowner" : tablemaster.widgetOwner,
		"wname" : tablemaster.widgetName,
		"tablename" : tablemaster.tableName
	};
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

function checkAjaxResponse(op, itemid, data)
{
	const response = JSON.parse(data);
	
	// console.log(response);
	
	if(response.status_code == "okay")
	{
		console.log("AjaxOp " + op + " for itemid " + itemid + " worked");	
		return;		
	}
	
	// Something went wrong, try to give user as informative a message as possible.
	const fcode = response.failure_code;
	const umssg = response.user_message;
	alert("Problem with sync operation " + fcode + "\n\n" + umssg);
	return;
}


function syncSingleItem(item)
{
	$.get(item.getUpsertUrl(), function( data ) {
		checkAjaxResponse('sync', item.getPkeyStr(), data);
	});
	
	
}

function deleteSingleItem(item)
{
	$.get(item.getDeleteUrl(), function( data ) {
		checkAjaxResponse('delete', item.getPkeyStr(), data);
	});	
}


