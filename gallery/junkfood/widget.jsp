
<%@ page import="java.util.*" %>

<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.DbUtil.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@ page import="lifedesign.basic.*" %>
<%@ page import="lifedesign.classic.*" %>

<%@include file="../../life/AuthInclude.jsp_inc" %>

<%
	ArgMap argMap = HtmlUtil.getArgMap(request);	
	
	DayCode jvTodayCode = LifeUtil.getTodayTzAware();	
	
	OptSelector dayCodeSel = LifeUtil.standardDateSelector(14);
	
	OptSelector intSelector = new OptSelector(Util.range(0, 20)); // hope I don't need more than 20
	
%>

<html>
<head>
<title>Junk Food Log</title>


<%@include file="../../life/AssetInclude.jsp_inc" %>



<%= DataServer.basicInclude(request) %>

<script>

function addNew()
{	
	const junkfact = getDocFormValue("junkfactor");
	const thenotes = getDocFormValue("notes");
	addNewSub(junkfact, thenotes);
}



function addClean()
{
	addNewSub(0, "Clean");
}

function addNewSub(junkfact, thenotes)
{
	const newid = newBasicId("junk_food_log");
	const daycode = getDocFormValue("day_code");
	
	const newrec = {
		"id" : newid,
		"junkfactor" : parseInt(junkfact),
		"day_code" : daycode,
		"notes": thenotes
	};		
	
	document.forms.mainform.notes.value = "";
	document.forms.mainform.junkfactor.value = "1";
	
	const newitem = buildJunkFoodLogItem(newrec);
	newitem.registerNSync();
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
	redispFullTable();
	
	redispSummTable();
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

function redispSummTable() 
{
	var itemlist = getItemList("junk_food_log");
	itemlist.sort(proxySort(a => [a.getDayCode()])).reverse();
	
	var tablestr = `
		<table id="dcb-basic" class="dcb-basic" width="40%">
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


function redispFullTable()
{
	var itemlist = getItemList("junk_food_log");
	itemlist.sort(proxySort(a => [a.getDayCode()])).reverse();
		
	const cutoff = getTodayCode().nDaysBefore(90);
			
	var tablestr = `
		<table id="dcb-basic" class="dcb-basic" width="40%">
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
<input type="hidden" name="opcode" value="addnew"/>
Junk Weight:
<select name="junkfactor">
<%= intSelector.getSelectStr(1) %>
</select>
Date:
<select name="day_code">
<%= dayCodeSel.getSelectStr(jvTodayCode.dayBefore()) %>
</select>
Notes:
<input type="text" name="notes"/>
</form>
<a href="javascript:addNew()">Add New</a>

---

<a href="javascript:addClean()">Clean</a>


<br/>

<h4>Summary</h4>

<div id="summtable"></div>



<h4>Full Log</h4>

<div id="fulltable"></div>


</center>
</body>
</html>
