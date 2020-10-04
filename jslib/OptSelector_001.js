
function OptSelector()
{
	// Key weirdness about HTML option select:
	// the map values are displays, while the keys are the value="..." stuff!!!
	this._keyList = [];
	this._dspList = [];
	
	this._selectOpen = "<select>";
	this._selectedKey = "";
}

// Standard build function for OptSelector
// Use this in preference to new keyword, for fluent coding style.
function buildOptSelector() 
{
	return new OptSelector();	
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
	this._selectOpen = selopen;
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
		${this._selectOpen}
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
