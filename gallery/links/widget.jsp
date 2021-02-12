
<%@include file="../../admin/AuthInclude.jsp_inc" %>

<html>
<head>
<title>Link Manager</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

<script>

var EDIT_STUDY_ITEM = -1;

var STUDY_CATEGORY = false;

var SEARCH_TERM = "goog";

massert(getItemList("link_categ").length > 0,
	"You must add some link categories by hand first!!");

var MAIN_CATEGORY = getItemList("link_categ")[0].getId();

function createNew()
{
	const newid = newBasicId("link_main");
	const categid = MAIN_CATEGORY;
		
	const newrec = {
		"id": newid,
		"link_url" : "http://danburfoot.net",
		"short_desc" : "NotYetSet",
		"cat_id" : categid
	};
	
	var newlinkitem = buildItem("link_main", newrec);		
	newlinkitem.registerNSync();	
	editStudyItem(newid);
}

function createNewCategory()
{
	const newcat = prompt("Please enter a name for this category : ");
	if(newcat)
	{
		const newid = newBasicId("link_categ");
		const newrec = {
			"id": newid,
			"short_code" : newcat,
			"full_desc" : "...",
			"is_active" : 1
		};
		
		const newitem = buildLinkCategItem(newrec);		
		newitem.registerNSync();
		redisplay();
	}
}

function deleteItem(killid)
{
	if(confirm("Are you sure you want to delete item " + killid + " ?"))
	{
		lookupItem("link_main", killid).deleteItem();
		redisplay();
	}
}

function deleteCategory(killcateg)
{
	const victim = lookupItem("link_categ", killcateg);
	
	if(confirm("Are you sure you want to delete category " + victim.getShortCode() + "?"))
	{
		victim.deleteItem();
		redisplay();
	}	
}

function getLinkCategMap()
{
	var catmap = {};
	
	var catlist = getItemList("link_categ");
	
	catlist.forEach(ci => catmap[ci.getShortCode()] = ci.getId() );

	return catmap;
}

function editStudyItem(itemid)
{
	EDIT_STUDY_ITEM = itemid;	
	redisplay();
}

function return2Main()
{
	STUDY_CATEGORY = false;
	editStudyItem(-1);
}

function studyCategoryInfo()
{
	STUDY_CATEGORY = true;
	redisplay();
}

function getEditRecord()
{
	const itemlist = getItemList("link_main").filter(rec => rec.getId() == EDIT_STUDY_ITEM);
	return itemlist[0];			
}

function getCategoryMap()
{	
	// Okay, this sorting doesn't come out in the final drop-down,
	// because it goes through the intermediate map 
	const categlist = getItemList("link_categ")
				.filter(ctg => ctg.getIsActive() == 1)
				.sort(proxySort(ctg => [ctg.getShortCode()]));
	
	// console.log(categlist);
	
	return buildOptionMap(
		categlist,
		itm => itm.getShortCode()
	);
}

function editShortDesc()
{
	editFieldName("short_desc");
}

function editLinkUrl()
{
	editFieldName("link_url");	
}

function editFieldName(fname)
{
	const edititem = getEditRecord();
	
	var newinfo = prompt("Please enter a new " + fname + " for this record:", edititem[fname]);
	
	if(newinfo)
	{
		edititem[fname] = newinfo;
		syncSingleItem(edititem);
		redisplay();
	}
}

function reDoSearch()
{
	const newsearch = prompt("Search for: ", SEARCH_TERM);

	if(newsearch) 
	{
		SEARCH_TERM = newsearch.toLowerCase();
		redisplay();
	}
}

function clearSearch()
{
	SEARCH_TERM = "";
	redisplay();
}



function updateCategory()
{
	const edititem = getEditRecord();
	const myval = getDocFormValue("item_category_sel");		
	edititem["cat_id"] = myval;
	syncSingleItem(edititem);
	redisplay();
}

function redisplay()
{
	redisplayMainTable();	
	redisplayEditItem();
	redisplayCategoryTable();
	redisplaySearchTable();

	setPageComponent(getPageComponent());
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

function getPageComponent()
{
	if(EDIT_STUDY_ITEM != -1)
		{ return "link_info"; }

	if(STUDY_CATEGORY)
		{ return "category_info"; }
	
	if(SEARCH_TERM.length > 0)
		{ return "link_search"; }

	return "link_manager";
}

function redisplayEditItem()
{
	if(EDIT_STUDY_ITEM == -1)
		{ return; }
	
	const edititem = getEditRecord();
	const optmap = getCategoryMap();
	const selectstr = getSelectString(optmap, edititem.getCatId());
	
	const spanstr = `
		<select name="item_category_sel" onChange="javascript:updateCategory()">
		${selectstr}
		</select>
	`;
	
	populateSpanData({
		"item_id" : edititem.getId(),
		"short_desc" : edititem.getShortDesc(),
		"link_url" : edititem.getLinkUrl(), 
		"item_category_sel_span" : spanstr
	});
		
	const opsel = getUniqElementByName("item_category_sel");
	opsel.value = edititem.getCatId();
}

function redisplayCategoryTable()
{
	var s = `
		<table class="dcb-basic" id="dcb-basic" width="40%">
		<tr>
		<th>ID</th>
		<th>Category</th>
		<th>NumLinks</th>
		<th>Active?</th>
		<th>...</th>
		</tr>
	`;
	
	var countmap = {};
	
	getItemList("link_main").forEach(function(litem) {
	
		if(!(litem.getCatId() in countmap))
			{ countmap[litem.getCatId()] = 0; }
		
		countmap[litem.getCatId()] += 1;
	});
	
	var categorylist = getItemList("link_categ").sort(proxySort(c => [c.getShortCode()]));
	
	categorylist.forEach(function(categ) {
		
		const active = categ.getIsActive() == 1 ? "YES" : "NO";
		
		const numhit = categ.getId() in countmap ? countmap[categ.getId()] : 0;
			
		const removeop = `
			<a href="javascript:deleteCategory(${categ.getId()})">
			<img src="/life/image/remove.png" height="18"></a>
		`;
		
		const toggleop = `
			<a href="javascript:genericToggleActive('link_categ', ${categ.getId()})">
			<img src="/life/image/cycle.png" height="18"></a>		
		`;
		
		const op2display = numhit == 0 ? removeop : toggleop;
		
		const rowstr = `
			<tr>
			<td>${categ.getId()}</td>
			<td>${categ.getShortCode()}</td>
			<td width="10%">${numhit}</td>
			<td width="10%">${active}</td>
			<td>${op2display}</td>
			</tr>
		`;
		
		s += rowstr;
	});
	
	s += "</table>";

	document.getElementById("categorytable").innerHTML = s;
	
}

function updateMainCatSelect()
{
	MAIN_CATEGORY = getDocFormValue("main_category_sel");
	redisplay();
}

// TODO: put this in a generic file...?
function buildOptionMap(items, labelfunc)
{
	var optmap = {};

	items.forEach(function(itm) {
		const label = labelfunc(itm);
		optmap[itm.getId()] = label;
	});

	return optmap;
}

// TODO: this is the old way of dynamic JS dropdown creation, update to new way
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

function getLinkTableStr(linkmainlist)
{
	var tablestr = `
		<table class="dcb-basic" id="dcb-basic" width="70%">
		<tr>
		<th>ID</th>
		<th>Category</th>
		<th>ShortDesc</th>
		<th>Link</th>
		<th>---</th>
		</tr>
	`;
						
		
	linkmainlist.forEach(function(linkitem) {
		
		var shorturl = linkitem.getLinkUrl();
		if(shorturl.length > 40)
			{ shorturl = shorturl.substring(0, 40)+"..."; }		
		
		const categitem = lookupItem("link_categ", linkitem.getCatId());

		tablestr += `
			<tr>
			<td>${linkitem.getId()}</td>
			<td>${categitem.getShortCode()}</td>
			<td>${linkitem.getShortDesc()}</td>
			<td>
			<a href="${linkitem.getLinkUrl()}">
			${shorturl}
			</a>
			</td>
			<td>
			<a href="javascript:editStudyItem(${linkitem.getId()})">
			<img src="/life/image/inspect.png" height="18"></a>
			
			&nbsp;&nbsp;
			
			<a href="javascript:deleteItem(${linkitem.getId()})">
			<img src="/life/image/remove.png" height="18"></a>
			
			</td>
			</tr>
		`;
	});
	
	return tablestr;
}


function redisplayMainTable()
{		
	{
		const optmap = getCategoryMap();
		const options = getSelectString(optmap, MAIN_CATEGORY);
		const selectstr = `
			<select name="main_category_sel" onChange="javascript:updateMainCatSelect()">
			${options}
			</select>
		`;
		
		document.getElementById("main_category_sel_span").innerHTML = selectstr;
	}
	
	const linkmainlist = getItemList("link_main").filter(lmi => lmi.getCatId() == MAIN_CATEGORY);

	const tablestr = getLinkTableStr(linkmainlist);

	populateSpanData({"maintable" : tablestr });
}



function redisplaySearchTable() {

	if(SEARCH_TERM.length == 0) {
		return;
	}



	const searchlist = getItemList("link_main").filter(lmi => lmi.getShortDesc().toLowerCase().indexOf(SEARCH_TERM) > -1);

	const tablestr = getLinkTableStr(searchlist);

	populateSpanData({
		"searchtable" : tablestr,
		"search_result" : SEARCH_TERM
	});
}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<span class="page_component" id="link_manager">

<h3>Link Manager</h3>

Category: 
<span id="main_category_sel_span"></span>

&nbsp; 
&nbsp; 

<a href="javascript:studyCategoryInfo()"><button>categories</button></a>

<br/><br/>


&nbsp; 
&nbsp; 

<a href="javascript:reDoSearch()"><button>search</button></a>

<br/>
<br/>

<div id="maintable"></div>

<br/>


<a class="css3button" href="javascript:createNew()">NEW</a>


</span>


<span class="page_component" id="link_search">



<h3>Link Search</h3>

<br/><br/>

<table id="dcb-basic" class="dcb-basic" width="30%">
<tr>
<td width="50%">Search Term</td>
<td><span id="search_result"></span></td>
</tr>
</table>

<br/>

<a href="javascript:reDoSearch()"><button>re-search</button></a>

&nbsp;
&nbsp;

<a href="javascript:clearSearch()"><button>clear</button></a>


<br/>
<br/>

<div id="searchtable"></div>

</span>

<span class="page_component" id="link_info">

<h2>Link Info</h2>

<table id="dcb-basic" width="50%">
<tr>
<td>Back</td>
<td></td>
<td><a name="back_url" href="javascript:return2Main()"><img src="/life/image/leftarrow.png" height="18"/></a></td>
</tr>
<tr>
<td>ID</td>
<td><span id="item_id"></span></td>
<td></td>
</tr>
<tr>
<td>Desc</td>
<td><span id="short_desc"></span></td>
<td><a href="javascript:editShortDesc()"><img src="/life/image/edit.png" height="18"/></a></td>
</tr>
<tr>
<td>Link</td>
<td><span id="link_url"></span></td>
<td><a href="javascript:editLinkUrl()"><img src="/life/image/edit.png" height="18"/></a></td>
</tr>
<tr>
<td>Category</td>
<td>
<span id="item_category_sel_span"></span>

</td>
<td></td>
</tr>

</table>

</span>


<span class="page_component" id="category_info">

<h3>Link Categories</h3>


<br/>

<a class="css3button" href="javascript:createNewCategory()">NEW</a>

&nbsp;
&nbsp;
&nbsp;

<a class="css3button" href="javascript:return2Main()">BACK</a>


<br/>
<br/>

<div id="categorytable"></div>

</span>


</span>





</center>
</body>
</html>
