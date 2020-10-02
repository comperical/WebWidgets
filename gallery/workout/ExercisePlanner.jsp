
<%@ page import="java.util.*" %>

<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.DbUtil.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@ page import="lifedesign.basic.*" %>
<%@ page import="lifedesign.classic.*" %>

<%@include file="../../life/AuthInclude.jsp_inc" %>

<html>
<head>
<title>Exercise Planner</title>

<%@include file="../../life/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

<script>


function deleteItem(killid)
{
	if(confirm("DON'T BE LAZY - are you sure you want to delete this item??"))
	{
		lookupItem("ex_week_goal", killid).deleteItem();
		redisplay();		
	}
}

function editMiniNote(editid)
{
	var myitem = lookupItem("ex_week_goal", editid);
	
	var newnotes = prompt("Notes for this item: ", myitem.getMiniNote());
	
	if(newnotes)
	{
		myitem.setMiniNote(newnotes);
		syncSingleItem(myitem);
		redisplay();		
	}
}

function rebuildWeek(mondaycode)
{
	if(!confirm("This will delete all the previous goal items for this week, and rebuild them from the template. Okay?"))
		{ return; }
	
	
	const olditems = getItemList("ex_week_goal").filter(exitem => exitem.getMondayCode() == mondaycode);
	
	// Gotcha here: if you delete before create, the new items will get reallocated the IDs deleted previously.
	// So if the delete operations get processed after the create operations because of race condition,
	// you will end up deleting the records you just built.
	const tempitems = getItemList("exercise_plan");
	
	tempitems.forEach(function(titem) {
			
		if(titem.getIsActive() != 1)
			{ return; }
		
		const newid = newBasicId("ex_week_goal");
		const newrec = {
			"id" : newid,
			"mini_note" : "...",
			"monday_code" : mondaycode,
			"short_code" : titem.getShortCode(),
			"weekly_goal" : titem.getWeeklyGoal()
		};
		
		const newitem = buildExWeekGoalItem(newrec);
		newitem.registerNSync();			
	});
	
	// Delete AFTER assigning new IDs
	olditems.forEach(exitem => exitem.deleteItem());

	redisplay();
	
}

function getPlanItem(shortcode)
{
	const planlist = getItemList("exercise_plan").filter(pln => pln.getShortCode() == shortcode);
	return planlist.length > 0 ? planlist[0] : null;
}

function getUnitCode(shortcode)
{
	const planitem = getPlanItem(shortcode);
	return planitem == null ? "???" : planitem.getUnitCode();
}

function getExType4Code(shortcode)
{
	const planitem = getPlanItem(shortcode);
	return planitem == null ? "body" : planitem.getExType();
}

function getMondayList()
{
	var daylist = [];
	var oneday = getTodayCode();
	
	while(daylist.length < 50)
	{
		daylist.push(oneday);
		oneday = oneday.dayBefore();
	}
	
	return daylist
		.filter(dc => dc.getDayOfWeek().toLowerCase() == "monday")
		.map(dc => dc.dateString);
}

function redisplay()
{
	var mainlog = $('<p></p>');
		
	// var workoutlist = getItemList("workout_log").filter(wo => wo.getWoType() == workouttype);
	const workoutlist = getItemList("ex_week_goal");

	var mondaylist = getMondayList().sort().reverse();
	
	// const unitinfo = getUnitInfo(workouttype);
	
	// const startmonday = getStartingMonday(workouttype);
	
	for(const mi in mondaylist)
	{
		const themonday = mondaylist[mi];
				
		var weeklist =  workoutlist.filter(witem => witem.getMondayCode() == themonday);
		weeklist.sort(proxySort(a => [getExType4Code(a), a.getId()]));
				
		mainlog.append("<h3>Week Of " + themonday.substring(5) + "</h3>");
		
		mainlog.append("<a class=\"css3button\" href=\"javascript:rebuildWeek('" + themonday + "')\">REBUILD</a><br/></br/>");

		var mytable = $('<table></table>').addClass('dcb-basic').attr("id", "dcb-basic").attr("width", "60%");
		
		{
			var row = $('<tr></tr>').addClass('bar');
		
			["Type", "Code", "Week Goal",  "Notes", "..."].forEach( function (hname) {
			
				row.append($('<th></th>').text(hname));
			});
			
			mytable.append(row);	
		}		
			
		

		const trcomposer = (new ComposerTool())
					.append("<tr><td>{2}</td>")
					.append("<td>{6}</td>")
					.append("<td>{3}  {4}</td>")
					.append("<td>{5}</td>")	
					.append("<td>")
					.append("<a href='javascript:editMiniNote({1})'><img src='/life/image/edit.png' height='18'/></a>")
					.append("&nbsp; &nbsp; ")			
					.append("<a href='javascript:deleteItem({1})'><img src='/life/image/remove.png' height='18'/></a>")
					.append("</td>")
					.append("</tr>");

		for(var wi in weeklist)
		{
			const woitem = weeklist[wi];
			// const effdate = getEffectiveDate(woitem);
			// var shortdow = lookupDayCode(effdate).getShortDayOfWeek();
			// var shownotes = woitem.getNotes();
			
			//if(effdate != woitem.getDayCode())
			//	{ shownotes = "Catchup=" + woitem.getDayCode().substring(5) + "    " + shownotes; }
	
			const data = [woitem.getId(), getExType4Code(woitem.getShortCode()), 
						woitem.getWeeklyGoal(), 
						getUnitCode(woitem.getShortCode()),
						woitem.getMiniNote(), woitem.getShortCode()];
			
			mytable.append(trcomposer.listFormat(data));
		}
		
		mainlog.append(mytable);		
		
		mainlog.append("<br/>");
	}
		
	// $('#unit_info').html(unitinfo);
	
	$('#complete_log').html(mainlog);
	
}



</script>

</head>

<body onLoad="javascript:redisplay()">




<center>

<h2>Exercise Planner</h2>

<a href="ExerciseTemplate.jsp">Template</a> --- 
<a href="widget.jsp">Workouts</a>


<center>

<div id="complete_log"></div>


</center>
</body>
</html>
