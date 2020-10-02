
function OptSelector()
{
	// Key weirdness about HTML option select:
	// the map values are displays, while the keys are the value="..." stuff!!!
	this._keyList = [];
	this._dspList = [];
	
	this._selectOpen = "<select>";
	this._selectedKey = "";
}

function buildOptSelector() 
{
	return new OptSelector();	
}


// Keys and Displays are the same
OptSelector.prototype.setKeyList = function(kdisp)
{
	return this.setKeyDispList(kdisp, kdisp);
}
              
OptSelector.prototype.setSelectOpener = function(selopen)
{
	this._selectOpen = selopen;
	return this;
}

OptSelector.prototype.resetData = function()
{
	this._keyList = [];
	this._dspList = [];
}


OptSelector.prototype.setSelectedKey = function(skey)
{
	this._selectedKey = skey;
	return this;
}

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



OptSelector.prototype.setKeyDispList = function(klist, dlist)
{
	
	for(var idx in klist)
	{
		this._keyList.push(klist[idx]);
		this._dspList.push(dlist[idx]);
	}
	
	return this;
}


OptSelector.prototype.getSelectString = function()
{
	const ostr = this.getFullOptionStr();
	
	return `
		${this._selectOpen}
		${ostr}
		</select>
	`;
	
	
	
}


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
                     
OptSelector.prototype.getSingleOptionStr = function(idx)
{
	const k = this._keyList[idx];
	const d = this._dspList[idx];
	
	const extra = (k == this._selectedKey) ? " selected " : "";
	
	return `<option value="${k}" ${extra}>${d}</option>`;
}
