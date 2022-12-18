
<html>
<head>
<title>Mini Task List</title>

<%= DataServer.basicInclude(request) %>

<script>

var TODAY_CODE = getTodayCode();

var EDIT_STUDY_ITEM = 3763;

// In this widget, this list is hardcoded
const MASTER_TYPE_LIST = ["chinese", "crm", "life", "work"];

// Gets the task's age. 
// For purposes of efficiency, caller should supply a reference to todaycode
function getTaskAge(thetask)
{
	// console.log("Task alpha is " + thetask.getAlphaDate());
	
	var alphadc = lookupDayCode(thetask.getAlphaDate());
	
	return alphadc.daysUntil(TODAY_CODE);
}

function createNewTask()
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
		var newid = newBasicId("mini_task_list");
		
		var todaycode = getTodayCode().getDateString();
		
		const newrec = {
			"id" : newid,
			"task_type" : showtypelist[0],
			"short_desc" : itemname,
			"extra_info" : "",
			"alpha_date" : todaycode,
			"omega_date" : "",
			"priority" : 5,
			"is_backlog" : 0
		};
	
		// CREATE TABLE mini_task_list (id int, task_type varchar(10), short_desc varchar(30), extra_info varchar(400), alpha_date varchar(10), omega_date varchar(10), priority int, is_backlog smallint default 0, primary key(id));
		
		const newtaskitem = buildItem("mini_task_list", newrec);
		newtaskitem.syncItem();
		redisplay();
	}
}

// Get effective priority of item, given its intrinsic priority and its age.
function getEffectivePriority(actitem)
{	
	var dayage = getTaskAge(actitem);
	
	var intprior = actitem.getPriority();
	
	var LAMBDA = Math.log(2)/5;
	
	return intprior * Math.exp(LAMBDA*dayage);
}

function archiveItem(itemid)
{
	if(confirm("Are you sure you want to archive this item " + itemid + " ?"))
	{
		var theitem = lookupItem("mini_task_list", itemid);
		theitem.setAlphaDate('2000-01-01');
		theitem.setIsBacklog(1);
		theitem.syncItem();
		redisplay();
	}
}






function deleteItem(killid)
{
	var theitem = lookupItem("mini_task_list", killid);
	
	if(confirm("Are you sure you want to delete item " + theitem.getShortDesc() + " ?"))
	{
		theitem.deleteItem();
		redisplay();
	}
}

function markItemComplete(markid)
{
	const markitem = lookupItem("mini_task_list", markid);
	const todaycode = getTodayCode().getDateString();
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
	markitem.setAlphaDate(getTodayCode().getDateString());
	
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
	
	const hits = W.getItemList("mini_task_list").filter(item => item.getId() == EDIT_STUDY_ITEM);
	return hits[0];
}

function getTaskItemList(wantcompleted)
{
	var tasklist = [];
	
	var biglist = W.getItemList("mini_task_list").filter(item => item.getIsBacklog() == 0);
		
	biglist.sort(proxySort(item => [item.getAlphaDate()])).reverse();
	
	for(var bi in biglist)
	{	
		var taskitem = biglist[bi];
		
		// console.log(taskitem.getAlphaDate());
		
		var taskcomplete = taskitem.getOmegaDate().length > 0;
		
		if(!wantcompleted && !taskcomplete)
		{ 
			tasklist.push(taskitem);
			continue; 
		}
		
		if(wantcompleted && taskcomplete)
		{
			tasklist.push(taskitem);
		}
		
		if(wantcompleted && tasklist.length > 50)
		 	{ break; }
	}
	
	// Sort completed tasks by finish date.
	if(wantcompleted)
	{
		// tasklist.sort(function(a, b) { return b.getOmegaDate().localeCompare(a.getOmegaDate()); });
		
		tasklist.sort(proxySort(item => [item.getOmegaDate()])).reverse();
	}
	

	return tasklist;
}

function toggleItemStatus()
{
	massert(EDIT_STUDY_ITEM != -1);

	const studyitem = lookupItem("mini_task_list", EDIT_STUDY_ITEM);
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
	const params = getUrlParamHash();
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

	redisplay();
}

function editItemName()
{
	var studyitem = getStudyItem();
	
	var newdesc = prompt("Enter a short description for this item: ", studyitem.getShortDesc());
	
	if(newdesc)
	{
		studyitem.setShortDesc(newdesc);
		syncSingleItem(studyitem);
		redisplay();			
	}
}

function editStudyItemPriority()
{
	editItemPriority(EDIT_STUDY_ITEM);
}

function updateTaskType()
{
	const newtype = getDocFormValue("task_type_sel");
	const studyitem = getStudyItem();
			
	studyitem.setTaskType(newtype);
	studyitem.syncItem();
	
	redisplay();	
}


function saveExtraInfo()
{
	var studyitem = getStudyItem();
			
	studyitem.setExtraInfo(document.getElementById("set_extra_info").value);
	
	syncSingleItem(studyitem);		
			
	redisplay();	
	
	toggleHidden4Class('edit_info');
}


function reDispActiveTable()
{

	var activelist = getTaskItemList(false);
	
	// Sort by effective priority
	activelist.sort(proxySort(actrec => [-actrec.getPriority()]));
	
	var tablestr = `
		<table class="basic-table"  width="80%">
		<tr>
		<th>Type</th>
		<th>ShortDesc</th>
		<th>Start</th>
		<th>Age</th>
		<th>Priority</th>
		<th>---</th>
		</tr>
	`;
	
	const showtypelist = getShowTypeList();
	
	activelist.forEach(function(activitem) {
			
		if(showtypelist.indexOf(activitem.getTaskType()) == -1)
			{ return; }
	
		const dayage = getTaskAge(activitem);
		
		var rowstr = `
			<tr>
			<td width="7">${activitem.getTaskType()}</td>
			<td width="40%">${activitem.getShortDesc()}</td>			
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
				<td width="18%">
				<a href="javascript:markItemComplete(${activitem.getId()})">
				<img src="/u/shared/image/checkmark.png" height="18"/></a>
			
				${breaker}
				
				<a href="javascript:refreshStartDate(${activitem.getId()})">
				<img src="/u/shared/image/cycle.png" height="18"></a>
			
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
	
	populateSpanData({
		"activetable" : tablestr
	});
	
}

function reDispCompleteTable()
{
	
	var tablestr = `
		<table class="basic-table"  width="70%">
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
	
	populateSpanData({
		"completetable" : tablestr		
	});
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
					.setKeyList(MASTER_TYPE_LIST)
					.setSelectOpener(`<select name="task_type_sel" onChange="javascript:updateTaskType()">`)
					.setSelectedKey(studyitem.getTaskType())
					.getSelectString();
	
	populateSpanData({
		"taskid" : studyitem.getId(),
		"shortdesc" : studyitem.getShortDesc(),
		"task_type_sel_span" : ttypesel,
		"alphadate" : studyitem.getAlphaDate(),
		"omegadate" : studyitem.getOmegaDate(),
		"item_status" : itemstat,
		"priority" : studyitem.getPriority(),
		"extrainfo" : extralinelist
	});
	
	document.getElementById("set_extra_info").value = extrainfo;	
}


function redisplay()
{
	_TASK_AGE_MAP = {};
	
	reDispEditItem();
	
	reDispActiveTable();
	
	reDispCompleteTable();
}





</script>

</head>

<body onLoad="javascript:setDefaultShow()">

<center>

<span class="main2edit">



<h3>Mini Task List</h3>

<br/>

<a name="truebutton" class="css3button" onclick="javascript:createNewTask()">new</a>

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

<h3>Active Items &nbsp; &nbsp; &nbsp; <a href="MiniTaskArchive.jsp">backlog</a></h3>

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
<td>ID</td>
<td><span id="taskid"></span></td>
</tr>
<tr>
<td>ShortDesc</td>
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

<table class="basic-table" width="50%" border="0">
<tr>
<td>
<span id="extrainfo"></span>
</td>

<td width="10%">
<a href="javascript:toggleHidden4Class('edit_info')"><img src="/u/shared/image/edit.png" height="18"></a>
</td>
</tr>
</table>
<br/>
</span>


<span class="edit_info" hidden>

<form>
<textarea id="set_extra_info" cols="80" rows="10">
</textarea>
</form>

<a class="css3button" onclick="javascript:saveExtraInfo()">save</a>

&nbsp;
&nbsp;
&nbsp;
&nbsp;

<a class="css3button" onclick="javascript:toggleHidden4Class('edit_info')">cancel</a>

</span>

</span>

</center>

</body>
</html>
