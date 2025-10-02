

// November 2024: moving forward, general Widget Utility code will go in the U namespace.
const U = {

    // Get a simple string representation of the schema for the given table
    // Or for all tables if the argument is left out
    // This is typically used in development when the programmer wants a quick reminder
    // Of how the underlying tables are designed
    getSchema : function(tablename)
    {
        const protoitem = function(tbl, fieldname)
        {
            const itemlist = W.getItemList(tbl);
            if(itemlist.length > 0)
            {
                return itemlist[0].getField(fieldname);
            }

            const masterob = W.__tableNameIndex.get(tbl);
            return masterob._defaultInfo[fieldname];
        }


        const typestr = function(tbl, fieldname)
        {
            if(fieldname == 'id')
                { return 'int'; }

            const masterob = W.__tableNameIndex.get(tbl);
            const defaultob = protoitem(tbl, fieldname);

            if(defaultob == null)
            {
                return "???";
            }

            if(typeof(defaultob) == typeof("danb"))
            {
                return "string";
            }

            if(typeof(defaultob) == typeof(42))
            {
                if(Number.isInteger(defaultob))
                    { return "int"; }

                return "float";
            }

            U.massert(false, `Unable to determine type of default object ${defaultob}`);
        }

        const db4table = function(tbl)
        {
            return W.__tableNameIndex.get(tbl).widgetName;
        }


        const tablelist = (tablename == null ? W.getWidgetTableList() : [tablename])
                                            .sort(U.proxySort(tbl => [db4table(tbl), tbl]));

        let s = "";

        tablelist.forEach(function(tbl) {

            const dbname = db4table(tbl);

            s += `------\n${dbname}::${tbl}\n`;

            W.getFieldList(tbl).forEach(function(fieldname) {
                const ftype = typestr(tbl, fieldname);
                s += `\t${fieldname} :: ${ftype}\n`;
            });
        });

        return s;
    },


    // Build the schema using the above command and print it to the console
    // Quick helper function for the developer to serve as a reminder for
    // what the table names and types are
    printSchema : function(tablename)
    {
        const myschema = U.getSchema(tablename);
        console.log(myschema);
    },

    // Check if the given table has the given field
    // As of March 2025, this is slowish, we'll keep it private for now until a faster version is available
    __tableHasField : function(tablename, fieldname)
    {
        return W.getFieldList(tablename).includes(fieldname);
    },

    // Perform an action on the record designated with the given table and item ID
    // the action is specified by the updater function
    // This action does not support delete, use genericDeleteItem for that functionality
    // In addition to running the update, also call syncItem on the record and then redisplay()
    genericItemUpdate : function(tablename, itemid, updater)
    {
        massert(W.haveItem(tablename, itemid),
            "Could not find item " + itemid + " in table " + tablename);

        const item = W.lookupItem(tablename, itemid);
        updater(item);
        item.syncItem();
        redisplay();
    },


    // Wrapper around the standard browser prompt(...) primitive,
    // that checks the result for being a valid integer
    promptForInt : function(message, pdefault)
    {
        return U.__promptForTarget(false, message, pdefault);
    },

    // Wrapper around the standard browser prompt(...) primitive,
    // that checks the result for being a valid float
    promptForFloat : function(message, pdefault)
    {
        return U.__promptForTarget(true, message, pdefault);
    },

    __promptForTarget : function(isfloat, message, pdefault)
    {
        const presult = prompt(message, pdefault);

        if(presult == null)
            { return null; }

        const checkfunc = isfloat ? okayFloat : okayInt;
        const parsefunc = isfloat ? parseFloat : parseInt;
        const numberstr = isfloat ? "number" : "integer";

        if(!checkfunc(presult))
        {
            alert(`Please enter a valid ${numberstr}, or hit Cancel`);
            return U.__promptForTarget(isfloat, message, pdefault);
        }

        return parsefunc(presult);
    },


    okayInt : function(s)
    {
        return /^-?\d+$/.test(s.trim());
    },

    okayFloat : function(s)
    {
        // A valid int is also a valid float.
        if(U.okayInt(s))
            { return true; }

        return /^-?\d*\.\d+$/.test(s.trim());
    },


    massert : function(condition, message)
    {
        return massert(condition, message);
    },


    // June 2025, migrating code from the old TimeUtil.js file
    // These methods should move into U... methods for the most part
    // To begin, they will just be pointers to the old methods
    lookupDayCode : function(dcstr)
    {
        return lookupDayCode(dcstr);
    },

    getTodayCode : function()
    {
        return getTodayCode();
    },

    haveDayCodeForString : function(dcstr)
    {
        return haveDayCodeForString(dcstr);
    }


}

// Delete Item from given table. 
// Error if the item with the given ID does not exist.
// Redisplays on success, if you don't want this behavior, do not use this method.
function genericDeleteItem(tablename, itemid)
{
    massert(W.haveItem(tablename, itemid), 
        "Could not find item " + itemid + " in table " + tablename);
    
    W.lookupItem(tablename, itemid).deleteItem();
    redisplay();
}

// Toggles the is_active field of the given item in the given table.
// Item must exist and have an is_active field.
// Syncs and redisplays on success, if you don't want this behavior, do not use this method.
function genericToggleActive(tablename, itemid)
{
    genericToggleField(tablename, "is_active", itemid);
}

// Toggles the given field name for the given item
// Item must have the given field, and the value must be 0/1
// Syncs and redisplays on success, if you don't want this behavior, do not use this method.
function genericToggleField(tablename, fieldname, itemid)
{
    massert(U.__tableHasField(tablename, fieldname), `No field ${fieldname} present for table ${tablename}`);
    const theitem = W.lookupItem(tablename, itemid);
    const curstat = theitem.getField(fieldname);
    const newstat = curstat == 1 ? 0 : 1;
    theitem.setField(fieldname, newstat);
    theitem.syncItem();
    redisplay();
}

// Prompts user to enter a new value for the given text field. 
// The previous value will be used as a prompt default.
// Syncs and redisplays on success, if you don't want this behavior, do not use this method.
function genericEditTextField(tablename, fieldname, itemid)
{
    massert(U.__tableHasField(tablename, fieldname), `No field ${fieldname} present for table ${tablename}`);
    const theitem = W.lookupItem(tablename, itemid);
    const newval = prompt("Please enter a new value for field " + fieldname + ": ", theitem[fieldname]);
    
    if(newval == null)
        { return; }

    theitem[fieldname] = newval;
    theitem.syncItem();
    redisplay();
}

// Same as genericEditIntField, but can be a float/real, instead of just an int
function genericEditFloatField(tablename, fieldname, itemid) 
{
    massert(U.__tableHasField(tablename, fieldname), `No field ${fieldname} present for table ${tablename}`);
    const theitem = W.lookupItem(tablename, itemid);
    const newval = prompt("Please enter a new value for field " + fieldname + ": ", theitem[fieldname]);
    
    if(!newval)
        { return; }


    if(!okayFloat(newval))
    {
        alert("Please enter a valid float");
        return;
    }

    theitem[fieldname] = parseFloat(newval);
    theitem.syncItem();
    redisplay();
}



// Prompts user to enter a new value for the given INT field. 
// The previous value will be used as a prompt default.
// If user enters a non-int, displays an error message and rejects the change.
// Syncs and redisplays on success, if you don't want this behavior, do not use this method.
function genericEditIntField(tablename, fieldname, itemid) 
{
    massert(U.__tableHasField(tablename, fieldname), `No field ${fieldname} present for table ${tablename}`);

    const theitem = W.lookupItem(tablename, itemid);
    const newval = prompt("Please enter a new value for field " + fieldname + ": ", theitem[fieldname]);
    
    if(!newval)
        { return; }


    if(!okayInt(newval))
    {
        alert("Please enter a valid integer");
        return;
    }

    theitem[fieldname] = parseInt(newval);
    theitem.syncItem();
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

        U.massert(Array.isArray(tup1), "The proxy function must return an Array/List, instead it returned " + tup1);
        
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

function dictFromExtractor(itemlist, extractor)
{

    const table = {};

    itemlist.forEach(function(item) {
        const pr = extractor(item);
        U.massert(Array.isArray(pr) && pr.length == 2, "The extractor function must return a length-2 array, got " + pr);
        table[pr[0]] = pr[1];
    })

    return table;
}



// Given map of span ID :: HTML data, 
// Lookup all the spans, and populate them.
function populateSpanData(spanmap)
{
    for(var spanid in spanmap)
    {
        const spanel = document.getElementById(spanid);
        U.massert(spanel != null, `Could not find element with ID ${spanid}`);
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

function __strictIntParseOkayNull(intstr)
{
    return __strictParseOkayNull(intstr, parseInt, 'int');
}

function __strictFloatParseOkayNull(floatstr)
{
    return __strictParseOkayNull(floatstr, parseFloat, 'float');
}

function __strictParseOkayNull(inputstr, parsefunc, typename)
{
    if(inputstr == null)
        { return null; }

    const r = parsefunc(inputstr);
    U.massert(!isNaN(r), `Invalid string for ${typename} : ${inputstr}`);
    return r;
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
    
    U.massert(selectlist.length <= 1, 
        "Found multiple elements with name " + docformname);
    
    return selectlist.length == 0 ? defaultval : selectlist[0].value;
}

// Get the element with the given name.
// Error if there is no element with the given name, or multiple elements.
function getUniqElementByName(elname)
{
    const selectlist = document.getElementsByName(elname);
    
    U.massert(selectlist.length == 1,
        "Found wrong number of elements with name: " + elname + " :: " + selectlist.length); 

    return selectlist[0];
    
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
    U.massert(qstring[0] != '?', "By convention, please strip leading question mark from query string");

    const params = {};
    const pairs = qstring.split("&");

    pairs.forEach(function(prstr) {
        const kv = prstr.split("=");
        U.massert(kv.length == 2, "Found bad key=value string " + prstr);
        params[kv[0]] = decodeURIComponent(kv[1]);
    });

    return params;
}

// Create a query string of the form ?key1=value1&key2=value2 from the given hash.
// This string is suitable for being used to compose a new URL
// by appending it to a prefix such as "https://webwidgets.io/u/dburfoot/mywidget/widget.jsp" + qstring
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


// TODO: this should be fixed, submitpack must overwrite the previously selected params
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


// Set a cookie with the given name=value pair
function setCookieNoExpiration(name, value) {
    const cookiestr = `${name}=${value}; path=/`;
    // document.cookie = name + "=" + value + expires + "; path=/";
    document.cookie = cookiestr;
}


// Returns full set of document cookies.
function getDocumentCookieInfo()
{
    const cookies = {}

    document.cookie.split(";").forEach(function(cstr) {

        const pairtoks = cstr.trim().split("=");

        if(pairtoks.length != 2)
            { return; }

        cookies[pairtoks[0]] = pairtoks[1];
    });

    return cookies;
}



// Return username of logged-in user
// This is pulled from the full cookie package
function getWidgetUserName()
{
    const result = U.getDocumentCookieInfo()['username'];
    return result == null || result == "" ? null : result;
}


// This implements a basic logout operation by clearing the user's WWIO-relevant cookies
// If the application has set additional cookies, it must implement clearing logic on its own
function basicWidgetLogout()
{
    // setCookieNoExpiration("username", "");
    // setCookieNoExpiration("accesshash", "");
    U.logoutWithBounceBack(null);
}

// Log out of Widgets and bounce-back to current url
function logoutAndReturn()
{
    U.logoutWithBounceBack(window.location.href);
}

function logoutWithBounceBack(bounceback)
{
    var lourl = "/u/admin/LogOut.jsp"

    if(bounceback != null)
    {
        const encbounce = encodeURIComponent(bounceback);
        lourl += "?bounceback=" + encbounce;
    }

    window.location.href = lourl;
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


function populateTopNavBar(headerdata, headerselected) {

    const data = composeNavBarCode(headerdata, headerselected);

    const topnavlist = document.getElementsByClassName("topnav");

    U.massert(topnavlist.length >  0, "Could not find any elements with class name topnav");
    U.massert(topnavlist.length == 1, "Found multiple elements with class name topnav");

    topnavlist[0].innerHTML = data;

}

function composeNavBarCode(headerdata, headerselected) {

    var navstr = `<a href="/u/admin/Bounce2Home.jsp">Home</a>`;
    var foundsel = false;

    headerdata.forEach(function(pr) {

        const display = pr[0];
        const href = pr[1];
        var selstr = "";

        if(headerselected == display) {

            foundsel = true;
            selstr = `class="navbar_active"`;
        }

        navstr += `<a href="${href}" ${selstr}>${display}</a>`;
    });

    U.massert(foundsel || headerselected == null,
        `Failed to find header named ${headerselected}, use null if you don't want to select`);

    return navstr;

}

function showLegacyOptApiWarning(funcname)
{
    if (W.__RAW_DEP_WARNING_COUNT < 3) {
        console.log(`**Warning**, use of old OptSelector function ${funcname} is deprecated and will be removed in a future version, please use configureFrom(...) methods`);
    }

    W.__RAW_DEP_WARNING_COUNT++;
}



// Legacy bridge code. We are moving these methods into the U namespace.
// You should call them from the U namespace moving forward.
// If a function is not on this list, it is deprecated!
const _RAW_FUNCTION_LIST = {
    genericEditIntField,
    genericEditFloatField,
    genericEditTextField,
    genericToggleField,
    genericToggleActive,
    genericDeleteItem,
    proxySort,
    basicWidgetLogout,
    logoutAndReturn,
    logoutWithBounceBack,
    getWidgetUserName,
    getDocumentCookieInfo,
    setCookieNoExpiration,
    submit2Current,
    submit2Base,
    decodeQString2Hash,
    encodeHash2QString,
    getUrlParamHash,
    getUniqElementByName,
    getDocFormValueDefault,
    getDocFormValue,
    populateSpanData,
};

// Copy them into U
for (const [name, fn] of Object.entries(_RAW_FUNCTION_LIST)) {

    if (U[name] == null) {   // only copy if U doesn’t already have it
        U[name] = fn;
    } else {
        console.warn(`U already has ${name}, skipping legacy bridge`);
    }
}

