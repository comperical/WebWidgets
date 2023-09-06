
<html>
<head>
<title>&#x1F605 &#x1F4A6</title>

<%= DataServer.include(request) %>

<script src="WorkoutLogger.js"></script>

<script>

_BIG_GOAL_MAP = new Map();

SHOW_LINEAR_MODE = false;

EXERCISE_TYPE = "body";

function handleNavBar() 
{
    const current = "W/O Log";

    populateTopNavBar(WO_HEADER_INFO, current);
}

function deleteItem(killid)
{
	if(confirm("Are you sure you want to remove this record?"))
	{
		W.lookupItem("workout_log", killid).deleteItem();
		redisplay();		
	}
}

function enterFailedRecordList(mondaycode)
{
	const message = "This will enter FAIL records for this week, so you can start the next week from a clean slate! Okay?";
	
	if(!confirm(message))
		{ return; }
	
	const wologger = new WorkoutLogger(W.getItemList("workout_log"), W.getItemList("ex_week_goal"));
	
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
			"day_code" : yesterday,
			"wo_type" : wotype,
			"wo_units" : shortfall,
			"notes" : "FAIL",
			"hole_fill" : ""
		};

		const newitem = W.buildItem("workout_log", newrec);
		newitem.syncItem();
	});
	
	redisplay();
}

function editItemNotes(editid)
{
	var myitem = W.lookupItem("workout_log", editid);
	
	var newnotes = prompt("Notes for this item: ", myitem.getNotes());
	
	if(newnotes)
	{
		myitem.setNotes(newnotes);
		myitem.syncItem();
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
	const payload = {
		"notes" : "",
		"hole_fill" : "",
		"day_code" : getDocFormValue("day_code_sel"),
		"wo_type" : getDocFormValue("wo_type"),
		"wo_units" : getDocFormValue("wo_units_sel")
	};
	
	const newitem = W.buildItem("workout_log", payload);		
	newitem.syncItem();
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
	const planlist = W.getItemList("exercise_plan").filter(pln => pln.getShortCode() == shortcode);
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

function toggleFormatMode()
{
	SHOW_LINEAR_MODE = !SHOW_LINEAR_MODE;
	redisplay();
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
	return W.getItemList("exercise_plan")
			.filter(function(ai) { return ai.getIsActive() == 1; })
			.filter(function(ai) { return ai.getExType() == EXERCISE_TYPE; })
			.map(function(ai) { return ai.getShortCode(); });	
}

function buildInitial()
{
	const actlist = getActiveExerciseCodeList().sort();
	
	buildOptSelector()
		.setElementName("wo_type")
		.setOnChange("javascript:redisplay()")
		.setKeyList(actlist)
		.autoPopulate();
	
	redisplay();
}

function redisplay()
{		
    handleNavBar();

	redispControls();

	const wologger = new WorkoutLogger(W.getItemList("workout_log"), W.getItemList("ex_week_goal"));
	
	const workouttype = workoutType2Show();
		
	document.getElementById("unit_info").innerHTML = getUnitCode(workouttype, getRecentMonday());
	
	
	const linearmap = getLinearMondayMap();

	var dcstr = "";

	// var workoutlist = getItemList("workout_log").filter(wo => wo.getWoType() == workouttype);
	const workoutlist = W.getItemList("workout_log");
	
	// TODO: just return a limited number of Mondays here to avoid rendering years of data.
	var mondaylist = getMondayList();
	// const startmonday = getStartingMonday(workouttype);
	
	mondaylist.forEach(function(themonday) {
		
		const goaltable = getWeeklyGoalTable(wologger, themonday);
		
		const logtable = getWeeklyLogTable(wologger, linearmap, themonday);
		
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
	
	const buttontext = SHOW_LINEAR_MODE ? "show logged" : "show linear";

	const formatbutton = `
		<a href="javascript:toggleFormatMode()">
		<button>${buttontext}</button>
		</a>
	`;

	populateSpanData({
		"show_format_button" : formatbutton,
		"double_column_table": dcstr
	});
}

function getLinearMondayMap()
{
	const linearmap = {};

	W.getItemList("workout_log").forEach(function(item) {
		const dc = lookupDayCode(item.getDayCode());
		const monday = getMonday4Date(dc).getDateString();
		if(!(monday in linearmap)) {
			linearmap[monday] = [];
		}

		linearmap[monday].push(item);
	});

	return linearmap;
}


function redispControls()
{
	buildOptSelector()
		.setKeyList([... Array(15).keys()])
		.setSelectedKey(getDistanceDefaultPrompt())
		.setElementName("wo_units_sel")
		.autoPopulate()

	const displaymap = getNiceDateDisplayMap(14);

	buildOptSelector()
		.setFromMap(displaymap)
		.setSelectedKey(getTodayCode().dayBefore().getDateString())
		.setElementName("day_code_sel")
		.autoPopulate();
}


function getWeeklyLogTable(wologger, linearmap, themonday)
{
	const weeklist = SHOW_LINEAR_MODE 
						? (themonday in linearmap ? linearmap[themonday] : []) 
						: wologger.getWorkouts4Monday(themonday);
		
	var logstr = `
		<h4>Log</h4>
		<table class="basic-table" width="95%">
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
		<a href="javascript:editItemNotes(${woitem.getId()})"><img src='/u/shared/image/edit.png' height='18'/></a>
		&nbsp;&nbsp;&nbsp;
		<a href="javascript:deleteItem(${woitem.getId()})"><img src='/u/shared/image/remove.png' height='18'/></a>
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

	const goalcount = W.getItemList("ex_week_goal").filter(gitem => gitem.getMondayCode() == themonday).length;
	
	if(goalcount == 0)
	{
		
		return `
		
			No Goals Defined
			<br/>
			<br/>
			
			<a class="css3button" onclick="javascript:rebuildFromActiveLayout('${themonday}')">ADD</a>
		`;
	}
	
	const worktypes = Object.keys(summary).filter(wocode => getExType4Code(wocode) == EXERCISE_TYPE).sort();

	
	var goalstr = `
	<table class="basic-table" width="90%">
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
			imstr = `<img src="/u/shared/image/${imcode}.png" height='22'/>`;
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



	return goalstr;
}

</script>

</head>

<body onLoad="javascript:buildInitial()">




<center>

<div class="topnav"></div>

<br/>

<center>

<table id="1" width="95%">

<tr>
<td width="40%" align="center">

<div id="show_format_button"></div>

</td>
<td align="center">

<h3 style="display: inline;">Workout Type:</h3>
<span id="wo_type_span"></span>


<br/>

<b>Date:</b>
<span id="day_code_sel_span"></span>
<br/>

<b><span id="unit_info"></span></b> : 

<span id="wo_units_sel_span"></span>

<br/><br/>

<a class="css3button" onclick="javascript:createItem()">ADD</a>

	<br/>
<br/>

</td>
</tr>
</table>

<span id="double_column_table"></span>

</center>
</body>
</html>
