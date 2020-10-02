

function fastEmpty(mymap)
{
	for(var k in mymap)
		{ return false; }
	
	return true;
}

function sprintf(s, datalist)
{	
	// console.log(s);
	
	massert(datalist.length <= 9, "Cannot currently handle more than 9 sprintf arguments");
	
	// blah I type with my elbows
	s = s.replace(/\{1\}/g, datalist[0]);
	s = s.replace(/\{2\}/g, datalist[1]);	
	s = s.replace(/\{3\}/g, datalist[2]);
	s = s.replace(/\{4\}/g, datalist[3]);
	s = s.replace(/\{5\}/g, datalist[4]);
	s = s.replace(/\{6\}/g, datalist[5]);
	s = s.replace(/\{7\}/g, datalist[6]);
	s = s.replace(/\{8\}/g, datalist[7]);
	s = s.replace(/\{9\}/g, datalist[8]);
	
	return s;	
}

function logpf(s, datalist)
{
	console.log(sprintf(s, datalist));	
}

function buildOptionMap(items, labelfunc)
{
	var optmap = {};
	
	items.forEach(function(itm) {
		const label = labelfunc(itm);
		optmap[itm.getId()] = label;
	});
	
	return optmap;
}

function genericDeleteItem(tablename, itemid)
{
	massert(haveItem(tablename, itemid), 
		"Could not find item " + itemid + " in table " + tablename);
	
	lookupItem(tablename, itemid).deleteItem();
	redisplay();	
}

function genericToggleActive(tablename, itemid)
{
	const theitem = lookupItem(tablename, itemid);
	const newactive = theitem.getIsActive() == 1 ? 0 : 1;
	theitem.setIsActive(newactive);
	syncSingleItem(theitem);
	redisplay();
}

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

// This can be generic
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
		spanel.innerHTML = spanmap[spanid];
	}
}

function okayInt(intstr)
{
	const npint = parseInt(intstr);
	return !isNaN(npint);
}

function okayFloat(floatstr)
{
	const floater = parseFloat(floatstr);
	return !isNaN(floater);
}

__ERRORS_ON_PAGE = 0;

__MAX_ERRORS_PER_PAGE = 3;

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
