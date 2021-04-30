
<%@ page import="java.util.*" %>

<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@ page import="lifedesign.basic.*" %>
<%@ page import="lifedesign.classic.*" %>

<%@include file="../../admin/AuthInclude.jsp_inc" %>

<%
	ArgMap argMap = HtmlUtil.getArgMap(request);
	
	DayCode jvTodayCode = LifeUtil.getTodayTzAware();
	
	OptSelector ratingSel = new OptSelector(Util.range(1, 10));
	
	DayCode todayCode = DayCode.getToday();
		
	OptSelector endHourSel = new OptSelector(Util.range(1, 24));
	
	OptSelector timeSpentSel = new OptSelector(LifeUtil.getHourTimeMap());
	
	OptSelector dayCodeSel = new OptSelector(DayCode.getDayRange(DayCode.getToday().nDaysBefore(10), DayCode.getToday().nDaysAfter(2)));
	
	String longPlanDow = TimeUtil.getLongDayOfWeek(jvTodayCode);		
%>

<html>
<head>
<title>Day Planner</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

<script>


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
			"day_code" : getStudyDayCode().getDateString(),
			"end_hour" : tmpitem.getEndHour(),
			"half_hour" : tmpitem.getHalfHour(),
			"short_desc" : tmpitem.getShortDesc()
		};
		
		const newitem = buildItem("day_plan_main", record);
		newitem.registerNSync();		
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

function createNewFromEndHour()
{
	const itemname = prompt("Item Desc: ");
	
	if(itemname)
	{	
		createNewSub(
			getDocFormValue("end_hour"),
			false,
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
		"day_code" : getStudyDayCode().getDateString(),
		"end_hour" : endhour,
		"half_hour" : ishalf ? 1 : 0,
		"short_desc" : itemname
	};
	
	const newitem = buildItem("day_plan_main", record);
	newitem.registerNSync();
	redisplay();
}

function getStudyDayCode()
{
	const pdstr = getDocFormValue("planday");
	return lookupDayCode(pdstr);
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

function getPlanDayItemList()
{
	const studyday = getStudyDayCode();	
	var itemlist = getItemList("day_plan_main").filter(dp => dp.getDayCode() == studyday.getDateString());
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
		<table id="dcb-basic" class="dcb-basic" width="50%">
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
	
	const tempsel = buildOptSelector()
						.setFromMap(getTemplateIdMap())
						.setSelectOpener(`<select name="temp_id" onChange="javascript:doTemplateImport()">`)
						.setSelectedKey(-1)

	populateSpanData({
		"dayplantable" : tablestr,
		"template_sel_span" : tempsel.getSelectString(),
		"plan_day_name" : getStudyDayCode().getDayOfWeek(),
		"plan_day_code" : getStudyDayCode().getDateString().substring(5)
	});


}


</script>

</head>

<body onLoad="javascript:redisplay()">


<center>

<br/>

<h3>Day Plan for <span id="plan_day_name"></span>, <span id="plan_day_code"></span></h3>

<form>
Go To: <select name="planday" onChange="javascript:redisplay()">
<%= dayCodeSel.getSelectStr(jvTodayCode) %>
</select>
</form>

<div id="dayplantable"></div>

<br/><br/>

End Time: <select name="end_hour">
<%= endHourSel.getSelectStr("16") %>
</select>

<a href="javascript:createNewFromEndHour()">
<img src="/life/image/add.png" width="18"/></a>

<br/><br/>

Hour Spent: <select name="time_spent_min">
<%= timeSpentSel.getSelectStr("90") %>
</select>

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
