

// Utility to help with create HTML selectors (drop-down menus)
// Contains a variety of methods to control the data, keys, and displays that are shown in the menu
function OptSelector()
{
    // Key weirdness about HTML option select:
    // the map values are displays, while the keys are the value="..." stuff!!!
    this._keyList = [];
    this._dspList = [];

    // selectOpen sets the select text explicitly
    // attributes sets the K/V map of select opener
    // Only one can be non-null    
    this._selectOpen = null;
    this._myAttributes = null;

    this._selectedKey = "";    
}

// Standard build function for OptSelector
// Use this in preference to new keyword, for fluent coding style.
function buildOptSelector() 
{
    return new OptSelector();
}


// Maintaining the K/V pairing, sort by display values.
OptSelector.prototype.sortByDisplay = function(kdisp)
{
    const pairlist = [];

    for(var idx = 0; idx < this._keyList.length; idx++) 
        { pairlist.push([this._dspList[idx], this._keyList[idx]]); }

    pairlist.sort()

    this._dspList = pairlist.map(pr => pr[0]);
    this._keyList = pairlist.map(pr => pr[1]);
    return this;
}



// Configure the key/values in this selector from a JavaScript Map
// Keys are the interior values, Map values are the display values
OptSelector.prototype.configureFromMap = function(themap)
{
    this.resetData();

    this._keyList = [... themap.keys()];;
    this._dspList = this._keyList.map(k => themap.get(k));

    return this;
}


// Configure the key/values in this selector from single list
// Both interior values and display values are the list elements
OptSelector.prototype.configureFromList = function(thelist)
{
    this.resetData();

    // Gotcha, need to make copies of these, otherwise altering the keyList/dspList
    // will change the underlying list!!
    this._keyList = thelist.slice();
    this._dspList = thelist.slice();

    return this;
}

// Same as configureFromList(...), but use list indexes as the keys
// and list elements for the values, instead of using elements for both
OptSelector.prototype.configureFromIdxList = function(thelist)
{
    this.resetData();

    for(let idx = 0; idx < thelist.length; idx++)
    {
        this._keyList.push(idx);
        this._dspList.push(thelist[idx]);
    }

    return this;
}




// Configure the key/values in this selector from a JavaScript hash/dict
// Interior values are hash keys, display values are hash values
OptSelector.prototype.configureFromHash = function(thehash)
{
    this.resetData();

    this._keyList = [... Object.keys(thehash)];
    this._dspList = this._keyList.map(k => thehash[k]);

    return this;
}




// Sets the keys and values from the given flat list
// In this case keys and values will be the same.
// Deprecated: use configureFromList instead
OptSelector.prototype.setKeyList = function(kdisp)
{
    showLegacyOptApiWarning('setKeyList');

    return this.setKeyDispList(kdisp, kdisp);
}

// Insert a starting pair into the key/display list
// This is useful for creating drop-downs with starter/dummy values that don't do anything
// Often use this AFTER sortByValue
OptSelector.prototype.insertStartingPair = function(kinit, dinit)
{
    this._keyList.splice(0, 0, kinit);
    this._dspList.splice(0, 0, dinit);
    return this;
}

              
// Sets the opening select statement for the selector
// Provide the attributes etc you need for the select here.
OptSelector.prototype.setSelectOpener = function(selopen)
{
    massert(this._myAttributes == null, 
        "You cannot set both the select opener and attributes like Name and onChange");

    this._selectOpen = selopen;
    return this;
}

// Set an Attribute of the select element that will be generated
// Usage of this operation is incompatible with setSelectOpener
OptSelector.prototype.setAttribute = function(attrname, attrval)
{
    massert(this._selectOpen == null, 
        "You cannot set both the select opener and attributes like Name and onChange");

    if(this._myAttributes == null) 
        { this._myAttributes = {}; }


    this._myAttributes[attrname] = attrval;
    return this;
}

// Set the name attribute of the selector
// Shorthand for setAttribute("name", ...)
OptSelector.prototype.setElementName = function(thename)
{
    return this.setAttribute("name", thename);
}

// Set the onChange attribute
// Shorthand for setAttribute("onChange")
// By convention, you are required to include the "javascript:" prefix
OptSelector.prototype.setOnChange = function(funcname)
{
    massert(funcname.startsWith("javascript:"),
        `By convention, input must have javascript: prefix, found ${funcname}, 
        if you don't like this, use setAttribute('onChange', ...`
    );


    if(this._myAttributes != null)
    {
        const previous = this._myAttributes["onChange"];
        massert(previous == null,
            `You have already set the onChange attribute to ${previous}, you cannot reset it`
        );
    }


    return this.setAttribute("onChange", funcname);
}

OptSelector.prototype.getSelectOpener = function()
{
    if(this._selectOpen != null) 
        { return this._selectOpen; }

    const mymap = this._myAttributes == null ? {} : this._myAttributes;

    var selstr = `<select `;

    Object.keys(mymap).forEach(function(k) {
        const v = mymap[k];
        selstr += ` ${k}="${v}" `;
    });

    selstr += ">";
    return selstr;
}


// Smart auto-populate of span (or div) based on naming convention
// To use this, you must set the element name using setElementName
// And you must have a span with the ID=name+"_span"
OptSelector.prototype.autoPopulate = function()
{
    massert(this._myAttributes != null && ("name" in this._myAttributes),
        "To use the auto-populate approach, you must set the element name attribute");

    const spanmap = {};
    spanmap[`${this._myAttributes["name"]}_span`] = this.getHtmlString();

    populateSpanData(spanmap);

    return this;
}





// Sets the key that will be selected by default
// You must set the key list first.
// One of the keys must match the input.
OptSelector.prototype.setSelectedKey = function(skey)
{
    this._selectedKey = skey;
    return this;
}

// Set key/value pairs from the given map.
// Keys will be keys of map, displays will be values.
// Deprecated: this method is misnamed
// Use configureFromMap or configureFromHash instead
OptSelector.prototype.setFromMap = function(optmap)
{
    showLegacyOptApiWarning('setFromMap');


    this.resetData();
    
    for(var k in optmap)
    {
        this._keyList.push(k);
        this._dspList.push(optmap[k]);
    }
    
    return this;
}

// Sets the key/values from the given flat list
// Keys will be INDEXES, values will be items.
// Deprecated: use one of the configureFrom(...) methods instead
OptSelector.prototype.setIndex2DispList = function(dlist)
{

    showLegacyOptApiWarning('setIndex2DispList');


    this.resetData();
    
    for(var idx in dlist)
    {
        this._keyList.push(idx);
        this._dspList.push(dlist[idx]);
    } 
    
    return this;
}


// Sets key/values from given list pair.
// Keys are from first list, values are from second list
// Deprecated: use one of the configureFrom(...) methods instead
OptSelector.prototype.setKeyDispList = function(klist, dlist)
{

    showLegacyOptApiWarning('setKeyDispList');

    
    for(var idx in klist)
    {
        this._keyList.push(klist[idx]);
        this._dspList.push(dlist[idx]);
    }
    
    return this;
}


OptSelector.prototype.getSelectString = function()
{
    console.log("**Warning**, function getSelectString() is deprecated and will be removed in future versions, please use getHtmlString()");
    return this.getHtmlString();
}

// Get the actual full select string for the OptSelector.
// This starts with the select tag and ends with closing select tag.
OptSelector.prototype.getHtmlString = function()
{
    const ostr = this.getFullOptionStr();
    
    return `
        ${this.getSelectOpener()}
        ${ostr}
        </select>
    `;  
}




// Clears the key/value pairs
// this is primarily for internal use, callers should prefer to just
// create a new OptSelector object
OptSelector.prototype.resetData = function()
{
    this._keyList = [];
    this._dspList = [];
}


// Get the full list of options as a flat string
// You can use this if you want to write out the select tags yourself.
OptSelector.prototype.getFullOptionStr = function()
{
    var ss = "";
    
    for(var idx in this._keyList)
    {
        ss += this.getSingleOptionStr(idx)
        ss += "\n";
    }
    
    return ss;
}

// Get the ith option string
OptSelector.prototype.getSingleOptionStr = function(idx)
{
    const k = this._keyList[idx];
    const d = this._dspList[idx];
    
    // Be very careful here. HTML selects don't really preserve types
    const skstring = `${this._selectedKey}`;

    const extra = (`${k}` == skstring) ? " selected " : "";
    
    return `<option value="${k}" ${extra}>${d}</option>`;
}

// Map of Element name to selected KEYS for OptSelector objects that use this feature
const GENERIC_OPT_SELECT_MAP = new Map();

// Configure this select to use a generic update function
// This function will pull the value of the OptSelector into the GENERIC_OPT_SELECT_MAP
// when the selector is changed
// You must provide an element name before calling this function
OptSelector.prototype.useGenericUpdater = function()
{
    massert(this._myAttributes != null && ("name" in this._myAttributes),
        "You must set the element name of the OptSelector before calling useGenericUpdater()");

    const myname = this._myAttributes["name"];
    massert(GENERIC_OPT_SELECT_MAP.has(myname),
        `You must initialize the OptSelector data for ${myname} before creating the selector, place data in GENERIC_OPT_SELECT_MAP`);

    this.setSelectedKey(GENERIC_OPT_SELECT_MAP.get(myname));

    // Need to check that myname is suitable for putting into quotes...
    const jsopt = `javascript:__genericOptSelectorUpdate('${myname}')`

    this.setOnChange(jsopt);

    return this;
}

// Deprecated, just set data in GENERIC_OPT_SELECT_MAP directly
function initGenericSelect(copymap)
{
    [... copymap.keys()].forEach(function(k) {
        GENERIC_OPT_SELECT_MAP.set(k, copymap.get(k));
    });
}

// Deprecated, just access GENERIC_OPT_SELECT_MAP directly
// Big question: is the data in here going to come out of the map with its original types...?
function getGenericSelectValue(k) {
    return GENERIC_OPT_SELECT_MAP.get(k);
}

// Update the GENERIC_OPT_SELECT_MAP from the form value with given name
// The key of the map is the given name
// Also call redisplay()
// This is the method called by OptSelectors that are configured with the useGenericUpdater option
function __genericOptSelectorUpdate(selectname)
{
    const value = getDocFormValue(selectname);
    GENERIC_OPT_SELECT_MAP.set(selectname, value);
    redisplay();
}
