
<%@ page import="lifedesign.basic.LifeUtil" %>

<%@include file="../../admin/AuthInclude.jsp_inc" %>

<html>
<head>
<title>Junk Food Log</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

<script>

// The date when I started using the consumption target formula.
SYSTEM_START_DATE = lookupDayCode("2021-07-01");

// Target number of items per year
YEARLY_CONSUMPTION_TARGET = 200;

function addNew()
{	
	const junkfact = getDocFormValue("junk_factor_sel");
	const thenotes = getDocFormValue("notes");
	addNewSub(junkfact, thenotes);
}

function addClean()
{
	addNewSub(0, "Clean");
}

function addNewSub(junkfact, thenotes)
{
	const daycode = getDocFormValue("day_code_sel");
	
	const newrec = {
		"junkfactor" : parseInt(junkfact),
		"day_code" : daycode,
		"notes": thenotes
	};		
	
	document.forms.mainform.notes.value = "";
	document.forms.mainform.junk_factor_sel.value = "1";
	
	const newitem = buildItem("junk_food_log", newrec);
	newitem.syncItem();
	redisplay();	
}



function deleteItem(killid)
{
	if(confirm("Are you sure you want to remove this record?"))
	{
		lookupItem("junk_food_log", killid).deleteItem();
		redisplay();
	}
}

function redisplay()
{
	redispControls();

	redispFullTable();
	
	redispSummTable();

	redispStatTable();
}

function junkWeightSince(daycode) 
{
	var jktotal = 0;
	var itemlist = getItemList("junk_food_log");
	itemlist.sort(proxySort(a => [a.getDayCode()])).reverse();
	
	for(var ii in itemlist) {
	
		const item = itemlist[ii];
		
		if(item.getDayCode() < daycode.getDateString())
			{ break; }
		
		jktotal += item.getJunkfactor();
	}	
	
	return jktotal;
}

function redispControls()
{
	const junksel = buildOptSelector()
						.setKeyList([... Array(10).keys()])
						.setSelectedKey(1)
						.setSelectOpener(`<select name="junk_factor_sel">`)
						.getSelectString();


	const displaymap = getNiceDateDisplayMap(14);

	const datesel = buildOptSelector()
					.setFromMap(displaymap)
					.setSelectedKey(getTodayCode().dayBefore().getDateString())
					.setSelectOpener(`<select name="day_code_sel">`)
					.getSelectString();

	populateSpanData({
		"day_code_sel_span" : datesel,
		"junk_factor_sel_span" : junksel
	})
}


function redispSummTable() 
{
	var itemlist = getItemList("junk_food_log");
	itemlist.sort(proxySort(a => [a.getDayCode()])).reverse();
	
	var tablestr = `
		<table class="basic-table"  width="40%">
		<tr>
		<th>NDays</th>
		<th>Since</th>
		<th>Total</th>
		<th>JunkWeight/Day</th>
		</tr>		
	
	`;
	
	const daysago = [7, 14, 21, 28];
	
	daysago.forEach(function(days) {
		
							
		const dayprobe = getTodayCode().nDaysBefore(days);
		const jktotal = junkWeightSince(dayprobe);
		const jkperday = jktotal / days;
		
		var rowstr = `
			<tr>
			<td>${days}</td>
			<td>${dayprobe.getDateString()}</td>
			<td>${jktotal}</td>
			<td>${jkperday.toFixed(3)}</td>
			</tr>
		`;
		
		tablestr += rowstr;
	});
	
	tablestr += `
		</table>
	`;
	
	document.getElementById('summtable').innerHTML = tablestr;
}

// This is the consumption target, which is the number of days
// since the epoch times a weight factor.
function getConsumptionTarget()
{
	const daysince = SYSTEM_START_DATE.daysUntil(getTodayCode()) + 1;

	const consperday = YEARLY_CONSUMPTION_TARGET / 365;
	return Math.floor(consperday * daysince);
}


// Display the status table - number of JF items since "epoch",  July 1, 2021
// Show a warning of depending on how far above the target number I am.
function redispStatTable()
{
	const junksince = junkWeightSince(SYSTEM_START_DATE);
	const constarget = getConsumptionTarget();

	const excess = junksince - constarget;

	const colorstr = 
		excess < 5 
			? (excess <= 0  ? "lightgreen" : "yellow") 
			: (excess < 10 ? "red" : "red");

	const tablestr = `
		<table class="basic-table" width="40%">
		<tr>
		<th>Total</th>
		<th>Target</th>
		<th>Excess</th>
		<th>Status</th>
		</tr>
		<tr>
		<td>${junksince}</td>
		<td>${constarget}</td>
		<td>${excess}</td>
		<td style="background-color: ${colorstr};"></td>
		</tr>
		</table>
	`;


	populateSpanData({"status_table" : tablestr});
}

function redispFullTable()
{
	var itemlist = getItemList("junk_food_log");
	itemlist.sort(proxySort(a => [a.getDayCode()])).reverse();
		
	const cutoff = getTodayCode().nDaysBefore(90);
			
	var tablestr = `
		<table class="basic-table"  width="40%">
		<tr>
		<th>Day</th>
		<th>Date</th>
		<th>Junk F</th>
		<th>Notes</th>
		<th>...</th>
		</tr>
	`;
	
	itemlist.forEach(function(jkitem) {
			
		const daycode = lookupDayCode(jkitem.getDayCode());
						
		if(jkitem.getDayCode() < cutoff.getDateString())
			{ return; }			
			
		var rowstr = `
			<tr>
			<td>${daycode.getShortDayOfWeek()}</td>
			<td>${jkitem.getDayCode().substring(5)}</td>
			<td>${jkitem.getJunkfactor()}</td>
			<td>${jkitem.getNotes()}</td>
			<td>
			<a href="javascript:deleteItem(${jkitem.getId()})">
			<img src="/life/image/remove.png" height="18"/>
			</a>
			</td>
			</tr>
		`;
		
		tablestr += rowstr;
	});	
	
	tablestr += `
		</table>
	`;
	
	
	document.getElementById('fulltable').innerHTML = tablestr;

}


</script>

</head>

<body onLoad="javascript:redisplay()">


<center>

<h4>Junk Food Log</h4>

<center>


<form name="mainform">
Junk Weight:
<span id="junk_factor_sel_span"></span>

Date:
<span id="day_code_sel_span"></span>

Notes:
<input type="text" name="notes"/>
</form>


<a href="javascript:addNew()"><button>add</button></a>

&nbsp;
&nbsp;
&nbsp;
&nbsp;

<a href="javascript:addClean()"><button>clean</button></a>

<br/>

<h4>Summary</h4>

<div id="summtable"></div>

<h4>Control Info</h4>

<div id="status_table"></div>



<h4>Full Log</h4>

<div id="fulltable"></div>


</center>
</body>
</html>
