

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

function getItemList(tabname)
{
	var itemfunc = __getListFuncMap[tabname];
	
	massert(itemfunc != null, "No item function found for " + tabname);
	
	return itemfunc();
}

function buildItem(tabname, record)
{
	var buildfunc = __buildItemFuncMap[tabname];
	
	massert(buildfunc != null, "No build function found for " + tabname);
	
	return buildfunc(record);	
}

function newBasicId(tabname)
{
	var idfunc = __newBasicFuncMap[tabname];
	
	return idfunc();	
}

function lookupItem(tabname, k1, k2, k3, k4) 
{
	return __itemLookupFuncMap[tabname](k1, k2, k3, k4);
}

function getHaveItemFunc(tabname)
{
	return __haveItemFuncMap[tabname];	
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


