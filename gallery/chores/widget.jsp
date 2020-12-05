

<%@include file="../../admin/AuthInclude.jsp_inc" %>

<html>
<head>
<title>Chore Listing</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

<%= DataServer.includeIfAvailable(request, "minitask", "mini_task_list") %>

<script>

// If true, show study/edit page
var EDIT_STUDY_ITEM = -1;

// If true, show log, otherwise full list
var SHOW_BASIC_LOG = true;

function swap2MiniTask(choreid)
{
	const choreitem = lookupItem("chore_def", choreid);
	const newid = newBasicId("mini_task_list");
	const todaycode = getTodayCode().getDateString();
	const shortdesc =  "LifeChore:" + choreitem.getShortName();
	
	const newrec = {
		"id" : newid,
		"task_type" : "life",
		"short_desc" : shortdesc,
		"extra_info" : "",
		"alpha_date" : todaycode,
		"omega_date" : "",
		"priority" : 5,
		"is_backlog" : 0
	};
	
	const newitem = buildItem("mini_task_list", newrec);
	newitem.registerNSync();
		
	if(confirm("Created MTL item, should I mark the chore as complete?")) 
	{ 
		const comprec = {
			"chore_id" : choreid,
			"day_code" : todaycode
		};
		
		const compitem = buildItem("chore_comp", comprec);
		compitem.registerNSync();
	}
	
	redisplay();
}

function markComplete(choreid)
{
	const newrec = {
		"chore_id" : choreid,
		"day_code" : getTodayCode().getDateString()
	};
	
	const newitem = buildItem("chore_comp", newrec);
	newitem.registerNSync();
	redisplay();
}


function getLastCompletedMap()
{
	var bigloglist = getItemList("chore_comp");
	
	bigloglist.sort(proxySort(logitem => [logitem.getDayCode()])).reverse();

	var compmap = {};
	
	bigloglist.forEach(function(compitem) {
			
		if(!compmap.hasOwnProperty(compitem.getChoreId()))
			{ compmap[compitem.getChoreId()] = compitem.getDayCode(); }
	});
	
	return compmap;
}

function getChoreAge(choreitem, chorecompmap)
{
	// It's never been completed
	if(!chorecompmap.hasOwnProperty(choreitem.getId()))
		{ return 100000000; }
	
	var todaydc = getTodayCode();
	
	// Last date on which it was completed
	var lastcompdc = lookupDayCode(chorecompmap[choreitem.getId()]);
	
	return lastcompdc.daysUntil(todaydc);
}



function toggleChoreActive(choreid, chorename)
{
	genericToggleActive("chore_def", choreid);
}

function createNew()
{
	const chorename = prompt("Enter a name for the chore: ");
	
	if(chorename)
	{
		const newid = newBasicId("chore_def");		
		
		const newrec = {
			"chore_id" : newid,
			"day_freq" : 30,
			"short_name" : chorename,
			"extra_info" : "",
			"is_active" : 1,
			"web_link" : ""
		};
		
		const newitem = buildItem("chore_def", newrec);
		newitem.registerNSync();
		redisplay();
	}
}

function setEditStudyItem(itemid)
{
	EDIT_STUDY_ITEM = itemid;	
	redisplay();	
}

function return2Main()
{
	setEditStudyItem(-1);	
}

function getPageComponent()
{
	if(EDIT_STUDY_ITEM != -1)
		{ return "chore_item"; }
	
	return SHOW_BASIC_LOG ? "chore_log" : "chore_list";
}

function redisplay()
{
	redisplayChoreList();
	
	redisplayChoreItem();
	
	redisplayChoreLog();

	setPageComponent(getPageComponent());
}

function redisplayChoreList()
{
	const showinact = getUniqElementByName("show_inactive").checked;
	
	var itemlist = getItemList("chore_def");
	itemlist.sort(proxySort(a => [a.getShortName()]));
	
	var tablestr = `
		<table class="dcb-basic" id="dcb-basic" width="60%">
		<tr>
		<th width="7%">ID</th>
		<th>Name</th>
		<th>Frequency</th>
		<th>Active?</th>
		<th>Op</th>		
		</tr>
	`;
				
	
	itemlist.forEach(function(chore) {
		
		if(!showinact && chore.getIsActive() == 0) 
			{ return; }
		
		const activestr = chore.getIsActive() == 1 ? "YES" : "NO";
		
		var weblinkstr = `<img src="/life/image/purewhite.png" height="18"/>`;
		
		if(chore.getWebLink().length > 0)
		{
			weblinkstr = `
				&nbsp;&nbsp;
				<a href="${chore.getWebLink()}"><img src="/life/image/chainlink.png" height="18"/></a>
			`;
			
		}
		
		
		const rowstr = `
			<tr>
			<td>${chore.getId()}</td>
			<td>${chore.getShortName()}</td>
			<td>${chore.getDayFreq()}</td>
			<td>${activestr}</td>
			<td width="15%">
				<a href="javascript:setEditStudyItem(${chore.getId()})">
				<img src="/life/image/inspect.png" height=18"/a></a>
				
				&nbsp; 
				&nbsp; 
				&nbsp; 

				<a href="javascript:toggleChoreActive(${chore.getId()}, '${chore.getShortName()}')">
				<img src="/life/image/cycle.png" height="18"/></a>				
			
				${weblinkstr}
			</td>
			</tr>
		`;

		tablestr += rowstr;
		
	});
	
	tablestr += `
		</table>
	`;
	
	populateSpanData({'chore_list_table' : tablestr});
}

function redisplayChoreItem()
{
	if(EDIT_STUDY_ITEM == -1)
		{ return; }
		
	const edititem = lookupItem("chore_def", EDIT_STUDY_ITEM);

	const extrainfo = edititem.getExtraInfo();
	
	// Okay, this took me a while to get right. The issue is that 
	// the standard string.replace(...) won't do a global, and there is no replaceAll
	const desclinelist = extrainfo.replace(/\n/g, "<br/>");	
	
	const spanmap = {
		"item_id" : 		edititem.getId(),	
		"short_name" : 		edititem.getShortName(),
		"day_freq" : 		edititem.getDayFreq(),
		"isactive" : 		edititem.getIsActive() == 1 ? "YES" : "NO",
		"web_link" : 		edititem.getWebLink() == "" ? "--" : edititem.getWebLink(),
		"fullitemdesc" : 	edititem.getExtraInfo(),
		"itemdescline" : 	desclinelist
	};
	
	populateSpanData(spanmap);
}


function toggleLogMode()
{
	SHOW_BASIC_LOG = !SHOW_BASIC_LOG;	
	redisplay();
}

function redisplayChoreLog()
{
	const lastcompmap = getLastCompletedMap();
	const showall = getUniqElementByName("show_all").checked;

	
	var itemlist = getItemList("chore_def");
	itemlist.sort(proxySort(a => [a.getShortName()]));
	
	// var lastlogmap = getLastLogMap();
	
	var activetable = `
		<table id="dcb-basic" class="dcb-basic" width="70%">
		<tr>
		<th width="7%">ID</th>
		<th>Chore Name</th>
		<th>Last Completed</th>
		<th>Overdue</th>
		<th width="18%">...</th>
		</tr>
	`;

	
	itemlist.forEach(function(chore) {
			
		
		const choreage = getChoreAge(chore, lastcompmap);
		const lastupdate = lastcompmap.hasOwnProperty(chore.getId()) ? lastcompmap[chore.getId()] : "never";

		if(chore.getIsActive() == 0)
			{ return; }
				
		if(!showall && choreage <= chore.getDayFreq())
			{ return; }
			
		var weblinkstr = "--";
		
		if(chore.getWebLink().length > 0) 
		{
			weblinkstr = `<a href="${chore.getWebLink()}"><img src="/life/image/chainlink.png" height=18"></a>`;
		}
		
					
		const rowstr = `
			<tr>
			<td>${chore.getId()}</td>
			<td>${chore.getShortName()}</td>
			<td>${lastupdate.substring(5)}</td>
			<td>${choreage}</td>
			
			<td width="10%">

				<a href="javascript:swap2MiniTask(${chore.getId()})">
				<img src="/life/image/swap2mtl.png" height=18"/a></a>
				
				&nbsp;&nbsp;
			
				<a href="javascript:markComplete(${chore.getId()})">
				<img src="/life/image/checkmark.png" height=18"/a></a>
				
				&nbsp;&nbsp;
				
				<a href="javascript:setEditStudyItem(${chore.getId()})">
				<img src="/life/image/inspect.png" height=18"/a></a>
				
				&nbsp;&nbsp;
												
				${weblinkstr}
			</td>
			</tr>
		`;
		
		activetable += rowstr;
	});
	
	activetable += `</table>`;
	
	populateSpanData({'chore_log_table' : activetable });
}



function getEditStudyItem()
{
	return lookupItem("chore_def", EDIT_STUDY_ITEM);	
}

function editChoreFreq()
{
	const showItem = getEditStudyItem();
	
	var newfreq = prompt("Enter a new frequency for this chore: ", showItem.getDayFreq());
	
	if(!newfreq)
		{ return; }
	
	if(!okayInt(newfreq))
	{
		alert("Invalid number, please reenter: " + newfreq);
		return;
	}
		
	showItem.setDayFreq(parseInt(newfreq));
	syncSingleItem(showItem);	
	redisplay();
}

function editChoreName()
{
	genericEditTextField("chore_def", "short_name", EDIT_STUDY_ITEM);
}


function editWebLink()
{
	var showItem = getEditStudyItem();

	var newlink = prompt("Enter a web link for this chore: ", showItem.getWebLink());

	if(newlink)
	{
		showItem.setWebLink(newlink);
		syncSingleItem(showItem);		
		redisplay();
	}
}

function saveNewDesc()
{
	const showItem = getEditStudyItem();
	const newDesc = getDocFormValue("fullitemdesc");
	
	showItem.setExtraInfo(newDesc);
	syncSingleItem(showItem);
	redisplay();
}

function flipActive()
{
	const showItem = getEditStudyItem();
	const curActive = showItem.getIsActive();
	
	showItem.setIsActive(curActive == 1 ? 0 : 1);
	syncSingleItem(showItem);		
	redisplay();
}




</script>

</head>

<body onLoad="javascript:redisplay()"/>


<center>

<span class="page_component" id="chore_list">

<h3>Chore Listing</h3>

<a href="javascript:toggleLogMode()">Chore Log</a>

<form>
Show InActive
<input type="checkbox" name="show_inactive" onChange="javascript:redisplay()"/>
</form>

<div id="chore_list_table"></div>

<br/>

<a name="truebutton" class="css3button" onclick="javascript:createNew()">create</a>


</span>

<span class="page_component" id="chore_log">

<h3>Chore Logging</h3>

<a href="javascript:toggleLogMode()">Chore List</a>

<br/>

<form>
Show All: <input type="checkbox" name="show_all" onChange="javascript:redisplay()"/>
</form>

<div id="chore_log_table"></div>
</span>


<span class="page_component" id="chore_item">

<h2>Chore Info</h2>

<table id="dcb-basic" width="50%">
<tr>
<td width="25%">Back</td>
<td></td>
<td><a name="back_url" href="javascript:return2Main()"><img src="/life/image/leftarrow.png" height="18"/></a></td>
</tr>
<tr>
<td>ID</td>
<td><span id="item_id"></span></td>
<td></td>
</tr>
<tr>
<td>Name</td>
<td><span id="short_name"></span></td>
<td><a href="javascript:editChoreName()"><img src="/life/image/edit.png" height="18"/></a></td>
</tr>
<tr>
<td>Link</td>
<td><span id="web_link"></span></td>
<td><a href="javascript:editWebLink()"><img src="/life/image/edit.png" height="18"/></a></td>
</tr>
<tr>
<td>Frequency</td>
<td><span id="day_freq"></span></td>
<td><a href="javascript:editChoreFreq()"><img src="/life/image/edit.png" height="18"/></a></td>
</tr>
<tr>
<td width="50%">Active?</td>
<td><span id="isactive"></span>

</td>
<td><a href="javascript:flipActive()"><img src="/life/image/cycle.png" height=18/></a></td>
</tr>

</table>


<br/>
<br/>

<!-- Full description table -->
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
<textarea id="fullitemdesc" name="fullitemdesc" rows="10" cols="50"></textarea>
</form>

<a href="javascript:saveNewDesc()">save desc</a>


</span>


</center>
</body>
</html>
