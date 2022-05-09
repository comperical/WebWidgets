
<html>
<head>
<title>Exercise Planner</title>

<%= DataServer.basicInclude(request) %>

<script src="WorkoutLogger.js"></script>


<script>


function handleNavBar() 
{
    const current = "W/O Planner";

    populateTopNavBar(WO_HEADER_INFO, current);
}

function deleteItem(killid)
{
	if(confirm("DON'T BE LAZY - are you sure you want to delete this item??"))
	{
		W.lookupItem("ex_week_goal", killid).deleteItem();
		redisplay();		
	}
}

function editMiniNote(editid)
{
	var myitem = W.lookupItem("ex_week_goal", editid);
	
	var newnotes = prompt("Notes for this item: ", myitem.getMiniNote());
	
	if(newnotes)
	{
		myitem.setMiniNote(newnotes);
		myitem.syncItem();
		redisplay();		
	}
}

function rebuildWeek(mondaycode)
{
	if(!confirm("This will delete all the previous goal items for this week, and rebuild them from the template. Okay?"))
		{ return; }
	
	const olditems = W.getItemList("ex_week_goal").filter(exitem => exitem.getMondayCode() == mondaycode);
	
	// Gotcha here: if you delete before create, the new items will get reallocated the IDs deleted previously.
	// So if the delete operations get processed after the create operations because of race condition,
	// you will end up deleting the records you just built.
	const tempitems = W.getItemList("exercise_plan");
	
	tempitems.forEach(function(titem) {
			
		if(titem.getIsActive() != 1)
			{ return; }
		
		const newrec = {
			"mini_note" : "...",
			"monday_code" : mondaycode,
			"short_code" : titem.getShortCode(),
			"weekly_goal" : titem.getWeeklyGoal()
		};
		
		const newitem = W.buildItem("ex_week_goal", newrec);
		newitem.syncItem();			
	});
	
	// Delete AFTER assigning new IDs
	olditems.forEach(exitem => exitem.deleteItem());

	redisplay();
	
}

function getPlanItem(shortcode)
{
	const planlist = W.getItemList("exercise_plan").filter(pln => pln.getShortCode() == shortcode);
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
	handleNavBar();

	var mainlog = "";
	const workoutlist = W.getItemList("ex_week_goal");
	const mondaylist = getMondayList().sort().reverse();
	
	mondaylist.forEach(function(themonday) {

		var weeklist =  workoutlist.filter(witem => witem.getMondayCode() == themonday);
		weeklist.sort(proxySort(a => [getExType4Code(a), a.getId()]));
				
		mainlog += `
			<h3>Week of ${themonday.substring(5)}</h3>
			<a class="css3button" href="javascript:rebuildWeek('${themonday}')">REBUILD</a>
			<br/>
			<br/>
		`;
		
		var tablestr = `
			<table class="basic-table" width="60%">
			<tr>
			<th>Type</th>
			<th>Code</th>
			<th>Week Goal</th>
			<th>Notes</th>
			<th>...</th>
			</tr>
		`;

		weeklist.forEach(function(woitem) {

			const extype = getExType4Code(woitem.getShortCode());
			
			const rowstr = `
				<tr>
				<td>${extype}</td>
				<td>${woitem.getShortCode()}</td>
				<td>${woitem.getWeeklyGoal()}</td>
				<td>${woitem.getMiniNote()}</td>
				<td>
				<a href="javascript:editMiniNote(${woitem.getId()})">
				<img src='/u/shared/image/edit.png' height="18"/></a>
				&nbsp;&nbsp;
			
				<a href="javascript:deleteItem(${woitem.getId()})">
				<img src="/u/shared/image/remove.png" height="18"/></a>
				</td>
				</tr>
			`;
			
			const data = [woitem.getId(), getExType4Code(woitem.getShortCode()), 
						woitem.getWeeklyGoal(), 
						getUnitCode(woitem.getShortCode()),
						woitem.getMiniNote(), woitem.getShortCode()];
			
			tablestr += rowstr;
		});
		
		tablestr += `</table>`;

		mainlog += tablestr;		
		mainlog += "<br/>";
	});
	
	document.getElementById("complete_log").innerHTML = mainlog;
}



</script>

</head>

<body onLoad="javascript:redisplay()">




<center>

<div class="topnav"></div>

<br/>

<center>

<div id="complete_log"></div>


</center>
</body>
</html>
