
<html>
<head>
<title>Exercise Template</title>

<wisp/>

<script>

var EDIT_STUDY_ITEM = 1;

function createNew()
{	
	const shortcode = prompt("ShortCode for item: ");
	
	if(shortcode)
	{					
		// created_on, active_on, completed_on, dead_line
		const comrecord = {
			"ex_type" : "body",
			"unit_code" : "hours",
			"weekly_goal" : 2,
			"short_code" : shortcode,
			"full_desc": "...",
			"usual_distance" : 2,
			"is_active" : 1
		};
		
		const newitem = W.buildItem("exercise_plan", comrecord);
		newitem.syncItem();
		redisplay();
	}
}

function editStudyItem(itemid)
{
	EDIT_STUDY_ITEM = itemid;
	redisplay();
}

function back2Main()
{
	EDIT_STUDY_ITEM = -1;
	redisplay();
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

function editUnitCode()
{
	genericEditTextField("exercise_plan", "unit_code", EDIT_STUDY_ITEM);
}

function redisplay()
{
	handleNavBar();

	const pageinfo = EDIT_STUDY_ITEM == -1 ? getMainPageInfo() : getEditPageInfo();
	populateSpanData({
		"pageinfo" : pageinfo
	});
}

function getEditPageInfo()
{

	const studyitem = W.lookupItem("exercise_plan", EDIT_STUDY_ITEM);

	var pageinfo = `

		<table class="basic-table" width="40%">
		<tr>
		<td>Back</td>
		<td></td>
		<td><a href="javascript:back2Main()"><img src="/u/shared/image/leftarrow.png" height="18"/></td>
		</tr>

		<tr>
		<td>Short Code</td>
		<td>${studyitem.getShortCode()}</td>
		<td></td>
		</tr>


		<tr>
		<td>Units</td>
		<td>${studyitem.getUnitCode()}</td>
		<td><a href="javascript:editUnitCode()"><img src="/u/shared/image/edit.png" height=18/></a></td>
		</tr>


		</table>
	`;

	return pageinfo;

}

function getMainPageInfo()
{	

	
	var tablestr = `
		<table class="basic-table" width="60%">
		<tr>
		<th>Category</th>
		<th>ShortName</th>
		<th>Unit</th>
		<th>---</th>
		</tr>		
	`

	
		
	var activelist = W.getItemList("exercise_plan");
	activelist.sort(proxySort(a => [a.getExType(), a.getId()]));

	activelist.forEach(function(activitem) {

		const studylink = "StudyExerciseItem.jsp?item_id=" + activitem.getId();
		const rowstr = `
			<tr>
			<td>${activitem.getExType()}</td>
			<td>${activitem.getShortCode()}</td>
			<td>${activitem.getUnitCode()}</td>
			<td>


			<a href="javascript:editStudyItem(${activitem.getId()})">
			<img src="/u/shared/image/inspect.png" height="18"/></a>

			</td>
			</tr>
		`;

		tablestr += rowstr;

	});

	return tablestr;
}




</script>

</head>

<body onLoad="javascript:redisplay()">


<center>

<div class="topnav"></div>

<br/>
<br/>

<div id="pageinfo"></div>


</body>
</html>
