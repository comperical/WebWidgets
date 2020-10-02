
<%@ page import="java.util.*" %>

<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.DbUtil.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@ page import="lifedesign.basic.*" %>
<%@ page import="lifedesign.classic.*" %>

<%@include file="../../life/AuthInclude.jsp_inc" %>

<%
	String pageTitle = "Workout Log";

	OptSelector dayCodeSel = LifeUtil.standardDateSelector(14);

	OptSelector intSelector = new OptSelector(Util.range(1, 10));
%>

<html>
<head>
<title>Workout Log</title>

<%@include file="../../life/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

<script src="WorkoutLogger.js"></script>


<script>

_BIG_GOAL_MAP = new Map();

EXERCISE_TYPE = "body";

function deleteItem(killid)
{
	if(confirm("Are you sure you want to remove this record?"))
	{
		lookupItem("workout_log", killid).deleteItem();
		redisplay();		
	}
}

function reBuildGoalFromTemplate(mondaycode)
{
	const message = "This will (re)-build your weekly goal for " + mondaycode + " from the template. Okay?";
	
	if(!confirm(message))
		{ return; }
	
	const todaycode = getTodayCode().getDateString();
	const planitems = getItemList("exercise_plan");
	
	planitems.forEach(function(pitem) {
			
		const newid = newBasicId("ex_week_goal");
		
		// Skip inactive
		if(pitem.getIsActive() == 0)
			{ return; }
		
		const newrec = {
			"id" : newid,
			"mini_note" : "Created on : " + todaycode,
			"monday_code" : mondaycode,
			"short_code" : pitem.getShortCode(),
			"weekly_goal" : pitem.getWeeklyGoal()
		};
		
		const newitem = buildExWeekGoalItem(newrec);
		newitem.registerNSync();
	});
	
	redisplay();
}

function enterFailedRecordList(mondaycode)
{
	const message = "This will enter FAIL records for this week, so you can start the next week from a clean slate! Okay?";
	
	if(!confirm(message))
		{ return; }
	
	const wologger = new WorkoutLogger(getItemList("workout_log"), getItemList("ex_week_goal"));
	
	const statusmap = wologger.getSummaryData(mondaycode);
	
	const yesterday = getTodayCode().dayBefore().getDateString();
	
	Object.keys(statusmap).forEach(function(wotype) {
			
		const wosum = statusmap[wotype];
		const shortfall = wosum[1] - wosum[0];
		
		if(shortfall <= 0)
			{ return; }
		
		if(getExType4Code(wotype) != EXERCISE_TYPE)
			{ return; }
		
		const newrec = {
			
			"id" : newBasicId("workout_log"),
			"day_code" : yesterday,
			"wo_type" : wotype,
			"wo_units" : shortfall,
			"notes" : "FAIL",
			"hole_fill" : ""
		};

		const newitem = buildWorkoutLogItem(newrec);
		newitem.registerNSync();
	});
	
	redisplay();
}

function editItemNotes(editid)
{
	var myitem = lookupItem("workout_log", editid);
	
	var newnotes = prompt("Notes for this item: ", myitem.getNotes());
	
	if(newnotes)
	{
		myitem.setNotes(newnotes);
		syncSingleItem(myitem);
		redisplay();		
	}
}

function getEffectiveDate(woitem)
{
	const hole = woitem.getHoleFill();
	return hole != "" ? hole : woitem.getDayCode();
}

function createItem()
{
	// workout_log (id int, day_code varchar(10), wo_type varchar(20), wo_units int, notes varchar(100), primary key(id));	
	var newid = newBasicId("workout_log");
		
	var payload = subPackFromFormNames(["day_code", "wo_type", "wo_units"]);
			
	payload["id"] = newid;
	payload["notes"] = "";
	payload["hole_fill"] = "";
		
	var newitem = buildWorkoutLogItem(payload);
		
	newitem.registerNSync();
		
	redisplay();	
	
}

function createLazyItem()
{
	// workout_log (id int, day_code varchar(10), wo_type varchar(20), wo_units int, notes varchar(100), primary key(id));	
	var newid = newBasicId("workout_log");
		
	var payload = subPackFromFormNames(["day_code"]);

	payload["id"] = newid;
	payload["wo_type"] = getDocFormValue("wo_type");
	payload["wo_units"] = 0;
	payload["hole_fill"] = "";
	payload["notes"] = "LAZY";
		
	var newitem = buildWorkoutLogItem(payload);
	newitem.registerNSync();
	redisplay();
}

// This is the workout type that is selected in the drop-down for adding.
// Need this to populate units field correctyly.
function workoutType2Show()
{
	return getDocFormValue("wo_type");
}

function getPlanItem(shortcode)
{
	const planlist = getItemList("exercise_plan").filter(pln => pln.getShortCode() == shortcode);
	return planlist.length > 0 ? planlist[0] : null;
}

function getDistanceDefaultPrompt()
{
	const wocode = workoutType2Show();
	const planitem = getPlanItem(wocode);
	return planitem == null ? 2 : planitem.getUsualDistance();
}

function getUnitCode(shortcode, mondaycode)
{
	const planitem = getPlanItem(shortcode);
	return planitem == null ? "???" : planitem.getUnitCode();
}

function getExType4Code(shortcode)
{
	const planitem = getPlanItem(shortcode);
	return planitem == null ? "body" : planitem.getExType();
}

function getRecentMonday()
{
	return getMondayList()[0];
}

function getMondayList()
{
	var mondays = [];
	
	var daycode = getTodayCode();
	
	for(var i = 0; i < 70; i++)
	{
		if(daycode.getShortDayOfWeek() == "Mon") 
			{ mondays.push(daycode.getDateString()); }
		
		daycode = daycode.dayBefore();
	}
	
	return mondays;
}

function isWeekComplete(sumdata)
{
	const keylist = Object.keys(sumdata);
	
	for(var wi in keylist)
	{
		const wotype = keylist[wi];
		const onepair = sumdata[wotype]; 

		if(getExType4Code(wotype) != EXERCISE_TYPE)
			{ continue; }
				
		if(onepair[0] < onepair[1])
			{ return false; }		
	}
	
	return true;
}

function getActiveExerciseCodeList()
{
	return getItemList("exercise_plan")
			.filter(function(ai) { return ai.getIsActive() == 1; })
			.filter(function(ai) { return ai.getExType() == EXERCISE_TYPE; })
			.map(function(ai) { return ai.getShortCode(); });	
}

function buildInitial()
{
	const actlist = getActiveExerciseCodeList().sort();
	
	const workoptsel = buildOptSelector()
				.setSelectOpener(`<select name="wo_type" onChange="javascript:redisplay()">`)
				.setKeyList(actlist);
				
	document.getElementById("wo_type_span").innerHTML = workoptsel.getSelectString();
	
	redisplay();
}

function redisplay()
{		
	const wologger = new WorkoutLogger(getItemList("workout_log"), getItemList("ex_week_goal"));
	
	const workouttype = workoutType2Show();
	
	getUniqElementByName("wo_units").value = getDistanceDefaultPrompt();
	
	document.getElementById("unit_info").innerHTML = getUnitCode(workouttype, getRecentMonday());
	
	
	var dcstr = "";

	// var workoutlist = getItemList("workout_log").filter(wo => wo.getWoType() == workouttype);
	const workoutlist = getItemList("workout_log");
	
	// TODO: just return a limited number of Mondays here to avoid rendering years of data.
	var mondaylist = getMondayList();
	// const startmonday = getStartingMonday(workouttype);
	
	mondaylist.forEach(function(themonday) {
		
		const goaltable = getWeeklyGoalTable(wologger, themonday);
		
		const logtable = getWeeklyLogTable(wologger, themonday);
		
		dcstr += `
			<h3>Week of ${themonday.substring(5)}</h3>
			<table width="100%">
			<tr>
			<td width="40%" align="center" style="vertical-align: top;">
			<h4>Goal</h4>
			${goaltable}
			</td>
			<td align="center">
			${logtable}
			</td>
			</tr>
			</table>
			<br/>
			<br/>
		`;
	});
	
	document.getElementById("double_column_table").innerHTML = dcstr;
	

	
}

function getWeeklyLogTable(wologger, themonday)
{
	var weeklist = wologger.getWorkouts4Monday(themonday);
		
	var logstr = "";
	
	logstr += `
	<h4>Log</h4>
	<table id="dcb-basic" class="dcb-basic" width="95%">
	<tr>
	<th>Day</th>
	<th>Date</th>
	<th>Type</th>
	<th>Length</th>
	<th>Notes</th>
	<th>...</th>
	</tr>
	`;
	
	weeklist.sort(proxySort(a => [a.getDayCode()])).reverse();
	
	
	weeklist.forEach(function(woitem) {
			
		const shortdow = lookupDayCode(woitem.getDayCode()).getShortDayOfWeek();
		
		logstr += `
		<tr>
		<td>${woitem.getDayCode().substring(5)}</td>
		<td>${shortdow}</td>
		<td>${woitem.getWoType()}</td>
		<td>${woitem.getWoUnits()}</td>
		<td>${woitem.getNotes()}</td>
		<td>
		<a href="javascript:editItemNotes(${woitem.getId()})"><img src='/life/image/edit.png' height='18'/></a>
		&nbsp;&nbsp;&nbsp;
		<a href="javascript:deleteItem(${woitem.getId()})"><img src='/life/image/remove.png' height='18'/></a>
		</td>
		</tr>
		`;
	});
	
	logstr += "</table>";	
	
	return logstr;
	
}

function getWeeklyGoalTable(wologger, themonday)
{	
	const summary = wologger.getSummaryData(themonday);

	const goalcount = getItemList("ex_week_goal").filter(gitem => gitem.getMondayCode() == themonday).length;
	
	if(goalcount == 0)
	{
		
		return `
		
			No Goals Defined
			<br/>
			<br/>
			
			<a class="css3button" onclick="javascript:reBuildGoalFromTemplate('${themonday}')">ADD</a>
		`;
	}
	
	const worktypes = Object.keys(summary).filter(wocode => getExType4Code(wocode) == EXERCISE_TYPE).sort();

	
	var goalstr = `
	<table id="dcb-basic" class="dcb-basic" width="90%">
	<tr>
	<th>WO Type</th>
	<th>Status</th>
	<th>Units</th>
	<th>...</th>
	</tr>
	`;
	
	var numcomplete = 0;
	var imlist = [];
	
	worktypes.forEach(function(wotype) {
			
		// This is weird
		var wounit = "??";
		try { wounit = getUnitCode(wotype); }
		catch (err) {} 
		
		const sumdata = summary[wotype];
		
		var imstr = "";
		
		if(sumdata[0] >= sumdata[1])
		{
			const anyfail = wologger.anyFailForBatch(themonday, wotype);
			const imcode = anyfail ? 'failure' : 'crown';
			imstr = `<img src="/life/image/${imcode}.png" height='22'/>`;
			imlist.push(imstr);
			numcomplete += 1;
		}
		
		goalstr += `
		<tr>
		<td>${wotype}</td>
		<td>${sumdata[0]} / ${sumdata[1]}</td>
		<td>${wounit}</td>
		<td>${imstr}</td>
		</tr>
		`;
	});
	
	const weekcomplete = isWeekComplete(summary);
	
	// Congratulations if you won!!
	if(weekcomplete)
	{
		goalstr += `
		<tr>
		<td colspan="4">
		${imlist.join('&nbsp;&nbsp;')}
		</td>
		</tr>			
		`;
	}		

	goalstr += "</table>";
	
	if(!weekcomplete)
	{
		goalstr += `
		
		<br/>
		<br/>
		<a class="css3button" onclick="javascript:enterFailedRecordList('${themonday}')">fail</a>
		
		`;
	}
	
	goalstr += `
	<br/><br/><br/>
	<a href="ExerciseTemplate.jsp">Template</a>
	&nbsp;	&nbsp;
	&nbsp;	&nbsp;
	<a href="ExercisePlanner.jsp">Planner</a>
	`;
	


	return goalstr;
}

</script>

</head>

<body onLoad="javascript:buildInitial()">




<center>

<h2>Workout Log</h2>

<center>

<table id="1" width="95%">

<tr>
<td width="40%" align="center">



</td>
<td align="center">

<h3 style="display: inline;">Workout Type:</h3>
<span id="wo_type_span">

</span>


<br/>

Date:
<select name="day_code">
<%= dayCodeSel.getSelectStr(DayCode.getToday().dayBefore()) %>
</select>
<br/>

<span id="unit_info"></span> : 
<select name="wo_units">
<%= intSelector.getSelectStr("1") %>
</select>

<br/><br/>

<a class="css3button" onclick="javascript:createItem()">ADD</a>

<%= HtmlUtil.nbsp(4) %>

<a class="css3button" onclick="javascript:createLazyItem()">LAZY</a>

<br/>
<br/>

</td>
</tr>
</table>

<span id="double_column_table"></span>

</center>
</body>
</html>
