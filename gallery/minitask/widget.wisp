
<html>
<head>
<title>Mini Task List</title>

<wisp/>

<style>

/* 
on a wide screen, use 80% of width, but on narrow screen use at least 800 pixel 
Goal here is to work with laptop and tablet, but not phone
*/
.tasktable {

	min-width: 800px;
	width: 80%;
}

</style>

<script src="/u/shared/optjs/ExtraInfoBox/v1.js"></script>

<script>

var TODAY_CODE = U.getTodayCode();

var EDIT_STUDY_ITEM = -1;


function createNewTop()
{
	createNewTaskSub(40);
}


function createNewHigh()
{
	createNewTaskSub(20);
}


function createNewTask()
{
	createNewTaskSub(5);
}


function createNewTaskSub(priority)
{
	const showtypelist = getShowTypeList();
	if(showtypelist.length > 1)
	{
		alert("Please select a single category");	
		return;
	}
	
	var itemname = prompt("New Item Desc: ");
	
	if(itemname)
	{
		const newrec = {
			"task_type" : showtypelist[0],
			"short_desc" : itemname,
			"extra_info" : "",
			"alpha_date" : U.getTodayCode().getDateString(),
			"omega_date" : "",
			"priority" : priority,
			"is_backlog" : 0
		};
	
		// CREATE TABLE mini_task_list (id int, task_type varchar(10), short_desc varchar(30), extra_info varchar(400), alpha_date varchar(10), omega_date varchar(10), priority int, is_backlog smallint default 0, primary key(id));
		
		const newtaskitem = W.buildItem("mini_task_list", newrec);
		newtaskitem.syncItem();
		redisplay();
	}
}



function archiveItem(itemid)
{
	if(confirm("Are you sure you want to archive this item " + itemid + " ?"))
	{
		var theitem = W.lookupItem("mini_task_list", itemid);
		theitem.setAlphaDate('2000-01-01');
		theitem.setIsBacklog(1);
		theitem.syncItem();
		redisplay();
	}
}



function deleteItem(killid)
{
	var theitem = W.lookupItem("mini_task_list", killid);
	
	if(confirm("Are you sure you want to delete item " + theitem.getShortDesc() + " ?"))
	{
		theitem.deleteItem();
		redisplay();
	}
}

function markItemComplete(markid)
{
	const markitem = W.lookupItem("mini_task_list", markid);
	const todaycode = U.getTodayCode().getDateString();
	markitem.setOmegaDate(todaycode);
	markitem.syncItem();
	redisplay();
}

function updateItemPriority(markid, delta)
{
	const markitem = W.lookupItem("mini_task_list", markid);
	const newpriority = markitem.getPriority() + delta;
	
	markitem.setPriority(newpriority);
	markitem.syncItem();			
	redisplay();
}

function editItemPriority(markid)
{
	const markitem = W.lookupItem("mini_task_list", markid);	
	const newpriority = prompt("Enter new priority: ", markitem.getPriority());
	
	if(!newpriority)
		{ return; }
	
	var npint = parseInt(newpriority);

	if(isNaN(npint))
	{ 
		alert("Invalid entry, please try again");
		return; 
	}
	
	markitem.setPriority(newpriority);
	markitem.syncItem();		
	redisplay();
}



function refreshStartDate(markid)
{
	const markitem = W.lookupItem("mini_task_list", markid);
	markitem.setAlphaDate(U.getTodayCode().getDateString());
	
	markitem.syncItem();
	redisplay();
}

function return2Main()
{
	editStudyItem(-1);
}

function editStudyItem(markid)
{
	EDIT_STUDY_ITEM = markid;
	
	toggleHidden4Class("main2edit");	
	
	redisplay();
}

function getStudyItem()
{
	if(EDIT_STUDY_ITEM == -1)
		{ return null; }
	
	return W.lookupItem("mini_task_list", EDIT_STUDY_ITEM);
}

function toggleItemStatus()
{
	U.massert(EDIT_STUDY_ITEM != -1);

	const studyitem = W.lookupItem("mini_task_list", EDIT_STUDY_ITEM);
	if(studyitem.getOmegaDate().length == 0) 
	{ 
		// This case is identical to just marking the study item complete.
		markItemComplete(EDIT_STUDY_ITEM); 
		return;
	}

	// To mark active, clear out the omega data.
	studyitem.setOmegaDate("");
	studyitem.syncItem();
	redisplay();
}

function getShowTypeList()
{
	var hits = [];
	
	document.getElementsByName("show_task_type").forEach(function(n) {
		if(!n.checked)
			{ return; }
		
		hits.push(n.value);
	});
	
	if(hits.length == 0 || hits[0] == "all")
		{ return MASTER_TYPE_LIST; }
	
	return hits;
}

function setDefaultShow()
{
	const params = U.getUrlParamHash();
	if (!('default_show' in params)) 
		{params['default_show'] = 'life';}

	var foundit = false;

	document.getElementsByName("show_task_type").forEach(function(n) {
		const checkit = params['default_show'] == n.value;
		if (checkit) {
			n.checked = true;
			foundit = true;
		}
	});
	
	if(!foundit) {
		alert(`Warning, requested default show ${params['default_show']}, but options are ${MASTER_TYPE_LIST}`);
	}

	if('item_id' in params)
	{
		editStudyItem(parseInt(params['item_id']));

		// console.log("EDIT_STUDY_ITEM is " + EDIT_STUDY_ITEM + " from params");
	}

	redisplay();
}

function editItemName()
{
	const updater = function(studyitem)
	{
		const newdesc = prompt("Enter a short description for this item: ", studyitem.getShortDesc());
		
		if(newdesc)
			{ studyitem.setShortDesc(newdesc); }
	}

	U.genericItemUpdate("mini_task_list", EDIT_STUDY_ITEM, updater);
}

function editStudyItemPriority()
{
	editItemPriority(EDIT_STUDY_ITEM);
}

function updateTaskType()
{
	const newtype = U.getDocFormValue("task_type_sel");
	const studyitem = getStudyItem();
			
	studyitem.setTaskType(newtype);
	studyitem.syncItem();
	
	redisplay();
}


function saveExtraInfo()
{
	var studyitem = getStudyItem();
			
	studyitem.setExtraInfo(document.getElementById("set_extra_info").value);

	studyitem.syncItem();
			
	redisplay();
	
	toggleHidden4Class('edit_info');
}

function getExtraInfoBox()
{
	return EXTRA.getEiBox()
					.withStandardConfig("mini_task_list", EDIT_STUDY_ITEM, "extra_info")
					.withBoxBuilder("javascript:getExtraInfoBox()");


}


function reDispActiveTable()
{

	var activelist = getTaskItemList(false);
	
	// Sort by effective priority
	activelist.sort(U.proxySort(actrec => [-actrec.getPriority()]));

	const showtypelist = getShowTypeList();

	const showtypecol = showtypelist.length > 1;	
	
	var tablestr = `
		<table class="basic-table tasktable">
		<tr>
		${showtypecol ? "<th>Type</th>" : ""}
		<th>Description</th>
		<th>Start</th>
		<th>Age</th>
		<th>Priority</th>
		<th>---</th>
		</tr>
	`;
	
	
	activelist.forEach(function(activitem) {
			
		if(showtypelist.indexOf(activitem.getTaskType()) == -1)
			{ return; }
	
		const dayage = getTaskAge(activitem);
		
		const tdcell = showtypecol ? `<td width="7">${activitem.getTaskType()}</td>` : "";

		var rowstr = `
			<tr>
			${tdcell}
			<td width="60%">${activitem.getShortDesc()}</td>			
			<td width="10%">${activitem.getAlphaDate().substring(5)}</td>	
			<td>${dayage}</td>			
		`;

		// Intrinsic priority
		{
			rowstr += `
				<td>
				${activitem.getPriority()}
				&nbsp; &nbsp; 
				&nbsp;

				<a href="javascript:editItemPriority(${activitem.getId()})">
				<img src="/u/shared/image/edit.png" height="18"/></a>
				</td>
			`;
		}

		
		{
			const breaker = "&nbsp; &nbsp;";
			
			rowstr += `
				<td>
				<a href="javascript:markItemComplete(${activitem.getId()})">
				<img src="/u/shared/image/checkmark.png" height="18"/></a>
			
				${breaker}
					
				<a href="javascript:editStudyItem(${activitem.getId()})">
				<img src="/u/shared/image/inspect.png" height="18"></a>
				
				${breaker}

				<a href="javascript:archiveItem(${activitem.getId()})">
				<img src="/u/shared/image/rghtarrow.png" height="18"></a>
				
				${breaker}
				
				<a href="javascript:deleteItem(${activitem.getId()})">
				<img src="/u/shared/image/remove.png" height="18"></a>
				
				</td>
			`;
		}
		

			
		rowstr += "</tr>";
		
		tablestr += rowstr;	
	});

	
	tablestr += "</table>";
	
	U.populateSpanData({ "activetable" : tablestr });
	
}

function reDispCompleteTable()
{
	
	var tablestr = `
		<table class="basic-table tasktable"  width="80%">
		<tr>
		<th>Type</th>
		<th>Desc</th>
		<th>Start</th>
		<th>Done</th>
		<th>---</th>
		</tr>
	`;
	
	const completelist = getTaskItemList(true);
	
	completelist.forEach(function(compitem) {
		
		const rowstr = `
			<tr>
			<td width="8%">${compitem.getTaskType()}</td>
			<td>${compitem.getShortDesc()}</td>
			<td width="5%">${compitem.getAlphaDate().substring(5)}</td>
			<td width="5%">${compitem.getOmegaDate().substring(5)}</td>
			<td>
			<a href="javascript:editStudyItem(${compitem.getId()})">
			<img src="/u/shared/image/inspect.png" height="18"></a>
			</td>
			
			</tr>
		`;
		
		tablestr += rowstr;
			
	});

	tablestr += `</table>`;
	
	U.populateSpanData({ "completetable" : tablestr	});
}

function reDispEditItem()
{
	if(EDIT_STUDY_ITEM == -1)
		{ return; }
	
	const studyitem = getStudyItem();
	const itemstat = studyitem.getOmegaDate().length == 0 ? "ACTIVE" : "COMPLETE";

	var extrainfo = studyitem.getExtraInfo();
	if(extrainfo.length == 0)
		{ extrainfo = "Not Yet Set"; }
	
	const extralinelist = extrainfo.replace(/\n/g, "<br/>");

	const ttypesel = buildOptSelector()
						.configureFromList(MASTER_TYPE_LIST)
						.setOnChange("javascript:updateTaskType()")
						.setElementName("task_type_sel")
						.setSelectedKey(studyitem.getTaskType())
						.getHtmlString();
	
	U.populateSpanData({
		"shortdesc" : studyitem.getShortDesc(),
		"task_type_sel_span" : ttypesel,
		"alphadate" : studyitem.getAlphaDate(),
		"omegadate" : studyitem.getOmegaDate(),
		"item_status" : itemstat,
		"priority" : studyitem.getPriority(),
		"extra_info_box" : getExtraInfoBox().getHtmlString()
	});
	
}


function handleTopNav()
{
    populateTopNavBar(getHeaderInfo(), "Mini Task List");
}

function redisplay()
{
	_TASK_AGE_MAP = {};
	
	handleTopNav();

	reDispEditItem();
	
	reDispActiveTable();
	
	reDispCompleteTable();
}





</script>

<style>

.button-green {
    background: -webkit-gradient(linear, left top, left bottom, from(#3d8), to(#1b6));
}

.button-teal {
    background: -webkit-gradient(linear, left top, left bottom, from(#30d5c8), to(#208a7c));
}



/* Yellow Button */
.button-yellow {
    background: -webkit-gradient(linear, left top, left bottom, from(#ffd700), to(#ffcc00));
    color: black; /* Better contrast for yellow */
}

/* Orange Button */
.button-orange {
    background: -webkit-gradient(linear, left top, left bottom, from(#ffa500), to(#ff7f00));
}



</style>

</head>

<body onLoad="javascript:setDefaultShow()">


<center>

<div class="topnav"></div>

<br/>

<span class="main2edit">


<br/>

<a class="css3button button-green" onclick="javascript:createNewTop()">top</a>

&nbsp;
&nbsp;
&nbsp;

<a class="css3button button-teal" onclick="javascript:createNewHigh()">high</a>


&nbsp;
&nbsp;
&nbsp;


<a class="css3button" onclick="javascript:createNewTask()">new</a>


<br/>
<br/>


<form>
<input type="radio" name="show_task_type" value="all" onChange="javascript:redisplay()">
<label>All</label>
&nbsp;
&nbsp;
&nbsp;
&nbsp;



<input type="radio" name="show_task_type" value="crm" onChange="javascript:redisplay()">
<label>CRM</label>
&nbsp;
&nbsp;
&nbsp;
&nbsp;

<input type="radio" name="show_task_type" value="life" onChange="javascript:redisplay()" checked>
<label>Life</label>
&nbsp;
&nbsp;
&nbsp;
&nbsp;

<input type="radio" name="show_task_type" value="work" onChange="javascript:redisplay()">
<label>Work</label>

&nbsp;
&nbsp;
&nbsp;
&nbsp;


<input type="radio" name="show_task_type" value="chinese" onChange="javascript:redisplay()">
<label>Chinese</label>


</form>  

<br/>

<div id="activetable"></div>

<br/><br/>

<h3>Completed Items, Last 60 Days</h3>

<br/>

<div id="completetable"></div>

</span>

<span class="main2edit" hidden>

<br/><br/>

<h2>Task Item Detail</h2>

<br/>

<table class="basic-table" width="50%">
<tr>
<td>Back</td>
<td><a href="javascript:return2Main()"><img src="/u/shared/image/leftarrow.png" height="18"/></a></td>
</tr>

<tr>
<td>Description</td>
<td><b><span id="shortdesc"></span></b>

&nbsp;
&nbsp;
&nbsp;

<a href="javascript:editItemName()"><img src="/u/shared/image/edit.png" height="18"></a>

</td>
</tr>
<tr>
<td>TaskType</td>
<td><span id="task_type_sel_span"></span></td>
</tr>
<tr>
<td>Start Date</td>
<td><span id="alphadate"></span></td>
</tr>
<tr>
<td>End Date</td>
<td><span id="omegadate"></span></td>
</tr>
<tr>
<td>Status</td>
<td>
<span id="item_status"></span>


&nbsp;
&nbsp;
&nbsp;


<a href="javascript:toggleItemStatus()"><img src="/u/shared/image/cycle.png" height="18"></a>
</td>
</tr>

<tr>
<td>Priority</td>
<td><span id="priority"></span>

&nbsp;
&nbsp;
&nbsp;

<a href="javascript:editStudyItemPriority()"><img src="/u/shared/image/edit.png" height="18"></a>
</td>
</tr>

</table>

<br/><br/>


<span id="extra_info_box"></span>

</span>

</center>

</body>
</html>
