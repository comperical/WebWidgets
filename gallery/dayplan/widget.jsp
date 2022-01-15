
<%@include file="../../admin/AuthInclude.jsp_inc" %>

<html>
<head>
<title>Day Planner</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

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
	getItemList("template_sub").forEach(function(tmpitem) {
		
		if(tmpitem.getTempId() != temp_id)
			{ return; }
		
		// console.log(tmpitem);
		
		const record = {
			"id" : newBasicId("day_plan_main"),
			"day_code" : PLAN_DAY_CODE.getDateString(),
			"end_hour" : tmpitem.getEndHour(),
			"half_hour" : tmpitem.getHalfHour(),
			"short_desc" : tmpitem.getShortDesc()
		};
		
		const newitem = buildItem("day_plan_main", record);
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
		"id" : newBasicId("day_plan_main"),
		"day_code" : PLAN_DAY_CODE.getDateString(),
		"end_hour" : endhour,
		"half_hour" : ishalf ? 1 : 0,
		"short_desc" : itemname
	};
	
	const newitem = buildItem("day_plan_main", record);
	newitem.syncItem();
	redisplay();
}

function addTime2Item(itemid)
{
	var planitem = lookupItem("day_plan_main", itemid);
	
	if(planitem.getHalfHour() == 0)
	{
		planitem.setHalfHour(1);
	} else {
		planitem.setEndHour(planitem.getEndHour()+1);
		planitem.setHalfHour(0);
	}
	
	syncSingleItem(planitem);			
	redisplay();	
}

function editItemDesc(itemid)
{
	var planitem = lookupItem("day_plan_main", itemid);
	
	var newdesc = prompt("Edit new description for item: ", planitem.getShortDesc());
	
	if(newdesc)
	{
		planitem.setShortDesc(newdesc);
		syncSingleItem(planitem);			
		redisplay();			
	}
}


function removeTimeFromItem(itemid)
{
	var planitem = lookupItem("day_plan_main", itemid);
	
	if(planitem.getHalfHour() == 1)
	{
		planitem.setHalfHour(0);
	} else {
		planitem.setEndHour(planitem.getEndHour()-1);
		planitem.setHalfHour(1);
	}
	
	syncSingleItem(planitem);			
	redisplay();	
}

function deleteItem(killid)
{
	lookupItem("day_plan_main", killid).deleteItem();
	
	redisplay();
}

function updatePlanDay()
{
	PLAN_DAY_CODE = lookupDayCode(getDocFormValue("plan_day_sel"));
	redisplay();
}

function getPlanDayItemList()
{
	var itemlist = getItemList("day_plan_main").filter(dp => dp.getDayCode() == PLAN_DAY_CODE.getDateString());
	itemlist.sort(proxySort(dp => [dp.getEndHour()]));
	return itemlist;
}

function getTemplateIdMap()
{
	var idmap = {};
	idmap[-1] = "----";

	getItemList("day_template").forEach(function(item) {

		if(item.getIsActive() == 0)
			{ return; }

		idmap[item.getId()] = item.getShortName();
	});

	return idmap;
}

function redisplay()
{
	var activelist = getPlanDayItemList();
					
	var tablestr = `
		<table class="basic-table"  width="50%">
		<tr>
		<th>Desc</th>
		<th>..</th>
		<th>EndTime</th>
		<th>TimeSpent</th>
		<th>---</th>
		</tr>
	`;

	// hour:minute now
	const hourminnow = calcTimeHourStr(new Date()).substring(0, 5);

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
			<img src="/life/image/edit.png" height="18" /></a>
			
			</td>
			<td>${hourminstr}</td>
			<td width="15%">${timespent}</td>
			<td>
			<a href="javascript:addTime2Item(${item.getId()})">
			<img src="/life/image/upicon.png" height="18" /></a>

			&nbsp;
			&nbsp;
			
			<a href="javascript:removeTimeFromItem(${item.getId()})">
			<img src="/life/image/downicon.png" height="18" /></a>

			&nbsp;
			&nbsp;
			
			<a href="javascript:deleteItem(${item.getId()})">
			<img src="/life/image/remove.png" height="18" /></a>

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
							.setSelectOpener(`<select name="time_spent_min">`)
							.getSelectString()
	
	const tempsel = buildOptSelector()
						.setFromMap(getTemplateIdMap())
						.setSelectOpener(`<select name="temp_id" onChange="javascript:doTemplateImport()">`)
						.setSelectedKey(-1)


	// TODO: this should give a day ahead, the whole point of the day plan is to do it the day before
	const displaymap = getNiceDateDisplayMap(14);

	const datesel = buildOptSelector()
					.setFromMap(displaymap)
					.setSelectedKey(PLAN_DAY_CODE.getDateString())
					.setSelectOpener(`<select name="plan_day_sel" onChange="javascript:updatePlanDay()">`)
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
<img src="/life/image/add.png" width="18"/></a>


<br/><br/>

wakeup
<a href="javascript:createWakeUpItem()">
<img src="/life/image/add.png" width="18"/></a> 

<br/><br/>
Import Template: 
<span id="template_sel_span">
</span>

</body>
</html>
