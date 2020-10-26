
<%@ page import="java.util.*" %>

<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@ page import="lifedesign.basic.*" %>
<%@ page import="lifedesign.classic.*" %>
<%@ page import="lifedesign.basic.LifeUtil.*" %>
<%@ page import="lifedesign.classic.FinanceSystem.*" %>

<%@include file="../../life/AuthInclude.jsp_inc" %>

<%
	ArgMap argMap = HtmlUtil.getArgMap(request);
	
	int dayTotal = argMap.getInt("daytotal", 60);

	OptSelector dayTotalSel = new OptSelector(Util.listify(30, 60, 90, 120, 150, 180, 270, 360));
	
	DayCode endDate = FinanceSystem.getLastMonthDay();
	DayCode startDate = endDate.nDaysBefore(dayTotal);
	
	Set<String> financeNeed = FinanceSystem.getNeedUploadMonthSet();

%>

<html>
<head>
<title>Finance Agg</title>

<%@include file="../../life/AssetInclude.jsp_inc" %>

<script src="FinanceTech.js"/></script>

<%= DataServer.basicInclude(request) %>

<script>

function changeDayTotal()
{
	const daytotal = getDocFormValue("daytotal");
	submit2Base({"daytotal" : daytotal });
}

function getCat2ReccMap(notemap)
{
	var reccmap = {};
	
	for(var cat in notemap)
	{
		reccmap[cat] = [];
		
		var notelist = notemap[cat];
	
		for(var ni in notelist)
		{
			var noteitem = notelist[ni];
		
			var recitem = lookupItem("finance_main", noteitem.getId());
			
			reccmap[cat].push(recitem);
		}
	}
	
	return reccmap;
}


function getCat2NoteMap(startday, endday)
{
	var catmap = {};
	
	var fnilist = getItemList("finance_note");
	
	for(var fni in fnilist)
	{
		var noteitem = fnilist[fni];
		var reccitem = lookupItem("finance_main", noteitem.getId());
	
		if(!(startday <= reccitem.getTransactDate() && reccitem.getTransactDate() <= endday))
			{ continue; }
		
		var expcat = noteitem.getExpenseCat();
		
		if(!catmap.hasOwnProperty(expcat))
		{
			catmap[expcat] = [];	
		}
		
		catmap[expcat].push(noteitem);
	}
	
	return catmap;
}

// TODO: copy of code in FinanceLog.jsp
function getDollarFormat(centamount)
{
	var dollamount = centamount/100;
	
	if(dollamount < 0)
	{
		return (-dollamount).toFixed(2);
	}
	
	return "+++" + dollamount.toFixed(2);
}

function getDataFrameList()
{
	var cat2NoteMap = getCat2NoteMap('<%= startDate %>', '<%= endDate %>');
	var cat2ReccMap = getCat2ReccMap(cat2NoteMap);

	var framelist = [];

	for(var expcat in cat2NoteMap)
	{
		var notelist = cat2NoteMap[expcat];
		var recclist = cat2ReccMap[expcat];
	
		// console.log(recclist[0]);
		
		var frameitem = {};
		
		var centsum = recclist
				.map(recc => recc.getCentAmount())
				.reduce((a, b) => a + b, 0);
				
		// var sum = [1, 2, 3].reduce((a, b) => a + b, 0);
		
		
		frameitem.expcat = expcat;
		frameitem.centsum = centsum;
		frameitem.numrec = notelist.length;
		frameitem.perday = (centsum / <%= dayTotal %>);
		frameitem.extrap2year = (frameitem.perday * 365);
		
		framelist.push(frameitem);
	}		
	
	return framelist;
}


function redisplay()
{
	var tablestr = `
		<table id="dcb-basic" class="dcb-basic" width="75%">
		<tr>
		<th>Category</th>
		<th>Total</th>
		<th>#Rec</th>
		<th>Per Day Avg</th>
		<th>Year Extrapolation</th>
		</tr>
	`;
	
	var framelist = getDataFrameList();
	
	framelist.sort((a, b) => a.centsum - b.centsum);
	
	var dailytotal = 0;
	var yearlytotal = 0;
	
	framelist.forEach(function(frameitem) {
			
		var expcat = frameitem.expcat;
		
		if(expcat == "ignore" || expcat == "uncategorized")
			{ return; }
		
		const dollarstr = getDollarFormat(frameitem.centsum);
		const perdaystr = getDollarFormat(frameitem.perday);
		const extrastr = getDollarFormat(frameitem.extrap2year);
		
		const rowstr = `
			<tr>
			<td>${expcat}</td>
			<td>${dollarstr}</td>
			<td>${frameitem.numrec}</td>
			<td>${perdaystr}</td>
			<td>${extrastr}</td>
			</tr>
		`;
				
		dailytotal += frameitem.perday;
		
		yearlytotal += frameitem.extrap2year;
		
		tablestr += rowstr;
		
	});
	
	tablestr += "</table>";
		
	populateSpanData({
		"aggtable" : tablestr,
		"dailytotal" : getDollarFormat(dailytotal),
		"yearlytotal" : getDollarFormat(yearlytotal)
	});
}


</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<a href="FinanceLog.jsp">Finance Log</a>




<h3>Finance Aggregation</h3>

<% 
	if(!financeNeed.isEmpty())
	{
%>
Should upload for month : <b><%= Util.join(financeNeed, " , ") %></b>
<% } %>

<br/>

<h4>Aggregation for Window: <%= startDate %> , <%= endDate %></h4>



<form>
Last #Day: <select name="daytotal" onChange="javascript:changeDayTotal()">
<%= dayTotalSel.getSelectStr(dayTotal) %>
</select>
</form>




<h4>
Total Daily : <span id="dailytotal"></span>
<br/>
Total Yearly : <span id="yearlytotal"></span>
</h4>

<div id="aggtable"></div>




<br/><br/><br/>

</center>
</body>
</html>
