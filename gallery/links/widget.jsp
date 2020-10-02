
<%@ page import="java.util.*" %>


<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>


<%@ page import="lifedesign.basic.*" %>
<%@ page import="lifedesign.classic.*" %>
<%@ page import="lifedesign.classic.JsCodeGenerator.*" %>

<%@include file="../../life/AuthInclude.jsp_inc" %>

<%
	ArgMap argMap = HtmlUtil.getArgMap(request);
	
	OptSelector ratingSel = new OptSelector(Util.range(1, 10));
	
	DayCode todayCode = DayCode.getToday();
	
	List<DayCode> dayList = DayCode.getDayRange(todayCode.nDaysBefore(30), 35);
	
	OptSelector dayListSel = new OptSelector(dayList);
	
%>

<html>
<head>
<title>Link Manager</title>

<%@include file="../../life/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

<script>

var EDIT_STUDY_ITEM = -1;

var STUDY_CATEGORY = false;

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
	
	var newlinkitem = buildLinkMainItem(newrec);		
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
	
	return "link_manager";
}

function redisplayEditItem()
{
	if(EDIT_STUDY_ITEM == -1)
		{ return; }
	
	var edititem = getEditRecord();
	
	$('#item_id').html(edititem.getId());
	
	$('#short_desc').html(edititem.getShortDesc());
	
	$('#link_url').html(edititem.getLinkUrl());

	const optmap = getCategoryMap();
	const selectstr = getSelectString(optmap, edititem.getCatId());
	
	const spanstr = `
		<select name="item_category_sel" onChange="javascript:updateCategory()">
		${selectstr}
		</select>
	`;

	$('#item_category_sel_span').html(spanstr);
	
	// const optmap = getCategoryMap();
	// popOptionMap("category_sel", optmap);
	
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
	
	var linktable = $('<table></table>').addClass('dcb-basic').attr("id", "dcb-basic").attr("width", "70%");
	
	{
		var row = $('<tr></tr>').addClass('bar');
	
		["ID", "Category", "ShortDesc", "Link", "---"].forEach( function (hname) {
		
			row.append($('<th></th>').text(hname));
		});
		
		linktable.append(row);	
	}
		
	var linkmainlist = getItemList("link_main");
	
	
	var trcomposer = (new ComposerTool())
				.append("<tr>")
				.append("<td>{1}</td>")
				.append("<td>{2}</td>")
				.append("<td>{3}</td>")
				.append("<td><a href=\"{4}\">{5}</a></td>")
				.append("<td width=\"10%\">{6}</td>")
				.append("</tr>");
				
	var opcomposer = (new ComposerTool())
				.append("<a href=\"javascript:editStudyItem({1})\"><img src=\"/life/image/inspect.png\" height=\"18\"></a>")
				.append("&nbsp;&nbsp;&nbsp;")
				.append("<a href=\"javascript:deleteItem({1})\"><img src=\"/life/image/remove.png\" height=\"18\"></a>");
				
				
	const categitem = lookupItem("link_categ", MAIN_CATEGORY);
		
	for(var lmi in linkmainlist)
	{
		const linkitem = linkmainlist[lmi];
		if(linkitem.getCatId() != MAIN_CATEGORY)
			{ continue; }
						
		var opstuff = opcomposer.listFormat([linkitem.getId()]);
		
		var shorturl = linkitem.getLinkUrl();
		
		if(shorturl.length > 40)
			{ shorturl = shorturl.substring(0, 40)+"..."; }
		
		var datalist = [linkitem.getId(), categitem.getShortCode(), linkitem.getShortDesc(),  linkitem.getLinkUrl(), shorturl, opstuff];
			
		linktable.append(trcomposer.listFormat(datalist));
	}
	

	$('#linktable').html(linktable);
	
}





</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<span class="page_component" id="link_manager">

<h3>Link Manager</h3>

Category: 
<span id="main_category_sel_span"></span>

--- <a href="javascript:studyCategoryInfo()">view</a>

<br/><br/>

<a class="css3button" href="javascript:createNew()">NEW</a>


<br/>
<br/>

<div id="linktable"></div>

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
