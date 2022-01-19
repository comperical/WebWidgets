
<%@ page import="java.util.*" %>

<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@ page import="lifedesign.basic.*" %>
<%@ page import="lifedesign.classic.*" %>

<%@include file="../../admin/AuthInclude.jsp_inc" %>

<%
	ArgMap argMap = HtmlUtil.getArgMap(request);
	
	OptSelector ratingSel = new OptSelector(Util.range(1, 10));
	
	DayCode todayCode = DayCode.getToday();
		
	List<String> taskTypeList = Util.listify("crm", "life", "digi");
	
	OptSelector taskTypeSel = new OptSelector(taskTypeList).addKey("all");
	
%>

<html>
<head>
<title>Mini Task Archive</title>

<%= DataServer.basicInclude(request) %>

<script>

var TODAY_CODE = getTodayCode();

// Gets the task's age. 
// For purposes of efficiency, caller should supply a reference to todaycode
function getTaskAge(thetask)
{
	var alphadc = lookupDayCode(thetask.getAlphaDate());
	
	return alphadc.daysUntil(TODAY_CODE);
}

function deleteItem(killid)
{
	if(confirm("Are you sure you want to delete item " + killid + " ?"))
	{
		lookupItem("mini_task_list", killid).deleteItem();
		redisplay();
	}
}

function activateItem(itemid)
{
	var theitem = lookupItem("mini_task_list", itemid);
	
	if(confirm("Do you want to activate item " + theitem.getShortDesc()))
	{
		theitem.setIsBacklog(0);
		theitem.setAlphaDate(getTodayCode().getDateString());
		
		syncSingleItem(theitem);		
		redisplay();		
	}
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


function getTaskItemList(wantcompleted)
{
	var tasklist = [];
	
	var biglist = getItemList("mini_task_list");
		
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
		
		if(tasklist.length > 50)
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

function getShowType()
{
	return getDocFormValue('show_type');
}

function redisplay()
{

	var activelist = getTaskItemList(false);
	
	// Sort by effective priority
	// activelist.sort(proxySort(actrec => [-getEffectivePriority(actrec)]));
	
				
	var activetable = $('<table></table>').addClass('dcb-basic').attr("id", "dcb-basic").attr("width", "75%");
	
	{
		var row = $('<tr></tr>').addClass('bar');
	
		["ID", "TaskType", "ShortDesc", "Priority", "---"].forEach( function (hname) {
		
			row.append($('<th></th>').text(hname));
		});
		
		activetable.append(row);	
	}
		
	var showtype = getShowType();
		
	for(var ai in activelist)
	{
		var activitem = activelist[ai];
	
		if(activitem.getTaskType() != showtype)
			{ continue; }
		
		if(activitem.getIsBacklog() != 1)
			{ continue; }
	
		var row = $('<tr></tr>').addClass('bar');
	
		// row.append($('<td></td>').text(possitem.getId()));
		row.append($('<td></td>').attr("width", "5%").text(activitem.getId()));
		row.append($('<td></td>').attr("width", "7%").text(activitem.getTaskType()));
		row.append($('<td></td>').text(activitem.getShortDesc()));			
						
			
		{
			var opcell = $('<td></td>').attr("width", "15%");
			
			opcell.append(activitem.getPriority()+"");
			
			for(var i = 0; i < 4; i++)
				{ opcell.append("&nbsp;"); }
			
			var decprijs = "javascript:editItemPriority(" + activitem.getId() + ")";
			
			var decpriref = $('<a></a>').attr("href", decprijs).append($('<img></img>').attr("src", "/u/shared/image/edit.png").attr("height", 16));;
				
			opcell.append(decpriref);
			
			row.append(opcell);
		}
		
				
		{
			var opcell = $('<td></td>').attr("width", "15%");
		
			{
				// var deletejs = "javascript:deleteItem(" + possitem.getId() + ", '" + possitem.getShortname() + "')";
			
				var deletejs = "javascript:activateItem(" + activitem.getId() + ")";
				
				
				var deleteref = $('<a></a>').attr("href", deletejs).append(
										$('<img></img>').attr("src", "/u/shared/image/leftarrow.png").attr("height", 18)
								);
				
				opcell.append(deleteref);
			} 
			
			opcell.append("&nbsp;");
			opcell.append("&nbsp;");
			opcell.append("&nbsp;");			
						
			{
				// var deletejs = "javascript:deleteItem(" + possitem.getId() + ", '" + possitem.getShortname() + "')";
			
				var studyurl = "MiniTaskDetail.jsp?id=" + activitem.getId();
				
				
				var studyref = $('<a></a>').attr("href", studyurl).append(
										$('<img></img>').attr("src", "/u/shared/image/inspect.png").attr("height", 18)
								);
				
				opcell.append(studyref);
			} 
			
			opcell.append("&nbsp;");
			opcell.append("&nbsp;");
			opcell.append("&nbsp;");			
			

			
			{
				// var deletejs = "javascript:deleteItem(" + possitem.getId() + ", '" + possitem.getShortname() + "')";
			
				var deletejs = "javascript:deleteItem(" + activitem.getId() + ")";
				
				
				var deleteref = $('<a></a>').attr("href", deletejs).append(
										$('<img></img>').attr("src", "/u/shared/image/remove.png").attr("height", 18)
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

function setDefaultShow()
{
	var params = getUrlParamHash();
	
	if('default_show' in params)
	{
		getUniqElementByName('show_type').value = params['default_show'];
		console.log(params);
	}
	
	redisplay();
}


</script>

</head>

<body onLoad="javascript:setDefaultShow()">


<center>

<h3>Mini Task Archive &nbsp; &nbsp; &nbsp; <a href="widget.jsp">active</a></h3>

<form>
<h4>Category: &nbsp; &nbsp; <select name="show_type" onChange="javascript:redisplay()">
<option value="crm">CRM</option>
<option value="life">Life</option>
<option value="work">Work</option>
</select></h4>
</form>

<br/>

<div id="activetable"></div>

<br/><br/>


</body>
</html>
