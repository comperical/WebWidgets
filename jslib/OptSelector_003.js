
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



// Sets the keys and values from the given flat list
// In this case keys and values will be the same.
OptSelector.prototype.setKeyList = function(kdisp)
{
    return this.setKeyDispList(kdisp, kdisp);
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
    spanmap[`${this._myAttributes["name"]}_span`] = this.getSelectString();

    populateSpanData(spanmap);

    return this;
}




// Clears the key/value pairs
// I'm not sure this should ever actually be used, you can just build a new object
OptSelector.prototype.resetData = function()
{
    this._keyList = [];
    this._dspList = [];
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
OptSelector.prototype.setFromMap = function(optmap)
{
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
OptSelector.prototype.setIndex2DispList = function(dlist)
{
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
OptSelector.prototype.setKeyDispList = function(klist, dlist)
{
    
    for(var idx in klist)
    {
        this._keyList.push(klist[idx]);
        this._dspList.push(dlist[idx]);
    }
    
    return this;
}

// Get the actual full select string for the OptSelector.
// This starts with the select tag and ends with closing select tag.
OptSelector.prototype.getSelectString = function()
{
    const ostr = this.getFullOptionStr();
    
    return `
        ${this.getSelectOpener()}
        ${ostr}
        </select>
    `;  
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
    
    const extra = (k == this._selectedKey) ? " selected " : "";
    
    return `<option value="${k}" ${extra}>${d}</option>`;
}
