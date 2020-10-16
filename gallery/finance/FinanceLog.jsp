
<%@ page import="java.util.*" %>

<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>
<%@ page import="net.danburfoot.shared.FiniteState.*" %>

<%@ page import="lifedesign.basic.*" %>
<%@ page import="lifedesign.classic.*" %>
<%@ page import="lifedesign.basic.LifeUtil.*" %>
<%@ page import="lifedesign.classic.FinanceSystem.*" %>

<%@include file="AuthInclude.jsp_inc" %>

<%
	ArgMap argMap = HtmlUtil.getArgMap(request);
	
	OptSelector catselect = new OptSelector(Util.listify(ExpenseType.values())).sortKeys().addKey("all");
	
	List<DayCode> cutofflist = Util.vector();
	
	for(int dayago : Util.listify(30, 45, 60, 90, 180, 360, 720))
	{
		cutofflist.add(DayCode.getToday().nDaysBefore(dayago));
	}
	
	OptSelector cutDaySelect = (new OptSelector(cutofflist)).addKey("---");
	
%>

<html>
<head>
<title>Finance Log</title>

<%@include file="AssetInclude.jsp_inc" %>

<%= JsCodeGenerator.getScriptInfo(request, "biz", Util.listify("finance_main", "finance_note")) %>


<script>

function getUncatRecList()
{
	return getItemList("finance_note")
			.filter(it => it.getExpenseCat() == "uncategorized");
}

function getHaveCatRecList()
{
	return getItemList("finance_note")
			.filter(it => it.getExpenseCat() != "uncategorized");

}


function getDollarFormat(centamount)
{
	var dollamount = centamount/100;
	
	if(dollamount < 0)
	{
		return (-dollamount).toFixed(2);
	}
	
	return "+++" + dollamount.toFixed(2);
}

function getOptionList()
{
	return ['<%= Util.join(Util.listify(ExpenseType.values()), "', '") %>'];
}

function doCat4Id(id)
{
	var noteitem = lookupItem("finance_note", id);
	
	var newvalue = document.getElementById("catselect" + id).value;
	
	noteitem.setExpenseCat(newvalue);

	syncSingleItem(noteitem);

	redisplay();	
}

function editUserNote(id)
{
	var noteitem = lookupItem("finance_note", id);
	var newnote = prompt("Enter a new note for this item: ", noteitem.getTheNote());
	
	if(newnote)
	{
		noteitem.setTheNote(newnote);
		syncSingleItem(noteitem);
		redisplay();		
	}
}

function composeCatOptionSelectStr(itemid)
{
	var s = `
		<select id="catselect${itemid}" onChange="javascript:doCat4Id(${itemid})">
	`;
	
	var optionlist = getOptionList().sort();
	
	for(var oi in optionlist)
	{
		const open = optionlist[oi] == "uncategorized" ? "<option selected>" : "<option>";
		
		s += open + optionlist[oi] + "</option>";
	}

	return s + "</select>";
}

function composeInspectRef(itemid)
{
	var s = "<a href=\"FinanceRecInspect.jsp?id={1}\">";

	s += "<img src=\"/life/image/inspect.png\" height=\"18\"/>";
	
	s += "</a>";
	
	return s;
}

function composeUserNoteEdit(itemid)
{
	var s = "<a href=\"javascript:editUserNote({1})\">";

	s += "<img src=\"/life/image/edit.png\" height=\"18\"/>";
	
	s += "</a>";
	
	return s;
}


function reDispCatOkTable()
{
	var tablestr = `
		<table id="dcb-basic" class="dcb-basic" width="90%">
		<tr>
		<th>DayCode</th>
		<th>ExpenseCat</th>
		<th>Amount</th>
		<th>CC Rec</th>
		<th>UserNote</th>
		<th>---</th>
		</tr>
	`;

	const targcat = getDocFormValue("catselect");
	const cutoffdate = getDocFormValue("cutoffdate");
	const catoklist = getHaveCatRecList();

	var catreclist = catoklist.map(nocat => lookupItem("finance_main", nocat.getId()));
		
	catreclist.sort(proxySort(item => item.getTransactDate())).reverse();
	
	
	catreclist.forEach(function(recitem) {
			
		const noteitem = lookupItem("finance_note", recitem.getId());
			
		if(targcat != "all" && noteitem.getExpenseCat() != targcat)
			{ return; }
			
		if(cutoffdate != "---" && recitem.getTransactDate().localeCompare(cutoffdate) < 0)
			{ return; }		
			
		const dollarstr = getDollarFormat(recitem.getCentAmount());		
		

		const rowstr = `
			<tr>
			<td>${recitem.getTransactDate().substring(5)}</td>
			<td>${noteitem.getExpenseCat()}</td>
			<td>${dollarstr}</td>
			<td>${recitem.getFullDesc()}</td>
			<td>${noteitem.getTheNote()}</td>
			<td width="7%">
			
			<a href="javascript:editUserNote(${noteitem.getId()})">
			<img src="/life/image/edit.png" height="18"/></a>

			&nbsp;
			&nbsp;
						
			<a href="FinanceRecInspect.jso?id=${noteitem.getId()})">
			<img src="/life/image/inspect.png" height="18"/></a>
			
			</td>
			</tr>
		`;
		
		tablestr += rowstr;
		
		
	});
	
	tablestr += "</table>";
	
	populateSpanData( { "maintable" : tablestr });

}

function reDispNoCatTable()
{
	var tablestr = `
		<table id="dcb-basic" class="dcb-basic" width="75%">
		<tr>
		<th>Date</th>
		<th>Statement</th>
		<th>Amount</th>
		<th>Note</th>
		<th>---</th>
		</tr>
	
	`;
	
	var nocatlist = getUncatRecList();
	
	var nocatfinlist = nocatlist.map(nocat => lookupItem("finance_main", nocat.getId()));
		
	nocatfinlist.sort(function(s1, s2) { return -s1.getTransactDate().localeCompare(s2.getTransactDate()); });	
	
	nocatfinlist.forEach(function(onerec) {
		
		const dollarstr = getDollarFormat(onerec.getCentAmount());
		const nterec = lookupItem("finance_note", onerec.getId());
		const catsel = composeCatOptionSelectStr(onerec.getId());
		
		const rowstr = `
			<tr>
			<td>${onerec.getTransactDate().substring(5)}</td>
			<td>${onerec.getFullDesc()}</td>
			<td>${dollarstr}</td>
			<td>${nterec.getTheNote()}</td>	
			<td>
			
			<a href="javascript:editUserNote(${onerec.getId()})">
			<img src="/life/image/edit.png" height="18"/></a>

			&nbsp; 
			&nbsp; 
			&nbsp; 
			
			${catsel}
			
			</td>
			</tr>
		
		`;
			
		tablestr += rowstr;
	});
	
	tablestr += "</table>";
	
	populateSpanData({"nocattable" : tablestr});
}


function redisplay()
{
	reDispNoCatTable();
	
	reDispCatOkTable();
}


</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<br/>

<a href="FinanceAgg.jsp">Aggregation</a>

<h3>Finance Log</h3>


<div id="nocattable"></div>

<br/><br/>

<h3>Full Record List</h3>

<form>
Expense Type: <select name="catselect" onChange="javascript:redisplay()">
<%= catselect.getSelectStr("all") %>
</select>

Cutoff: <select name="cutoffdate" onChange="javascript:redisplay()">
<%= cutDaySelect.getSelectStr("---") %>
</select>

</form>

<br/><br/>

<div id="maintable"></div>


<br/><br/>


</center>
</body>
</html>
