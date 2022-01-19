
<%@ page import="java.util.*" %>


<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>


<%@ page import="lifedesign.basic.*" %>

<%@include file="../../admin/AuthInclude.jsp_inc" %>

<%
%>

<html>
<head>
<title>Exercise Template</title>

<script src="/life/jscript/jquery-1.4.2.js"></script>

<%= DataServer.basicInclude(request) %>

<script>

function createNew()
{	
	var shortcode = prompt("ShortCode for item: ");
	
	if(shortcode)
	{	
		var newid = newBasicId("exercise_plan");
				
		// created_on, active_on, completed_on, dead_line
		var comrecord = {
			"id" : newid,
			"ex_type" : "body",
			"unit_code" : "hours",
			"weekly_goal" : 2,
			"short_code" : shortcode,
			"full_desc": "...",
			"usual_distance" : 2,
			"is_active" : 1
		};
		
		console.log(Object.keys(comrecord));
		var newitem = buildExercisePlanItem(comrecord);
		newitem.syncItem();
		redisplay();
	}
}

function toggleItemActive(itemid)
{
	genericToggleActive("exercise_plan", itemid);
	redisplay();
}

function redisplay()
{	
	
	var activetable = $('<table></table>').addClass('basic-table').attr("width", "60%");
	
	var headerlist = ["ID", "Category", "ShortName", "Weekly Goal", "Active?", "---"];
	
	
	
	{
		var row = $('<tr></tr>').addClass('bar');
		
		headerlist.forEach( function (hname) {
				
				row.append($('<th></th>').text(hname));
		});
		
		activetable.append(row);	
	}
	
		
	var activelist = getItemList("exercise_plan");
	activelist.sort(proxySort(a => [a.getExType(), a.getId()]));

	for(var ai in activelist)
	{
		var activitem = activelist[ai];
		
		//if(showtypelist.indexOf(activitem.getTaskType()) == -1)
		//	{ continue; }
		
		
		// console.log("Task type is " + activitem.getTaskType() + ",  checked is " + showcbox.checked);
		
		// console.log(oneday + " " + dci);
		
		var row = $('<tr></tr>').addClass('bar');
		
		
		// row.append($('<td></td>').text(possitem.getId()));
		row.append($('<td></td>').attr("width", "5%").text(activitem.getId()));
		
		row.append($('<td></td>').text(activitem.getExType()));
		row.append($('<td></td>').text(activitem.getShortCode()));
		row.append($('<td></td>').text(activitem.getWeeklyGoal() + "  " + activitem.getUnitCode()));
		row.append($('<td></td>').text(activitem.getIsActive() == 1 ? "YES" : "NO"));
		
		{
			var opcell = $('<td></td>').attr("width", "15%");
			
			{
				var studylink = "StudyExerciseItem.jsp?item_id=" + activitem.getId();
				
				var incpriref = $('<a></a>').attr("href", studylink).append($('<img></img>').attr("src", "/u/shared/image/inspect.png").attr("height", 18));;
				
				opcell.append(incpriref);
				opcell.append("&nbsp;");
				opcell.append("&nbsp;");
				opcell.append("&nbsp;");
			}				
			
			{				
				var deletejs = "javascript:toggleItemActive(" + activitem.getId() + ")";
				
				var deleteref = $('<a></a>').attr("href", deletejs).append(
					$('<img></img>').attr("src", "/u/shared/image/cycle.png").attr("height", 18)
					);
				
				opcell.append(deleteref);
			} 
			
			opcell.append("&nbsp;");
			opcell.append("&nbsp;");
			opcell.append("&nbsp;");			
				
			row.append(opcell);
		}		
		
		activetable.append(row);
	}
	
	$('#activetable').html(activetable);	
		

}




</script>

</head>

<body onLoad="javascript:redisplay()">


<center>

<h2>Exercise Template</h2>

<a href="ExercisePlanner.jsp"><button>planner</button></a>
&nbsp;
&nbsp;
&nbsp;
<a href="widget.jsp"><button>workouts</button></a>


<br/><br/>

<div id="activetable"></div>

<br/><br/>

<%= HtmlUtil.nbsp(4) %>

<a class="css3button" onclick="javascript:createNew()">new</a>

</form>


</body>
</html>
