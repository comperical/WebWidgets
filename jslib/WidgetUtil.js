

// Fast check to determine if the given map is empty.
// This is a weird JS thing.
function fastEmpty(mymap)
{
    for(var k in mymap)
        { return false; }
    
    return true;
}

// Delete Item from given table. 
// Error if the item with the given ID does not exist.
function genericDeleteItem(tablename, itemid)
{
    massert(haveItem(tablename, itemid), 
        "Could not find item " + itemid + " in table " + tablename);
    
    lookupItem(tablename, itemid).deleteItem();
    redisplay();    
}

// Toggles the is_active field of the given item in the given table.
// Item must exist and have an is_active field.
// Syncs and redisplays on success, if you don't want this behavior, do not use this method.
function genericToggleActive(tablename, itemid)
{
    const theitem = lookupItem(tablename, itemid);
    const newactive = theitem.getIsActive() == 1 ? 0 : 1;
    theitem.setIsActive(newactive);
    syncSingleItem(theitem);
    redisplay();
}

// Prompts user to enter a new value for the given text field. 
// The previous value will be used as a prompt default.
// Syncs and redisplays on success, if you don't want this behavior, do not use this method.
function genericEditTextField(tablename, fieldname, itemid)
{
    const theitem = lookupItem(tablename, itemid);
    const newval = prompt("Please enter a new value for field " + fieldname + ": ", theitem[fieldname]);
    
    if(newval)
    {
        theitem[fieldname] = newval;
        syncSingleItem(theitem);
        redisplay();
    }
}

// Prompts user to enter a new value for the given INT field. 
// The previous value will be used as a prompt default.
// If user enters a non-int, displays an error message and rejects the change.
// Syncs and redisplays on success, if you don't want this behavior, do not use this method.
function genericEditIntField(tablename, fieldname, itemid) 
{
    const theitem = lookupItem(tablename, itemid);
    const newval = prompt("Please enter a new value for field " + fieldname + ": ", theitem[fieldname]);
    
    if(!newval)
        { return; }


    if(!okayInt(newval))
    {
        alert("Please enter a valid integer");
        return;
    }

    theitem[fieldname] = newval;
    syncSingleItem(theitem);
    redisplay();
}

// returns the item in the collection that has the minimum
// value according to the given function.
function minWithProxy(items, minfunc)
{   
    var minitem = null;
    var minrslt = null;
    
    items.forEach(function(it) {
        
        const newrslt = minfunc(it);
        
        if(minitem == null || newrslt < minrslt)
        {
            minitem = it;
            minrslt = newrslt;
        }
    });
    
    return minitem;
}

// This is a higher order function: the input and return values are both functions.
// It converts a function of one variable into a binary function that can be used to compare the variables.
// Call with mylist.sort(proxyFun(x => [x.getId(), x.getName()]))
function proxySort(proxyfun) 
{
        
    return function(rec1, rec2) {
        
        var tup1 = proxyfun(rec1);
        var tup2 = proxyfun(rec2);

        massert(Array.isArray(tup1), "The proxy function must return an Array/List, instead it returned " + tup1);
        
        for(var i in tup1)
        {
            var x1 = tup1[i];
            var x2 = tup2[i];
            
            if(x1 != x2)
                { return x1 < x2 ? -1 : +1; }
        }
        
        return 0;
    }
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

// Given map of span ID :: HTML data, 
// Lookup all the spans, and populate them.
function populateSpanData(spanmap)
{
    for(var spanid in spanmap)
    {
        const spanel = document.getElementById(spanid);
        massert(spanel != null, `Could not find element with ID ${spanid}`);
        spanel.innerHTML = spanmap[spanid];
    }
}

// Checks if the given input is an allowable Integer.
// Return true if yes.
function okayInt(intstr)
{
    return /^-?\d+$/.test(intstr.trim());
}

// Return true if the given string is an allowable float.
function okayFloat(floatstr)
{
    // A valid int is also a valid float.
    if(okayInt(floatstr))
        { return true; }

    return /^-?\d*\.\d+$/.test(floatstr.trim());
}

__ERRORS_ON_PAGE = 0;

__MAX_ERRORS_PER_PAGE = 3;

// Assert that the given condition is true.
// If not, alert prompt is shown with the provided error message, as well as some info about the number of errors.
// CAUTION - want to avoid showing the user an infinite number of prompts, that's why we keep track of 
// the __ERRORS_ON_PAGE info.
function massert(condition, message)
{
    if (!condition) {
        
        __ERRORS_ON_PAGE += 1;
        
        const mssg = message || "Assertion failed";
        
        const alertmssg = `
Encountered the following error:

>> ${mssg}

This is error ${__ERRORS_ON_PAGE}; only the first ${__MAX_ERRORS_PER_PAGE} will be shown.

If you are the admin, please fix the error; if you are a user, please contact admin.
`;
        
        if(__ERRORS_ON_PAGE <= __MAX_ERRORS_PER_PAGE)
        {
            alert(alertmssg);
        }
        
        console.log("Error: " + mssg);
        throw mssg;
    }
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

// Get the VALUE of the form element with the given NAME.
// Error if there is no element with the given name, or multiple elements.
function getDocFormValue(docformname)
{
    return getUniqElementByName(docformname).value;
}

// Get the value of the document form with the given name,
// or return the default value if there are no elements with that name.
// Error if there are multiple elements with name.
function getDocFormValueDefault(docformname, defaultval)
{
    const selectlist = document.getElementsByName(docformname);
    
    massert(selectlist.length <= 1, 
        "Found multiple elements with name " + docformname);
    
    return selectlist.length == 0 ? defaultval : selectlist[0].value;
}

// Get the element with the given name.
// Error if there is no element with the given name, or multiple elements.
function getUniqElementByName(elname)
{
    var selectlist = document.getElementsByName(elname);
    
    massert(selectlist.length == 1, 
        "Found wrong number of elements with name: " + elname + " :: " + selectlist.length); 

    return selectlist[0];
    
}

// Get Query String / URL Params as a hash.
// Example MyWidget.jsp?name=1&id=5 will return
// { "name" : 1, "id" : 5}
function getUrlParamHash___XXX()
{
    return getUrlParamHash(window.location.search.substring(1));
}

// Get Query String / URL Params as a hash.
// Example MyWidget.jsp?name=1&id=5 will return
// { "name" : 1, "id" : 5}
function getUrlParamHash()
{
    var phash = {};
    
    var match,
        pl     = /\+/g,  // Regex for replacing addition symbol with a space
        search = /([^&=]+)=?([^&]*)/g,
        decode = function (s) { return decodeURIComponent(s.replace(pl, " ")); },
        query = window.location.search.substring(1);

    while (match = search.exec(query))
    {
        phash[decode(match[1])] = decode(match[2]);
    }
    
    return phash;
}


// Simple transform of a query string, without the leading ?, into a key=value pair
// Should be a pure inverse of encodeHash2QString below.
function decodeQString2Hash(qstring)
{
    massert(qstring[0] != '?', "By convention, please strip leading question mark from query string");

    const params = {};
    const pairs = qstring.split("&");

    pairs.forEach(function(prstr) {
        const kv = prstr.split("=");
        massert(kv.length == 2, "Found bad key=value string " + prstr);
        params[kv[0]] = decodeURIComponent(kv[1]);
    });

    return params;
}

function encodeHash2QString(submitpack)
{
    var qlist = new Array();
    
    for (var key in submitpack) {
        if (submitpack.hasOwnProperty(key)) {
            qlist.push(key + "=" + encodeURIComponent(submitpack[key]));
        }
    }

    return qlist.join("&");     
}

function submit2Base(submitpack)
{
    var qlist = new Array();
    
    for (var key in submitpack) {
        if (submitpack.hasOwnProperty(key)) {
            qlist.push(key + "=" + encodeURIComponent(submitpack[key]));
        }
    }

    var qstr = qlist.join("&"); 
    
    var newloc = window.location.origin + window.location.pathname + "?" + qstr;
    
    window.location.href = newloc;  
}


function submit2Current(submitpack)
{
    var qlist = new Array();
    
    for (var key in submitpack) {
        if (submitpack.hasOwnProperty(key)) {
            qlist.push(key + "=" + encodeURIComponent(submitpack[key]));
        }
    }

    var qstr = qlist.join("&"); 
    
    var winurl = window.location.href;
    
    if(winurl.search("#") > 0)
    {
        winurl = winurl.substr(0, winurl.search("#"));
    }
    
    
    var haveq = window.location.href.search("\\?") > 0;
    
    var newloc = winurl + (haveq ? "&" : "?") + qstr; 
    
    window.location.href = newloc;
}
