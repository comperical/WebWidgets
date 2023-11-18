
<html>
<head>
<title>Day Planner</title>

<wisp view_prefixes="recent"/>

<script>

PLAN_DAY_CODE = getTodayCode();

function getHourTimeMap()
{
	const hourmap = {
		30 : "30 min",
		60 : "60 min",
		90 : "90 min"
	}

	for(var exhour = 2; exhour < 10; exhour++) {

		[true, false].forEach(function(ishalf) {

			const halfstr = ishalf ? ".5" : "";
			const label = `${exhour}${halfstr} hr`;
			const mincount = exhour * 60 + (ishalf ? 30 : 0);
			hourmap[mincount] = label;
		});
	}

	return hourmap;
}

function doTemplateImport()
{
	const temp_id = getDocFormValue("temp_id");

	// Look these up before creating the new ones, then delete them after.
	const deletes = getPlanDayItemList();	
	
	// remember: create new first to assign IDs, then delete old.
	W.getItemList("template_sub").forEach(function(tmpitem) {
		
		if(tmpitem.getTempId() != temp_id)
			{ return; }
		
		// console.log(tmpitem);
		
		const record = {
			"day_code" : PLAN_DAY_CODE.getDateString(),
			"end_hour" : tmpitem.getEndHour(),
			"half_hour" : tmpitem.getHalfHour(),
			"short_desc" : tmpitem.getShortDesc()
		};
		
		const newitem = W.buildItem("day_plan_main", record);
		newitem.syncItem();		
	});
	
	deletes.forEach(function(olditem) { olditem.deleteItem(); });
	
	redisplay();
}

function newByHourSpent()
{
	var itemlist = getPlanDayItemList();
	
	if(itemlist.length == 0)
	{
		alert("You must create at least one record first");
		return;
	}
	
	const plusmin = getDocFormValue("time_spent_min");
	
	const previtem = itemlist.slice(-1)[0];	
	
	const totalmin = previtem.getEndHour() * 60 + previtem.getHalfHour() * 30 + plusmin*1;
	
	const newhour = Math.floor(totalmin/60);	
	
	const newhalf = (totalmin - newhour*60) > 15;
	
	const itemname = prompt("Item Desc: ");
	
	if(itemname)
	{	
		createNewSub(
			newhour,
			newhalf,
			itemname
		);
	}
}


function createWakeUpItem()
{
	createNewSub(
		8, // Hard-coded wake up time
		false,
		"Jump out of bed!!"
	);	
}

function createNewSub(endhour, ishalf, itemname)
{
	const record = {
		"day_code" : PLAN_DAY_CODE.getDateString(),
		"end_hour" : endhour,
		"half_hour" : ishalf ? 1 : 0,
		"short_desc" : itemname
	};
	
	const newitem = W.buildItem("day_plan_main", record);
	newitem.syncItem();
	redisplay();
}

function addTime2Item(itemid)
{
	var planitem = W.lookupItem("day_plan_main", itemid);
	
	if(planitem.getHalfHour() == 0)
	{
		planitem.setHalfHour(1);
	} else {
		planitem.setEndHour(planitem.getEndHour()+1);
		planitem.setHalfHour(0);
	}
	
	planitem.syncItem();
	redisplay();	
}

function editItemDesc(itemid)
{
	const planitem = W.lookupItem("day_plan_main", itemid);
	const newdesc = prompt("Edit new description for item: ", planitem.getShortDesc());
	
	if(newdesc)
	{
		planitem.setShortDesc(newdesc);
		planitem.syncItem();
		redisplay();			
	}
}


function removeTimeFromItem(itemid)
{
	var planitem = W.lookupItem("day_plan_main", itemid);
	
	if(planitem.getHalfHour() == 1)
	{
		planitem.setHalfHour(0);
	} else {
		planitem.setEndHour(planitem.getEndHour()-1);
		planitem.setHalfHour(1);
	}
	
	planitem.syncItem();
	redisplay();	
}

function deleteItem(killid)
{
	genericDeleteItem("day_plan_main", killid);

	redisplay();
}

function updatePlanDay()
{
	PLAN_DAY_CODE = lookupDayCode(getDocFormValue("plan_day_sel"));
	redisplay();
}

function getPlanDayItemList()
{
	const itemlist = W.getItemList("day_plan_main").filter(dp => dp.getDayCode() == PLAN_DAY_CODE.getDateString());
	itemlist.sort(proxySort(dp => [dp.getEndHour()]));
	return itemlist;
}

function getTemplateIdMap()
{
	return buildGenericDict(W.getItemList("day_template").filter(item => item.getIsActive() == 1), 
		item => item.getId(), item => item.getShortName());

}


// This is a copy of a function in my personal shared JS code
function getDateDisplayMap()
{

	var dayptr = getTodayCode().dayAfter().dayAfter();
    const displaymap = {};

	for(var idx = 0; idx < 14; idx++)
	{
		displaymap[dayptr.getDateString()] = dayptr.getNiceDisplay();
		dayptr = dayptr.dayBefore();
	}

    return displaymap;
}


function redisplay()
{
	var activelist = getPlanDayItemList();
					
	var tablestr = `
		<table class="basic-table"  width="750px">
		<tr>
		<th>Desc</th>
		<th>..</th>
		<th>EndTime</th>
		<th>TimeSpent</th>
		<th>---</th>
		</tr>
	`;

	// hour:minute now
	const hourminnow = exactMomentNow().asIsoLongBasic(MY_TIME_ZONE).substring(11, 16);

	// true if previous row was past now	
	var prevpastnow = false;

	for(var ai in activelist)
	{
		const item = activelist[ai];	
				
		const endhourstr = item.getEndHour();	
		const halfstr = item.getHalfHour() == 1 ? ":30" : ":00";
				
		var timespent = "---";
		if(ai > 0)
		{
			const previtem = activelist[ai-1];
			var totalmin = item.getEndHour()*60 - previtem.getEndHour()*60;			
			totalmin += (item.getHalfHour()*30) - (previtem.getHalfHour()*30);
			const totalhour = totalmin/60;
			timespent = totalhour.toFixed(1) + " hr";
		}
		
		const hourminstr = `${endhourstr}${halfstr}`;
		// To compare correctly, must transform "8:00" -> "08:00"
		const cmphourmin = hourminstr.length == 4 ? "0" + hourminstr : hourminstr;
		const currentpastnow = cmphourmin > hourminnow;

		// highlight the NOW row
		var colorstr = "";
		if(currentpastnow && !prevpastnow)
			{ colorstr = `style="background-color: lightgreen;"`}

		prevpastnow = currentpastnow;

		var rowstr = `
			<tr ${colorstr}>
			<td>${item.getShortDesc()}</td>
			<td>
			
			<a href="javascript:editItemDesc(${item.getId()})">
			<img src="/u/shared/image/edit.png" height="18" /></a>
			
			</td>
			<td>${hourminstr}</td>
			<td width="15%">${timespent}</td>
			<td>
			<a href="javascript:addTime2Item(${item.getId()})">
			<img src="/u/shared/image/upicon.png" height="18" /></a>

			&nbsp;
			&nbsp;
			
			<a href="javascript:removeTimeFromItem(${item.getId()})">
			<img src="/u/shared/image/downicon.png" height="18" /></a>

			&nbsp;
			&nbsp;
			
			<a href="javascript:deleteItem(${item.getId()})">
			<img src="/u/shared/image/remove.png" height="18" /></a>

			</td>
			</tr>
		`;	
		

		tablestr += rowstr;
	}
	
	tablestr += `
		</table>
	`;

	const timeminsel = buildOptSelector()
							.setFromMap(getHourTimeMap())
							.setElementName("time_spent_min")
							.getSelectString()
	
	const tempsel = buildOptSelector()
						.setFromMap(getTemplateIdMap())
						.sortByDisplay()
						.insertStartingPair(-1, "---")
						.setElementName("temp_id")
						.setOnChange("javascript:doTemplateImport()")
						.setSelectedKey(-1)


	const displaymap = getDateDisplayMap();

	const datesel = buildOptSelector()
					.setFromMap(displaymap)
					.setSelectedKey(PLAN_DAY_CODE.getDateString())
					.setOnChange("javascript:updatePlanDay()")
					.setElementName("plan_day_sel")
					.getSelectString();


	populateSpanData({
		"dayplantable" : tablestr,
		"template_sel_span" : tempsel.getSelectString(),
		"plan_day_name" : PLAN_DAY_CODE.getDayOfWeek(),
		"time_spent_min_span" : timeminsel,
		"plan_day_code" : PLAN_DAY_CODE.getDateString().substring(5),
		"plan_day_sel_span" : datesel
	});


}


</script>

</head>

<body onLoad="javascript:redisplay()">


<center>

<br/>

<h3>Day Plan for <span id="plan_day_name"></span>, <span id="plan_day_code"></span></h3>

<form>
Go To: <span id="plan_day_sel_span"></span>
</form>

<div id="dayplantable"></div>

<br/><br/>

Hour Spent: <span id="time_spent_min_span"></span>

<a href="javascript:newByHourSpent()">
<img src="/u/shared/image/add.png" width="18"/></a>


<br/><br/>

wakeup
<a href="javascript:createWakeUpItem()">
<img src="/u/shared/image/add.png" width="18"/></a> 

<br/><br/>
Import Template: 
<span id="template_sel_span">
</span>

</body>
</html>
