
<html>
<head>
<title>Exercise Planner</title>

<wisp/>

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


function updateGoalTarget(goalid)
{
	const goalitem = W.lookupItem("ex_week_goal", goalid);
	const newgoal = prompt("Enter a new goal target: ", goalitem.getWeeklyGoal());

	if(newgoal)
	{
		if(!okayInt(newgoal))
		{
			alert("Please enter an integer");
			return;
		}

		goalitem.setWeeklyGoal(newgoal);
		goalitem.syncItem();
		redisplay();
	}
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

	const planNameDict = buildGenericDict(W.getItemList("exercise_plan"), item => item.getShortCode(), item => item);

	var mainlog = "";
	const workoutlist = W.getItemList("ex_week_goal");
	const mondaylist = getMondayList().sort().reverse();
	
	mondaylist.forEach(function(themonday) {

		var weeklist =  workoutlist.filter(witem => witem.getMondayCode() == themonday);
		weeklist.sort(proxySort(a => [a.getShortCode()]));
				
		mainlog += `
			<h3>Week of ${themonday.substring(5)}</h3>
			<a class="css3button" href="javascript:rebuildFromActiveLayout('${themonday}')">REBUILD</a>
			<br/>
			<br/>
		`;
		
		var tablestr = `
			<table class="basic-table" width="60%">
			<tr>
			<th>Code</th>
			<th colspan="2">Week Goal</th>

			<th>Notes</th>
			<th>...</th>
			</tr>
		`;

		weeklist.forEach(function(woitem) {

			const planitem = planNameDict[woitem.getShortCode()];
			
			const rowstr = `
				<tr>
				<td>${woitem.getShortCode()}</td>
				<td>${woitem.getWeeklyGoal()}  ${planitem.getUnitCode()}</td>

				<td>
				<a href="javascript:updateGoalTarget(${woitem.getId()})")">
				<img src="/u/shared/image/edit.png" height="18"/></a>
				</td>
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
