
<html>
<head>
<title>&#x1F621 &#x1F624</title>

<wisp/>

<script src="/u/shared/optjs/ExtraInfoBox/v1.js"></script>


<script>

var EDIT_STUDY_ITEM = -1;

var SHOW_YEAR_INFO = true;

function createNew()
{
	const shortname = prompt("ENRAGED about what?? : ");
	
	if(shortname)
	{
		const todaycode = getTodayCode().dayBefore().getDateString();
		
		// created_on, active_on, completed_on, dead_line
		const newrec = {
			"short_name" : shortname,
			"category": 'misc',
			"full_desc": "NotYetSet",
			"day_code" : todaycode
		};
		
		const newitem = W.buildItem("rage_log", newrec);
		newitem.syncItem();
		redisplay();
	}
}

function deleteItem(killid, shortname)
{
	if(confirm("Are you sure you want to delete item " + shortname + "?"))
	{
		W.lookupItem("rage_log", killid).deleteItem();
		
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
	handleNavBar("Rage Log");

	redisplayMainTable();

	redisplayStudyItem();

	setPageComponent(getPageComponent());
}

function getPageComponent()
{
	return EDIT_STUDY_ITEM == -1 ? "maintable_cmp" : "edit_item";
}

function getExtraInfoBox()
{
	return EXTRA.getEiBox()
					.withStandardConfig("rage_log", EDIT_STUDY_ITEM, "full_desc")
					.withBoxBuilder("javascript:getExtraInfoBox()");
}


function getTagList(itemid)
{
	const myitem = W.lookupItem("rage_log", itemid);
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

	W.getItemList("rage_log").forEach(function(ritem) {
		tagListFromItem(ritem).forEach(tag => tagset.add(tag));		
	});

	return [... tagset].sort(proxySort(s => [s.toLowerCase()]));
}

function addStudyTag()
{
	const newtag = getDocFormValue("add_tag_sel");
	var thetags = getTagList(EDIT_STUDY_ITEM);
	thetags.push(newtag);

	const myitem = W.lookupItem("rage_log", EDIT_STUDY_ITEM);
	myitem.setCategory(thetags.join(";"));
	myitem.syncItem();
	redisplay();
}

function newTagForStudyItem()
{
	const updater = function(myitem)
	{
		const newtag = prompt("Please enter a new tag:");
		if(newtag)
		{
			const curtags = getTagList(myitem.getId());
			curtags.push(newtag);
			myitem.setCategory(curtags.join(";"));
		}
	}

	U.genericItemUpdate("rage_log", EDIT_STUDY_ITEM, updater);
}


function removeStudyTag(tagidx) 
{
	const oldtags = getTagList(EDIT_STUDY_ITEM);
	oldtags.splice(tagidx, 1);


	const myitem = W.lookupItem("rage_log", EDIT_STUDY_ITEM);
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
			<img src="/u/shared/image/remove.png" height="16" /></a>
			&nbsp; &nbsp; &nbsp;
		`;
	}

	var fulltaglist = ['---'];
	fulltaglist.push(... getTagUniverse());
	const tagsel = buildOptSelector()
						.configureFromList(fulltaglist)
						.setElementName("add_tag_sel")
						.setOnChange("javascript:addStudyTag()")
						.setSelectedKey('---');



	const studyitem = W.lookupItem("rage_log", EDIT_STUDY_ITEM);
	
	
	populateSpanData({
		"day_code" : studyitem.getDayCode(),
		"short_name" : studyitem.getShortName(),
		"category_list" : tagstr,
		"add_tag_sel_span" : tagsel.getHtmlString(),
		"extra_info_box" : getExtraInfoBox().getHtmlString()
	});
}

function redisplayMainTable()
{

	var ragelist = W.getItemList("rage_log");
	ragelist.sort(proxySort(a => [a.getDayCode()])).reverse();

	var tablestr = `
		<table class="basic-table"  width="85%">
		<tr>
		<th width="10%">Date</th>
		<th>Tags</th>
		<th>Name</th>
		<th>Desc</th>
		<th>Op</th>
		</tr>
	`;
	
	ragelist.forEach(function(item) {
				
		const taglist = tagListFromItem(item).join(", ");
				
		var datedisp = item.getDayCode();
		datedisp = SHOW_YEAR_INFO ? datedisp : datedisp.substring(5);

		const rowstr = `
			<tr>
			<td>${datedisp}</td>	
			<td>${taglist}</td>			
			<td>${item.getShortName()}</td>
			<td width="50%">${getBasicDesc(item)}</td>
			<td width="10%">
				<a href="javascript:editStudyItem(${item.getId()})">
				<img src="/u/shared/image/inspect.png" height=18"/></a>
				
				&nbsp; &nbsp; &nbsp;
				
				<a href="javascript:deleteItem(${item.getId()}, '${item.getShortName()}')">
				<img src="/u/shared/image/remove.png" height="18"/></a>
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

<div class="topnav"></div>

<br/>
<br/>

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

<table width="50%" class="basic-table">
<tr>
<td width="25%">Back</td>
<td></td>
<td width="30%"><a href="javascript:back2Main()"><img src="/u/shared/image/leftarrow.png" height="18"/></a></td>
</tr>
<tr>
<td>Name</td>
<td><div id="short_name"></div></td>
<td><a href="javascript:editShortName()"><img src="/u/shared/image/edit.png" height=18/></a></td>
</tr>
<tr>
<td>Tags</td>
<td><div id="category_list"></div></td>
<td>
<span id="add_tag_sel_span"></span>

&nbsp;
&nbsp;
&nbsp;

<a href="javascript:newTagForStudyItem()"><img src="/u/shared/image/add.png" height="16" /></a>

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

<span id="extra_info_box"></span>

</span>


</center>
</body>
</html>
