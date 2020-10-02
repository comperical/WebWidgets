
<%@ page import="java.util.*" %>

<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.DbUtil.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@ page import="lifedesign.basic.*" %>

<%@include file="../../life/AuthInclude.jsp_inc" %>

<%
	String pageTitle = "Rage Item Edit";

	ArgMap argMap = HtmlUtil.getArgMap(request);
	int itemId = argMap.getInt("item_id");
	
	// TODO: make this an enum somewhere
	List<String> catList = Util.listify("misc", "tech", "govt", "personal", "politics", "self2blame");
	OptSelector categorySel = new OptSelector(catList);

%>

<html>
<head>
<title><%= pageTitle %></title>

<%@include file="../../life/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

<script>

function saveNewDesc()
{
	var showItem = getItem2Show();
	var newDesc = getDocFormValue("full_desc");
	showItem.setFullDesc(newDesc);
	syncSingleItem(showItem);		
	redisplay();
}

function editShortName()
{
	var showItem = getItem2Show();
	var newname = prompt("Enter new name for item: ", showItem.getShortName());
	if(newname)
	{
		showItem.setShortName(newname);
		syncSingleItem(showItem);
		redisplay();
	}
}


function updateCategory()
{
	var showItem = getItem2Show();
	var newcat = getDocFormValue("new_category");
	showItem.setCategory(newcat);
	syncSingleItem(showItem);		
	redisplay();
}



function getItem2Show()
{
	var onelist = getItemList("rage_log").filter(it => it.getId() == <%= itemId %>);
			
	return onelist[0];
}

function redisplay()
{

	var showItem = getItem2Show();
	
	['day_code', 'short_name', 'category', 'full_desc'].forEach(function(fname) {
			var qname = "#" + fname;
			$(qname).html(showItem.getField(fname));	
		}
	);
		
	// Set the drop-down default
	getUniqElementByName("new_category").value = showItem.getCategory();
	
	var curItemDesc = showItem.getFullDesc();
	
	// Okay, this took me a while to get right. The issue is that 
	// the standard string.replace(...) won't do a global, and there is no replaceAll
	var desclinelist = curItemDesc.replace(/\n/g, "<br/>");
	
	$('#itemdescline').html(desclinelist);
}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<br/><br/>

<h3><%= pageTitle %></h3>

<br/>

<table width="50%" id="dcb-basic">
<tr>
<td width="25%">Back</td>
<td></td>
<td width="30%"><a href="widget.jsp"><img src="/life/image/leftarrow.png" height="18"/></a></td>
</tr>
<tr>
<td>Name</td>
<td><div id="short_name"></div></td>
<td><a href="javascript:editShortName()"><img src="/life/image/edit.png" height=18/></a></td>
</tr>
<tr>
<td>Category</td>
<td><div id="category"></div></td>
<td>
<select name="new_category" onChange="javascript:updateCategory()">
<%= categorySel.getSelectStr("misc") %>
</select>
</td>
</tr>
<tr>
<td>Date</td>
<td><span id="day_code"></span>
<td></td>
</tr>
</table>

<br/>
<br/>

<table id="dcb-basic" width="30%">
<tr>
<td>
<span id="itemdescline">xxx<br/>yyy</span>
</td>
</tr>
</table>

<br/>
<br/>

<form>
<textarea id="full_desc" name="full_desc" rows="10" cols="50"></textarea>
</form>

<a href="javascript:saveNewDesc()">save desc</a>

</body>
</html>
