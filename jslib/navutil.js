

// TODO put this in CRM
// http://stackoverflow.com/questions/10834796/validate-that-a-string-is-a-positive-integer
function isNormalInteger(str) {
    return /^\+?\d+$/.test(str);
}

// Copy the fields in the flist to the mainform, then submit it
function nav2main(flist)
{
	
	flist.forEach(function(fname) {
			
			assertFormFieldExists('mainform', fname);	
			assertFormFieldExists('navform', fname);
			
			document.forms.mainform[fname].value = document.forms.navform[fname].value;
	});
	
	document.forms.mainform.submit();
}

function assertFormFieldExists(formname, fieldname)
{
	massert(formname in document.forms, "Form named " + formname + " does not appear to be defined");
	
	massert(document.forms[formname].hasOwnProperty(fieldname), "Property not found in : " + formname + "," + fieldname);
}

function proxySort(proxyfun) 
{
		
	return function(rec1, rec2) {
		
		var tup1 = proxyfun(rec1);
		var tup2 = proxyfun(rec2);
		
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

function local2Pack(locnamelist)
{
	// var pairlist = locnamelist.map(n => "\"" + n + "\": " + n );
	
	var pairlist = locnamelist.map(function(n) { return "\"" + n + "\": " + n; })
	
	return "{ " + pairlist.join(" , ") + " } ";
}



function popOptionMap(selectname, optmap)
{
	var targselect = getUniqElementByName(selectname);
	
	if(targselect.childElementCount >= 1)
		{ return; }
	
	for(var onekey in optmap)
	{
		var opt = document.createElement("option");
			  
		opt.value = optmap[onekey];
		opt.innerHTML = onekey; // whatever property it has
		
		// then append it to the select element
		targselect.appendChild(opt);
	}
}

function getSelectString(optmap, selected)
{
	var sels = "";
	
	for(const k in optmap)
	{
		const label = optmap[k];
		const chooseme = (selected+"") == (k+"") ? " selected " : "";
		
		sels += `
			<option ${chooseme} value="${k}">${label}</option>
		`;
	}
	
	return sels;
}

function hideItem(itemid)
{
    setHidden2Value(itemid, true);
}

function showItem(itemid)
{
    setHidden2Value(itemid, false);
}

function setHidden2Value(itemid, ishidden)
{
    var theitem = document.getElementById(itemid);
    theitem.hidden = ishidden;
}

function toggleHidden(theitem)
{
	theitem.hidden = !theitem.hidden;
}

function toggleHidden4Id(itemid)
{
	var theitem = document.getElementById(itemid);
	toggleHidden(theitem);
}

function toggleHidden4Class(classname)
{
	var clist = document.getElementsByClassName(classname);
	for(var ci in clist)
		{ toggleHidden(clist[ci]); }
}



function setNavData(onekey, oneval)
{
	massert(document.forms.navform.hasOwnProperty(onekey), "Property not found in navform: " + onekey);
	
	document.forms.navform[onekey].value = oneval;	
}

function addBounceBack(subpack)
{
	return addExplicitBounceBack(subpack, window.location.href);	
}

function addExplicitBounceBack(subpack, bounceurl)
{
	subpack.bounceurl = bounceurl;	
	return subpack;	
}

function checkRequiredArgPresent(subpack, arglist)
{
	for(var i in arglist)
	{
		massert(subpack.hasOwnProperty(arglist[i]), "Required argument " + arglist[i] + " not present in subpack");	
		
	}
	
}

function sorryNoUrl()
{
	alert("Sorry, the document URL is missing in this Alpha version of the system. In the full release version, all document URLs will be present. Please try another link."); 	
}

function checkArgListOkay(subpack, reqlist, optlist)
{
	var extlist = ['bounceurl'];
	
	for(var onekey in subpack)
	{
		if(reqlist.indexOf(onekey) > -1)
			{ continue; }
		
		if(optlist.indexOf(onekey) > -1)
			{ continue; }
		
		if(extlist.indexOf(onekey) > -1)
			{ continue; }
		
		massert(false, "SubPack property " + onekey + " is neither optional, required, or extra");
	}
}

function subPackFromForm(formref)
{
	var subpack = {}
	
	for(var i in formref.elements)
	{
		var oneitem = formref.elements[i];
		subpack[oneitem.name] = oneitem.value;
	}
	
	return subpack;
	
}

function subPackFromFormNames(namelist)
{
	var subpack = {}
	
	for(var i in namelist)
		{ subpack[namelist[i]] = getDocFormValue(namelist[i]); }
	
	return subpack;	
}

function addFormValue2Pack(subpack, fieldname)
{
	var str2add = getDocFormValue(fieldname)
	subpack[fieldname] = str2add;
	return subpack;
}


// Builds a subpack from analyzing the caller of the function. 
// So if the function is called from a method called "addNewControl" 
// You will get {"opcode": "addnewcontrol" }
function addOpCodeFromCaller(subpack)
{
	if(subpack === undefined)
		{ subpack = {}; }
	
	var callerfunc = addOpCodeFromCaller.caller.toString();
	
	// console.log("This method was called from " + callerfunc);	
	
	var alphapos = callerfunc.indexOf("function ") + "function ".length;
	
	var omegapos = callerfunc.indexOf("(", alphapos);
	
	funcname = callerfunc.substring(alphapos, omegapos).toLowerCase();
	
	subpack["opcode"] = funcname;
	
	//console.log("Function name is " + funcname);
	
	return subpack;
}



function getUrlParamHash()
{
	var phash = {};
	
	var match,
		pl     = /\+/g,  // Regex for replacing addition symbol with a space
		search = /([^&=]+)=?([^&]*)/g,
		decode = function (s) { return decodeURIComponent(s.replace(pl, " ")); },
		query  = window.location.search.substring(1);

	while (match = search.exec(query))
	{
		phash[decode(match[1])] = decode(match[2]);
	}
	
	return phash;
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

// Old method of submitting operation.
function doGenOp(opinfo)
{
	var subpack = { "opinfo": opinfo };
	submit2Current(subpack);
}


function updateNavInfo(onedocname)
{
	massert(typeof(onedocname) == "string", 
		"Bad type for onedocname, should be string, found " + typeof(onedocname));
	
	
	
	updateNavInfoList([onedocname]);	
}

function updateNavInfoList(docnamelist)
{
	massert(typeof(docnamelist) == "object");
	
	
	// Get the previous information
	var subpack = getUrlParamHash();	
	
	for(var i in docnamelist)
	{
		var oneformname = docnamelist[i];	
		
		var selectlist = document.getElementsByName(oneformname);
		
		massert(selectlist.length == 1, 
			"Found wrong number of elements with name: " + oneformname + " :: " + selectlist.length);
		
		// Overwrite the given value
		subpack[oneformname] = selectlist[0].value;
	}
	
	// Submit
	submit2Base(subpack);
}

// Take the given doc form value and send it directly 
// to submit2Current
function directSubmit2Current(docformname)
{
	var subpack = getUrlParamHash();
	
	subpack[docformname] = getDocFormValue(docformname);
	
	submit2Base(subpack);
}

function getDocFormValue(docformname)
{
	return getUniqElementByName(docformname).value;
}

function getUniqElementByName(elname)
{
	var selectlist = document.getElementsByName(elname);
	
	massert(selectlist.length == 1, 
		"Found wrong number of elements with name: " + elname + " :: " + selectlist.length); 

	return selectlist[0];
	
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


function genOpSubmit(genopurl, submitpack)
{
	var qstr = encodeHash2QString(submitpack);	
	
	var newloc = genopurl + "?" + qstr; 
	
	window.location.href = newloc;	
}

function addExtraInfo(subpack, extrainfo)
{
	subpack.extrainfo = extrainfo;
	return subpack;
}


// These are for filtering pages, see ArgMapFilter
function deleteFilter(killidx)
{
	var subpack = { "opcode": "deletefilter", "killidx" : killidx };
	submit2Current(subpack);
}

function addFilter(filtcode, filtarg)
{
	var subpack = { "opcode": "addfilter", "newkey" : filtcode, "newval" : filtarg };
	submit2Current(subpack);
}

function addFilterDeDup(filtcode, filtarg)
{
	var subpack = { "opcode": "addfilter", "newkey" : filtcode, "newval" : filtarg, "removedup" : true };
	submit2Current(subpack);
}

function smartAddFilter(selname)
{
	var selectel = getUniqElementByName(selname);
	
	addFilter(selectel.name, selectel.value);
}

function smartAddFilterDeDup(selname)
{
	var selectel = getUniqElementByName(selname);

	addFilterDeDup(selectel.name, selectel.value);
}


function promptAddFilter()
{
	var filtcode = prompt("Enter a filter code: ");
	
	var filtarg = prompt("Enter a filter argument: ");
	
	addFilter(filtcode, filtarg);
}







