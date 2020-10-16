
<%@ page import="java.util.*" %>

<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.DbUtil.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@ page import="lifedesign.basic.*" %>
<%@ page import="lifedesign.classic.*" %><%@ page import="lifedesign.basic.FinanceSystem.*" %>

<%@include file="AuthInclude.jsp_inc" %>

<%
	String pageTitle = "Inspect Finance Record";

	ArgMap argMap = HtmlUtil.getArgMap(request);
	int recordId = argMap.getInt("id");
		
	OptSelector catSelect = new OptSelector(Util.listify(ExpenseType.values()));

%>

<html>
<head>
<title><%= pageTitle %></title>

<%@include file="AssetInclude.jsp_inc" %>

<%= JsCodeGenerator.getScriptInfo(request, "biz", Util.listify("finance_main", "finance_note")) %>

<script>

function saveNewDesc()
{
	var showItem = getNoteRecord();

	var newDesc = getDocFormValue("fullitemdesc");
	
	showItem.setTheNote(newDesc);
	
	syncSingleItem(showItem);		

	redisplay();
}

function editUserNote()
{
	var noteItem = getNoteRecord();

	var notetext = prompt("Enter note: ", noteItem.getTheNote());
	
	if(notetext)
	{
		noteItem.setTheNote(notetext);
		syncSingleItem(noteItem);		
		redisplay();	
	}
}

function updateExpenseCat()
{
	var noteItem = getNoteRecord();
	var expcat = getDocFormValue("expense_cat");
	
	noteItem.setExpenseCat(expcat);
	syncSingleItem(noteItem);		
	redisplay();	
}




function editPurchaseDate()
{
	var newdate = prompt("Enter a new purchase date: ");
	
	if(newdate)
	{
		dcmap = getDayCodeMap();
	
		if(!dcmap.hasOwnProperty(newdate))
		{
			alert("Improper date format!");
			return;
		}
		
		var showitem = getItem2Show()
		
		showitem.setPurchaseDate(newdate);
		
		syncSingleItem(showitem);		

		redisplay();		
	}
}

function getMainRecord()
{
	var onelist = getItemList("finance_main")
			.filter(it => it.getId() == <%= recordId %>);
			
	return onelist[0];
	
}


function getNoteRecord()
{
	var onelist = getItemList("finance_note")
			.filter(it => it.getId() == <%= recordId %>);
			
	return onelist[0];	
}

function redisplay()
{

	// var showItem = getItem2Show();
	
	var mainItem = getMainRecord();
	var noteItem = getNoteRecord();
	
	$('#itemdesc').html(mainItem.getFullDesc());

	$('#itemtype').html(noteItem.getExpenseCat());
	
	$('#pur_date').html(mainItem.getTransactDate());
	
	$('#amount').html(mainItem.getCentAmount());
	
	$('#user_note').html(noteItem.getTheNote());
	
	document.getElementById("expense_cat").value = noteItem.getExpenseCat();
}

function back2Def()
{
	var showItem = getItem2Show();

	window.location.href = "ClothingList.jsp?showtype=" + showItem.getMainType();
	
	return;
}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<br/><br/>

<h3><%= pageTitle %></h3>

<a href="FinanceLog.jsp">Back2Log</a> 

<br/><br/>


<table width="50%" id="dcb-basic">
<tr>
<td width="50%">Desc</td>
<td><div id="itemdesc"></div></td>
<td></td>
</tr>
<tr>
<td width="50%">Purchased</td>
<td><span id="pur_date"></span>
<td></td>
</td>
</tr>
<tr>
<td width="50%">Amount</td>
<td><span id="amount"></span></td>
<td></td>
</tr>
<tr>
<td width="50%">Note</td>
<td><span id="user_note"></span></td>
<td><a href="javascript:editUserNote()"><img src="/life/image/edit.png" height=18/></a></td>
</tr>
<tr>
<td width="50%">Category</td>

<td colspan="2">
<select id="expense_cat" name="expense_cat" onChange="javascript:updateExpenseCat()">
<%= catSelect.getSelectStr() %>
</select>
</td>
</tr>

</table>

</body>
</html>
