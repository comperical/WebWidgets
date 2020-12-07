
<%@include file="../../admin/AuthInclude.jsp_inc" %>

<html>
<head>
<title>Rage Log</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

<script>

var EDIT_STUDY_ITEM = -1;

function createNew()
{
	const shortname = prompt("ENRAGED about what?? : ");
	
	if(shortname)
	{
		const newid = newBasicId("rage_log");
		const todaycode = getTodayCode().getDateString();
		
		// created_on, active_on, completed_on, dead_line
		const newrec = {
			"id" : newid,
			"short_name" : shortname,
			"category": 'misc',
			"full_desc": "NotYetSet",
			"day_code" : todaycode		
		};		
		
		const newitem = buildItem("rage_log", newrec);
		newitem.registerNSync();
		redisplay();
	}
}

function deleteItem(killid, shortname)
{
	if(confirm("Are you sure you want to delete item " + shortname + "?"))
	{
		lookupItem("rage_log", killid).deleteItem();
		
		redisplay();
	}
}

function editStudyItem(itemid) 
{
	EDIT_STUDY_ITEM = itemid;
	redisplay();
}

function editShortName()
{
	genericEditTextField("rage_log", "short_name", EDIT_STUDY_ITEM);
}

function back2Main()
{
	EDIT_STUDY_ITEM = -1;
	redisplay();
}


function getBasicDesc(rageitem)
{
	var fulldesc = rageitem.getFullDesc();
	var desclines = fulldesc.split("\n");
	return desclines[0];
}

function redisplay()
{
	redisplayMainTable();

	redisplayStudyItem();

	setPageComponent(getPageComponent());
}

function getPageComponent()
{
	return EDIT_STUDY_ITEM == -1 ? "maintable_cmp" : "edit_item";
}

function saveNewDesc()
{
	const myitem = lookupItem("rage_log", EDIT_STUDY_ITEM);
	const newdesc = getDocFormValue("full_desc");
	myitem.setFullDesc(newdesc);
	myitem.syncItem();
	redisplay();
}

function getTagList(itemid)
{
	const myitem = lookupItem("rage_log", itemid);
	return tagListFromItem(myitem);
}

function tagListFromItem(ritem) 
{
	const tagstr = ritem.getCategory().trim();
	return tagstr.length == 0 ? [] : tagstr.split(";");
}

function getTagUniverse()
{
	const tagset = new Set();

	getItemList("rage_log").forEach(function(ritem) {
		tagListFromItem(ritem).forEach(tag => tagset.add(tag));		
	});

	return [... tagset].sort(proxySort(s => [s.toLowerCase()]));
}

function addStudyTag()
{
	const newtag = getDocFormValue("add_tag_sel");
	var thetags = getTagList(EDIT_STUDY_ITEM);
	thetags.push(newtag);

	const myitem = lookupItem("rage_log", EDIT_STUDY_ITEM);
	myitem.setCategory(thetags.join(";"));
	myitem.syncItem();
	redisplay();
}

function removeStudyTag(tagidx) 
{
	const oldtags = getTagList(EDIT_STUDY_ITEM);
	oldtags.splice(tagidx, 1);


	const myitem = lookupItem("rage_log", EDIT_STUDY_ITEM);
	myitem.setCategory(oldtags.join(";"));
	myitem.syncItem();
	redisplay();
}

function redisplayStudyItem()
{
	if(EDIT_STUDY_ITEM == -1)
		{ return; }

	const taglist = getTagList(EDIT_STUDY_ITEM);
	var tagstr = "";

	for(var tagidx in taglist) {

		const tag = taglist[tagidx];

		tagstr += `
			${tag}
			<a href="javascript:removeStudyTag('${tagidx}')">
			<img src="/life/image/remove.png" height="16" /></a>
			&nbsp; &nbsp; &nbsp;
		`;
	}

	var fulltaglist = ['---'];
	fulltaglist.push(... getTagUniverse());
	const tagsel = buildOptSelector()
						.setKeyList(fulltaglist)
						.setSelectOpener(`<select name="add_tag_sel" onChange="javascript:addStudyTag()">`)
						.setSelectedKey('---');



	const studyitem = lookupItem("rage_log", EDIT_STUDY_ITEM);
	
	// Okay, this took me a while to get right. The issue is that 
	// the standard string.replace(...) won't do a global, and there is no replaceAll
	var desclinelist = studyitem.getFullDesc().replace(/\n/g, "<br/>");
	
	populateSpanData({
		"day_code" : studyitem.getDayCode(),
		"short_name" : studyitem.getShortName(),
		"category_list" : tagstr,
		"full_desc" : studyitem.getFullDesc(),
		"add_tag_sel_span" : tagsel.getSelectString(),
		"itemdescline" : desclinelist
	});
}

function redisplayMainTable()
{

	var ragelist = getItemList("rage_log");
	ragelist.sort(proxySort(a => [a.getDayCode()])).reverse();

	var tablestr = `
		<table id="dcb-basic" class="dcb-basic" width="80%">
		<tr>
		<th width="7%">Date</th>
		<th>Tags</th>
		<th>Name</th>
		<th>Desc</th>
		<th>Op</th>
		</tr>
	`;
	
	ragelist.forEach(function(item) {
				
		const taglist = tagListFromItem(item).join(", ");
				
		const rowstr = `
			<tr>
			<td>${item.getDayCode().substring(5)}</td>	
			<td>${taglist}</td>			
			<td>${item.getShortName()}</td>
			<td width="50%">${getBasicDesc(item)}</td>
			<td width="10%">
				<a href="javascript:editStudyItem(${item.getId()})">
				<img src="/life/image/inspect.png" height=18"/></a>
				
				&nbsp; &nbsp; &nbsp;
				
				<a href="javascript:deleteItem(${item.getId()}, '${item.getShortName()}')">
				<img src="/life/image/remove.png" height="18"/></a>
			</td>
			</tr>
		`

		tablestr += rowstr;
	});

	tablestr += "</table>";

	populateSpanData({"maintable" : tablestr });
}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<span class="page_component" id="maintable_cmp">

<h2>Rage Log</h2>

<a class="css3button" style="background:-webkit-gradient(linear,left top,left bottom,from(#c00),to(#800));"
onclick="javascript:createNew()">NEW</a>

<br/>
<br/>

<div id="maintable"></div>


<br/>
</span>

<span class="page_component" id="edit_item">

<h3>Edit Item</h3>

<br/>

<table width="50%" id="dcb-basic">
<tr>
<td width="25%">Back</td>
<td></td>
<td width="30%"><a href="javascript:back2Main()"><img src="/life/image/leftarrow.png" height="18"/></a></td>
</tr>
<tr>
<td>Name</td>
<td><div id="short_name"></div></td>
<td><a href="javascript:editShortName()"><img src="/life/image/edit.png" height=18/></a></td>
</tr>
<tr>
<td>Tags</td>
<td><div id="category_list"></div></td>
<td>
<span id="add_tag_sel_span"></span>
</td>
</tr>
<tr>
<td>Date</td>
<td><span id="day_code"></span>
<td></td>
</tr>
</table>

<br/>
<br/>

<table id="dcb-basic" width="30%">
<tr>
<td>
<span id="itemdescline">xxx<br/>yyy</span>
</td>
</tr>
</table>

<br/>
<br/>

<form>
<textarea id="full_desc" name="full_desc" rows="10" cols="50"></textarea>
</form>

<a href="javascript:saveNewDesc()">save desc</a>

</span>


</center>
</body>
</html>
