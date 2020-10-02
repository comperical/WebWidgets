

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
	
	massert(buildfunc != null, "No build function found for " + buildfunc);
	
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
	return "/life/sql2js/AjaxOp.jsp?" + encodeHash2QString(subpack);
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
	return "/life/sql2js/AjaxOp.jsp?" + encodeHash2QString(subpack);	
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

function AjaxOkay(op, itemid)
{
	console.log("AjaxOp " + op + " for itemid " + itemid + " worked");	
}

function checkAjaxResponse(op, itemid, data)
{
	if(data.trim() == "SUCCESS")
	{
		console.log("AjaxOp " + op + " for itemid " + itemid + " worked");	
		return;
	}
	
	if(data.indexOf("DENIED") > -1)
	{
		alert("Ajax operation denied to do credentials problem, please reload page and re-login");
		return;
	}
	
	alert("Unknown error: " + data.trim());
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


