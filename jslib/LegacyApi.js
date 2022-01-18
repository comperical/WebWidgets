
// Legacy version of W.getItemList(tabname) in main API
function getItemList(tabname)
{
    W.showRawFunctionWarning("getItemList");
    return W.getItemList(tabname);
}

// Legacy version of W.buildItem(tabname, record) in main API
function buildItem(tabname, record)
{
    W.showRawFunctionWarning("buildItem");
    return W.buildItem(tabname, record); 
}

// Legacy version of W.haveItem(tabname, itemid) in main API
function haveItem(tabname, itemid)
{
    W.showRawFunctionWarning("haveItem");

    return W.haveItem(tabname, itemid);
}

// Legacy version of W.haveTable(tabname) in main API
function haveTable(tabname)
{
    W.showRawFunctionWarning("haveTable");
    return W.haveTable(tabname);
}

// Legacy version of W.lookupItem(tabname, itemid) in main API
function lookupItem(tabname, itemid)
{
    W.showRawFunctionWarning("lookupItem");
    return W.lookupItem(tabname, itemid);
}

// Legacy version of W.getWidgetTableList() in main API
function getWidgetTableList()
{
    W.showRawFunctionWarning("getWidgetTableList");
    return W.getWidgetTableList();
}

// Legacy version of W.newBasicId(tabname) in main API
function newBasicId(tabname)
{
    W.showRawFunctionWarning("newBasicId");
    return W.newBasicId(tabname);
}

// Syncs the given item to the server.
// You must sync every time you create or update a record to persist the changes.
// There is also a convenience method called syncItem attached to the JS object.
function syncSingleItem(item)
{
    console.log(`Warning, function syncSingleItem is deprecated, please use item.syncItem()`)
    W.__submitNewRequest(item.getUpsertUrl(), "sync", item.getPkeyStr());
}

// Deletes the given item from the server.
// You must call this when you want to remove an item to ensure that the delete operation has persisted.
// There is also a convenience method called deleteItem() on the JS object.
function deleteSingleItem(item)
{
    console.log(`Warning, function deleteSingleItem is deprecated, please use item.deleteItem()`)
    W.__submitNewRequest(item.getDeleteUrl(), "delete", item.getPkeyStr());
}
