
<html>
<head>
<title>Study Ex. Item</title>

<%= DataServer.basicInclude(request) %>


<script>

STUDY_ITEM_ID = parseInt(getUrlParamHash()["item_id"]);

function flipActive()
{
	var showItem = getItem2Show();

	var curActive = showItem.getIsActive();
	
	showItem.setIsActive(curActive == 1 ? 0 : 1);
	showItem.syncItem();
	redisplay();
}

function saveNewDesc()
{
	var showItem = getItem2Show();

	var newDesc = getDocFormValue("fullitemdesc");
	
	showItem.setFullDesc(newDesc);
	showItem.syncItem();
	redisplay();
}

function updateExType()
{
	const showitem = getItem2Show();
	const newtype = getDocFormValue("sel_ex_type");
	
	showitem.setExType(newtype);
	showitem.syncItem();
	redisplay();
}

function updateGoal()
{
	const showitem = getItem2Show();
	const newgoal = getDocFormValue("weekly_goal_sel");
	
	showitem.setWeeklyGoal(newgoal);
	showitem.syncItem();
	redisplay();
}

function updateDistance()
{
	const showitem = getItem2Show();
	const newdist = getDocFormValue("usual_distance_sel");
	
	showitem.setUsualDistance(newdist);
	showitem.syncItem();
	redisplay();
}

function editShortCode()
{
	var showitem = getItem2Show()
	var shortcode = prompt("Enter a new workout code: ", showitem.getShortCode());
	
	if(shortcode)
	{		
		showitem.setShortCode(shortcode);
		showitem.syncItem();
		redisplay();		
	}
}



function editUnitCode()
{
	var showitem = getItem2Show()
	var unitcode = prompt("Enter a new unit code: ", showitem.getUnitCode());
	
	if(unitcode)
	{		
		showitem.setUnitCode(unitcode);
		showitem.syncItem();
		redisplay();		
	}
}

function getItem2Show()
{
	return W.lookupItem("exercise_plan", STUDY_ITEM_ID);
}

function redisplay()
{

	const showItem = getItem2Show();
	const activestr = showItem.getIsActive() == 1 ? "YES" : "NO";

	const curItemDesc = showItem.getFullDesc();
	const desclinelist = curItemDesc.replace(/\n/g, "<br/>");


	populateSpanData({
		"short_code" : showItem.getShortCode(),
		"unit_code" : showItem.getUnitCode(),
		"ex_type" : showItem.getExType(),
		"usual_distance" : showItem.getUsualDistance(),
		"weekly_goal" : showItem.getWeeklyGoal(),
		"isactive" : activestr,
		"itemdescline" : desclinelist
	})
	
	buildOptSelector()
		.setKeyList(["body", "brain"])
		.setElementName("sel_ex_type")
		.setOnChange("javascript:updateExType()")
		.setSelectedKey(showItem.getExType())
		.autoPopulate();

	const goalrange = [...Array(20).keys()];
	buildOptSelector()
		.setKeyList(goalrange)
		.setSelectedKey(showItem.getWeeklyGoal())
		.setElementName("weekly_goal_sel")
		.setOnChange("javascript:updateGoal()")
		.autoPopulate()

	const usuallist = [... Array(10).keys()];
	buildOptSelector()
		.setKeyList(usuallist)
		.setSelectedKey(showItem.getUsualDistance())
		.setElementName("usual_distance_sel")
		.setOnChange("javascript:updateDistance()")
		.autoPopulate()

}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<br/><br/>

<h3>Study Exercise Item</h3>

<br/><br/>

<table width="30%" class="basic-table">
<tr>
<td>Back</td>
<td></td>
<td><a href="ExerciseTemplate.jsp"><img src="/u/shared/image/leftarrow.png" height="18"/></a></td>
</tr>

<tr>
<td width="50%">ShortCode</td>
<td><div id="short_code"></div></td>
<td><a href="javascript:editShortCode()"><img src="/u/shared/image/edit.png" height=18/></a></td>
</tr>
<tr>
<td width="50%">Type</td>
<td><div id="ex_type"></div></td>
<td>
<span id="sel_ex_type_span"></span>
</td>
</tr>



<tr>
<td width="50%">Goal</td>
<td><div id="weekly_goal"></div></td>
<td>
<span id="weekly_goal_sel_span"></span>
</td>
</tr>

<tr>
<td width="50%">Usual Distance</td>
<td><div id="usual_distance"></div></td>
<td>
<span id="usual_distance_sel_span"></span>
</td>
</tr>


<tr>
<td width="50%">Units</td>
<td><div id="unit_code"></div></td>
<td><a href="javascript:editUnitCode()"><img src="/u/shared/image/edit.png" height=18/></a></td>
</tr>




<tr>
<td width="50%">Active?</td>
<td><span id="isactive"></span>

</td>
<td><a href="javascript:flipActive()"><img src="/u/shared/image/cycle.png" height=18/></a></td>
</tr>
</table>

<br/>
<br/>

<table class="basic-table" width="30%">
<tr>
<td>
<span id="itemdescline">xxx<br/>yyy</span>
</td>
</tr>
</table>

<br/>
<br/>

<form>
<textarea id="fullitemdesc" name="fullitemdesc" rows="10" cols="50"></textarea>
</form>

<a href="javascript:saveNewDesc()">save desc</a>

</body>
</html>
