
<html>
<head>
<title>Exercise Template</title>

<%= DataServer.basicInclude(request) %>

<script src="WorkoutLogger.js"></script>

<script>

function createNew()
{	
	var shortcode = prompt("ShortCode for item: ");
	
	if(shortcode)
	{					
		// created_on, active_on, completed_on, dead_line
		var comrecord = {
			"ex_type" : "body",
			"unit_code" : "hours",
			"weekly_goal" : 2,
			"short_code" : shortcode,
			"full_desc": "...",
			"usual_distance" : 2,
			"is_active" : 1
		};
		
		var newitem = buildItem("exercise_plan", comrecord);
		newitem.syncItem();
		redisplay();
	}
}

function toggleItemActive(itemid)
{
	genericToggleActive("exercise_plan", itemid);
	redisplay();
}

function handleNavBar() 
{
    const current = "W/O Template";

    populateTopNavBar(WO_HEADER_INFO, current);
}

function redisplay()
{	

	handleNavBar();
	
	var tablestr = `
		<table class="basic-table" width="60%">
		<tr>
		<th>ID</th>
		<th>Category</th>
		<th>ShortName</th>
		<th>Weekly Goal</th>
		<th>Active?</th>
		<th>---</th>
		</tr>		
	`

	
		
	var activelist = getItemList("exercise_plan");
	activelist.sort(proxySort(a => [a.getExType(), a.getId()]));

	activelist.forEach(function(activitem) {

		const actstr = activitem.getIsActive() == 1 ? "YES" : "NO";
		const studylink = "StudyExerciseItem.jsp?item_id=" + activitem.getId();
		const rowstr = `
			<tr>
			<td width="5%">${activitem.getId()}</td>
			<td>${activitem.getExType()}</td>
			<td>${activitem.getShortCode()}</td>
			<td>${activitem.getWeeklyGoal() + "  " + activitem.getUnitCode()}</td>
			<td>${actstr}</td>
			<td>


			<a href="${studylink}">
			<img src="/u/shared/image/inspect.png" height="18"/></a>

			&nbsp;
			&nbsp;
			&nbsp;

			<a href="javascript:toggleItemActive(${activitem.getId()}">
			<img src="/u/shared/image/cycle.png" height="18"/></a>

			</td>
			</tr>
		`;

		tablestr += rowstr;

	});

	populateSpanData({"activetable" : tablestr});
}




</script>

</head>

<body onLoad="javascript:redisplay()">


<center>

<div class="topnav"></div>

<br/>
<br/>

<div id="activetable"></div>

<br/><br/>


<a class="css3button" onclick="javascript:createNew()">new</a>

</form>


</body>
</html>
