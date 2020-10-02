
<%@ page import="java.util.*" %>

<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@ page import="lifedesign.basic.*" %>
<%@ page import="lifedesign.classic.*" %>

<%@include file="../../life/AuthInclude.jsp_inc" %>


<%
	ArgMap argMap = HtmlUtil.getArgMap(request);
	
	OptSelector ratingSel = new OptSelector(Util.range(1, 10));
	
	DayCode todayCode = DayCode.getToday();
		
%>

<html>
<head>
<title>Mini Task List</title>

<%@include file="../../life/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

<script>

var TODAY_CODE = getTodayCode();

var EDIT_STUDY_ITEM = -1;

// Gets the task's age. 
// For purposes of efficiency, caller should supply a reference to todaycode
function getTaskAge(thetask)
{
	// console.log("Task alpha is " + thetask.getAlphaDate());
	
	var alphadc = lookupDayCode(thetask.getAlphaDate());
	
	return alphadc.daysUntil(TODAY_CODE);
}

function createNew(tasktype)
{
	var itemname = prompt("New Item Desc: ");
	
	if(itemname)
	{	
		var newid = newBasicId("mini_task_list");
		
		var todaycode = getTodayCode().getDateString();
	
		var newtaskitem = new MiniTaskListItem(newid, tasktype, itemname, '', todaycode, '', 5, 0);
		
		newtaskitem.registerNSync();
		
		redisplay();
	}
}

// Get effective priority of item, given its intrinsic priority and its age.
function getEffectivePriority(actitem)
{
	// console.log("Act Item is " + actitem.getId());
	// var dcalpha = lookupDayCode(actitem.getAlphaDate());
			
	// var dayage = dcalpha.daysUntil(getTodayCode());
	// var dayage = getTaskAgeMap()[actitem.getId()];
	
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
		syncSingleItem(theitem);		
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
	var markitem = lookupItem("mini_task_list", markid);
			
	markitem.setOmegaDate("<%= DayCode.getToday() %>");
	
	syncSingleItem(markitem);		
			
	redisplay();
}

function updateItemPriority(markid, delta)
{
	var markitem = lookupItem("mini_task_list", markid);
			
	var newpriority = markitem.getPriority() + delta;
	
	markitem.setPriority(newpriority);
	
	syncSingleItem(markitem);		
			
	redisplay();
}

function editItemPriority(markid)
{
	var markitem = lookupItem("mini_task_list", markid);
			
	var newpriority = prompt("Enter new priority: ", markitem.getPriority());
	
	if(!newpriority)
		{ return; }
	
	var npint = parseInt(newpriority);

	if(isNaN(npint))
	{ 
		alert("Invalid entry, please try again");
		return; 
	}
	
	markitem.setPriority(newpriority);
	syncSingleItem(markitem);		
	redisplay();
}



function refreshStartDate(markid)
{
	var markitem = lookupItem("mini_task_list", markid);
		
	// console.log("Today code is : " + getTodayCode().getDateString());
	
	markitem.setAlphaDate(getTodayCode().getDateString());
	
	syncSingleItem(markitem);		
			
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
	
	const hits = getItemList("mini_task_list").filter(item => item.getId() == EDIT_STUDY_ITEM);
	return hits[0];
}

function getTaskItemList(wantcompleted)
{
	var tasklist = [];
	
	var biglist = getItemList("mini_task_list").filter(item => item.getIsBacklog() == 0);
		
	biglist.sort(proxySort(item => item.getAlphaDate())).reverse();
	
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
		
		if(tasklist.length > 50)
			{ break; }
	}
	
	// Sort completed tasks by finish date.
	if(wantcompleted)
	{
		// tasklist.sort(function(a, b) { return b.getOmegaDate().localeCompare(a.getOmegaDate()); });
		
		tasklist.sort(proxySort(item => item.getOmegaDate())).reverse();
	}
	

	return tasklist;
}

function getShowTypeList()
{
	const alltypes = ['crm', 'life', 'work'];
	var hits = [];
	
	document.getElementsByName("show_task_type").forEach(function(n) {
		if(!n.checked)
			{ return; }
		
		hits.push(n.value);
	});
	
	if(hits.length == 0 || hits[0] == "all")
		{ return alltypes; }
	
	return hits;
}

function setDefaultShow()
{
	var params = getUrlParamHash();
	var typelist = ['crm', 'life', 'work'];
	
	if('default_show' in params)
	{
		for(var ti in typelist)
		{
			var showme = typelist[ti] == params['default_show'];
			var button = getUniqElementByName("show_" + typelist[ti]);
			button.checked = showme;
			
			// getUniqElementByName('show_type').value = params['default_show'];
			// console.log(params);
		}
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
	activelist.sort(proxySort(actrec => [-getEffectivePriority(actrec)]));
	
				
	var activetable = $('<table></table>').addClass('dcb-basic').attr("id", "dcb-basic").attr("width", "75%");
	
	{
		var row = $('<tr></tr>').addClass('bar');
	
		["ID", "TaskType", "ShortDesc", "StartDate", "DayOld", "Int Prior", "Eff Prior", "---"].forEach( function (hname) {
		
			row.append($('<th></th>').text(hname));
		});
		
		activetable.append(row);	
	}
		
	const showtypelist = getShowTypeList();
			
	for(var ai in activelist)
	{
		var activitem = activelist[ai];
	
		if(showtypelist.indexOf(activitem.getTaskType()) == -1)
			{ continue; }
	
		
		// console.log("Task type is " + activitem.getTaskType() + ",  checked is " + showcbox.checked);
		
		// console.log(oneday + " " + dci);

		var row = $('<tr></tr>').addClass('bar');
	
		// row.append($('<td></td>').text(possitem.getId()));
		row.append($('<td></td>').attr("width", "5%").text(activitem.getId()));
		
		row.append($('<td></td>').attr("width", "7%").text(activitem.getTaskType()));
		
		row.append($('<td></td>').text(activitem.getShortDesc()));			
				
		row.append($('<td></td>').attr("width", "15%").text(activitem.getAlphaDate()));
		
		
		{
			// var dcalpha = lookupDayCode(activitem.getAlphaDate());
			
			// var dayage = dcalpha.daysUntil(getTodayCode());
			
			// var dayage = getTaskAgeMap()[activitem.getId()];
			
			var dayage = getTaskAge(activitem);
		
			row.append($('<td></td>').attr("width", "7%").text(dayage));
		}
			
		{
			var opcell = $('<td></td>').attr("width", "15%");
			
			opcell.append(activitem.getPriority()+"");
			
			for(var i = 0; i < 4; i++)
				{ opcell.append("&nbsp;"); }
			
			var decprijs = "javascript:editItemPriority(" + activitem.getId() + ")";
			
			var decpriref = $('<a></a>').attr("href", decprijs).append($('<img></img>').attr("src", "/life/image/edit.png").attr("height", 16));;
				
			opcell.append(decpriref);
			
			row.append(opcell);
		}
				
		
		// Effective Priority
		{
			var opcell = $('<td></td>').attr("width", "10%");
			
			var effpri = getEffectivePriority(activitem);
			
			opcell.append(effpri.toFixed(1));		
			
			row.append(opcell);
		}
		
				
		{
			var opcell = $('<td></td>').attr("width", "18%");
		
			{
				// var deletejs = "javascript:deleteItem(" + possitem.getId() + ", '" + possitem.getShortname() + "')";
			
				var deletejs = "javascript:markItemComplete(" + activitem.getId() + ")";
				
				
				var deleteref = $('<a></a>').attr("href", deletejs).append(
										$('<img></img>').attr("src", "/life/image/checkmark.png").attr("height", 18)
								);
				
				opcell.append(deleteref);
			} 
			
			opcell.append("&nbsp;");
			opcell.append("&nbsp;");
			opcell.append("&nbsp;");			
			
			{
				var incprijs = "javascript:refreshStartDate(" + activitem.getId() + ")";
				
				var incpriref = $('<a></a>').attr("href", incprijs).append($('<img></img>').attr("src", "/life/image/cycle.png").attr("height", 18));;
					
				opcell.append(incpriref);
			}
			
			
			
			
			opcell.append("&nbsp;");
			opcell.append("&nbsp;");
			opcell.append("&nbsp;");
			
			{			
				const studyurl = "javascript:editStudyItem(" + activitem.getId() + ")";
				
				
				var studyref = $('<a></a>').attr("href", studyurl).append(
										$('<img></img>').attr("src", "/life/image/inspect.png").attr("height", 18)
								);
				
				opcell.append(studyref);
			} 
			
			opcell.append("&nbsp;");
			opcell.append("&nbsp;");
			opcell.append("&nbsp;");			
			

			
			{	
				var deletejs = "javascript:archiveItem(" + activitem.getId() + ")";
				
				
				var deleteref = $('<a></a>').attr("href", deletejs).append(
										$('<img></img>').attr("src", "/life/image/rghtarrow.png").attr("height", 18)
								);
				
				opcell.append(deleteref);
			} 			
			
			opcell.append("&nbsp;");
			opcell.append("&nbsp;");
			opcell.append("&nbsp;");			
					
			
			{			
				var deletejs = "javascript:deleteItem(" + activitem.getId() + ")";
				
				
				var deleteref = $('<a></a>').attr("href", deletejs).append(
										$('<img></img>').attr("src", "/life/image/remove.png").attr("height", 18)
								);
				
				opcell.append(deleteref);
			} 			
						
			
			
			
						
			row.append(opcell);
		}
		
		
		
		// row.append($('<td></td>').attr("width", "10%").text(activitem.getRating()));
				
		activetable.append(row);
	}
	
	$('#activetable').html(activetable);	
}

function reDispCompleteTable()
{

	var completetable = $('<table></table>').addClass('dcb-basic').attr("id", "dcb-basic").attr("width", "70%");
	
	{
		var row = $('<tr></tr>').addClass('bar');
	
		["ID", "TaskType", "ShortDesc", "Started", "Completed", "---"].forEach( function (hname) {
		
			row.append($('<th></th>').text(hname));
		});
		
		completetable.append(row);	
	}
	
	
	var completelist = getTaskItemList(true);
	
	
	for(var ci in completelist)
	{
		var compitem = completelist[ci];
	
		// console.log(oneday + " " + dci);

		var row = $('<tr></tr>').addClass('bar');
	
		// row.append($('<td></td>').text(possitem.getId()));
		row.append($('<td></td>').attr("width", "5%").text(compitem.getId()));
		
		row.append($('<td></td>').attr("width", "8%").text(compitem.getTaskType()));
		
		row.append($('<td></td>').text(compitem.getShortDesc()));			
				
		row.append($('<td></td>').attr("width", "15%").text(compitem.getAlphaDate()));
		
		row.append($('<td></td>').attr("width", "15%").text(compitem.getOmegaDate()));
			
				
		// row.append($('<td></td>').attr("width", "10%").text(activitem.getRating()));
				
		{
			var opcell = $('<td></td>').attr("width", "5%");
		

			{
				// var deletejs = "javascript:deleteItem(" + possitem.getId() + ", '" + possitem.getShortname() + "')";
			
				var studyurl = "MiniTaskDetail.jsp?id=" + compitem.getId();
				
				
				var studyref = $('<a></a>').attr("href", studyurl).append(
										$('<img></img>').attr("src", "/life/image/inspect.png").attr("height", 18)
								);
				
				opcell.append(studyref);
			} 
			
						
			row.append(opcell);
		}		
		
		
		completetable.append(row);
	}
	
	$('#completetable').html(completetable);	
}

function reDispEditItem()
{
	if(EDIT_STUDY_ITEM == -1)
		{ return; }
	
	var studyitem = getStudyItem();

	$('#taskid').html(studyitem.getId());	

	$('#shortdesc').html(studyitem.getShortDesc());	
	
	$('#tasktype').html(studyitem.getTaskType());	
	
	$('#alphadate').html(studyitem.getAlphaDate());	
	
	$('#omegadate').html(studyitem.getOmegaDate());	

	$('#int_prior').html(studyitem.getPriority());	

	$('#eff_prior').html(getEffectivePriority(studyitem).toFixed(2));
	
	var extrainfo = studyitem.getExtraInfo();
	if(extrainfo.length == 0)
		{ extrainfo = "Not Yet Set"; }
	
	const extralinelist = extrainfo.replace(/\n/g, "<br/>");
	$('#extrainfo').html(extralinelist);
	
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

<a name="truebutton" class="css3button" onclick="javascript:createNew('crm')">crm</a>

&nbsp;
&nbsp;
&nbsp;
&nbsp;

<a name="truebutton" class="css3button" onclick="javascript:createNew('life')">life</a>

&nbsp;
&nbsp;
&nbsp;
&nbsp;

<a name="truebutton" class="css3button" onclick="javascript:createNew('work')">work</a>

<br/>
<br/>


<form>
<input type="radio" name="show_task_type" value="all" onChange="javascript:redisplay()">
<label>All</label>
<%= HtmlUtil.nbsp(4) %>

<input type="radio" name="show_task_type" value="crm" onChange="javascript:redisplay()">
<label>CRM</label>
<%= HtmlUtil.nbsp(4) %>


<input type="radio" name="show_task_type" value="life" onChange="javascript:redisplay()" checked>
<label>Life</label>
<%= HtmlUtil.nbsp(4) %>


<input type="radio" name="show_task_type" value="work" onChange="javascript:redisplay()">
<label>Work</label>
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

<table id="dcb-basic" width="50%">
<tr>
<td>Back</td>
<td><a href="javascript:return2Main()"><img src="/life/image/leftarrow.png" height="18"/></a></td>
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

<a href="javascript:editItemName()"><img src="/life/image/edit.png" height="18"></a>

</td>
</tr>
<tr>
<td>TaskType</td>
<td><span id="tasktype"></span></td>
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
<td>Intrinsic Priority</td>
<td><span id="int_prior"></span>

&nbsp;
&nbsp;
&nbsp;

<a href="javascript:editStudyItemPriority()"><img src="/life/image/edit.png" height="18"></a>
</td>
</tr>
<tr>
<td>Effective Priority</td>
<td><span id="eff_prior"></span></td>
</tr>

</table>

<br/><br/>

<table id="dcb-basic" width="50%" border="0">
<tr>
<td>
<span id="extrainfo"></span>
</td>

<td width="10%">
<a href="javascript:toggleHidden4Class('edit_info')"><img src="/life/image/edit.png" height="18"></a>
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
<%= HtmlUtil.nbsp(4) %>
<a class="css3button" onclick="javascript:toggleHidden4Class('edit_info')">cancel</a>

</span>

</span>

</center>

</body>
</html>