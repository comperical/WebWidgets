
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

// Set the page component to the selected ID.
// This is used to enable SPA-style behavior.
// The code looks up all of the elements with the "page_component" class. 
// Then it marks the component as hidden unless it's ID matches the argument ID. 
function setPageComponent(selectedid)
{
    // Warning: this might be non-compliant for old browsers.
    const complist = Array.from(document.getElementsByClassName("page_component"));
    
    complist.forEach(function(citem) {
        
        if(citem.id != selectedid)
        {
            citem.hidden = true;
            return;
        }
    
        citem.hidden = false;
        foundit = true;
    });
    
    massert(foundit, "Failed to find page_component element with ID " + selectedid);
}

// Hide element with given ID
function hideItem(itemid)
{
    setHidden2Value(itemid, true);
}

// Show (= un-hide) element with given ID.
function showItem(itemid)
{
    setHidden2Value(itemid, false);
}

// Set the hidden property of element with given ID to true/false argument.
function setHidden2Value(itemid, ishidden)
{
    var theitem = document.getElementById(itemid);
    theitem.hidden = ishidden;
}

// Toggle Hidden value for given element.
function toggleHidden(theitem)
{
    theitem.hidden = !theitem.hidden;
}

// Toggle Hidden value for element with given ID.
function toggleHidden4Id(itemid)
{
    var theitem = document.getElementById(itemid);
    toggleHidden(theitem);
}

// Toggle Hidden value for all elements with given class.
function toggleHidden4Class(classname)
{
    var clist = document.getElementsByClassName(classname);
    for(var ci in clist)
        { toggleHidden(clist[ci]); }
}




