
<%@ page import="java.util.*" %>

<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.DbUtil.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@ page import="lifedesign.basic.*" %>
<%@ page import="lifedesign.classic.*" %><%@ page import="lifedesign.classic.JsCodeGenerator.*" %>

<%@include file="../../admin/AuthInclude.jsp_inc" %>


<%
	String pageTitle = "Study Exercise Item";

	ArgMap argMap = HtmlUtil.getArgMap(request);
	int itemId = argMap.getInt("item_id");
	
	OptSelector categoryList = new OptSelector(Util.listify("brain", "body"));

	OptSelector intSelectList = new OptSelector(Util.range(1, 20));
%>

<html>
<head>
<title><%= pageTitle %></title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>


<script>

function flipActive()
{
	var showItem = getItem2Show();

	var curActive = showItem.getIsActive();
	
	showItem.setIsActive(curActive == 1 ? 0 : 1);
	
	syncSingleItem(showItem);		

	redisplay();
}

function saveNewDesc()
{
	var showItem = getItem2Show();

	var newDesc = getDocFormValue("fullitemdesc");
	
	showItem.setFullDesc(newDesc);
	
	syncSingleItem(showItem);		

	redisplay();
}

function updateExType()
{
	const showitem = getItem2Show();
	const newtype = getDocFormValue("sel_ex_type");
	
	showitem.setExType(newtype);
	syncSingleItem(showitem);		
	redisplay();

}

function updateGoal()
{
	const showitem = getItem2Show();
	const newgoal = getDocFormValue("sel_goal");
	
	showitem.setWeeklyGoal(newgoal);
	syncSingleItem(showitem);		
	redisplay();
}

function updateDistance()
{
	const showitem = getItem2Show();
	const newdist = getDocFormValue("sel_distance");
	
	showitem.setUsualDistance(newdist);
	syncSingleItem(showitem);		
	redisplay();
}

function editShortCode()
{
	var showitem = getItem2Show()
	var shortcode = prompt("Enter a new workout code: ", showitem.getShortCode());
	
	if(shortcode)
	{		
		showitem.setShortCode(shortcode);
		syncSingleItem(showitem);		
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
		syncSingleItem(showitem);		
		redisplay();		
	}
}

function getItem2Show()
{
	var onelist = getItemList("exercise_plan")
			.filter(it => it.getId() == <%= itemId %>);
			
	return onelist[0];
}

function redisplay()
{

	var showItem = getItem2Show();
	
	$('#short_code').html(showItem.getShortCode());
	
	$('#unit_code').html(showItem.getUnitCode());

	$('#ex_type').html(showItem.getExType());
		
	$('#usual_distance').html(showItem.getUsualDistance());
	
	$('#weekly_goal').html(showItem.getWeeklyGoal());
	
	getUniqElementByName("sel_ex_type").value = showItem.getExType();
	
	getUniqElementByName("sel_distance").value = showItem.getUsualDistance();	
	
	var curItemDesc = showItem.getFullDesc();
	
	// Okay, this took me a while to get right. The issue is that 
	// the standard string.replace(...) won't do a global, and there is no replaceAll
	var desclinelist = curItemDesc.replace(/\n/g, "<br/>");
	$('#itemdescline').html(desclinelist);
	
	var activebool = showItem.getIsActive() == 1;
	
	$('#isactive').html(activebool ? "YES" : "NO");	
}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<br/><br/>

<h3><%= pageTitle %></h3>

<br/><br/>

<table width="30%" id="dcb-basic">
<tr>
<td>Back</td>
<td></td>
<td><a href="ExerciseTemplate.jsp"><img src="/life/image/leftarrow.png" height="18"/></a></td>
</tr>

<tr>
<td width="50%">ShortCode</td>
<td><div id="short_code"></div></td>
<td><a href="javascript:editShortCode()"><img src="/life/image/edit.png" height=18/></a></td>
</tr>
<tr>
<td width="50%">Type</td>
<td><div id="ex_type"></div></td>
<td>
<select name="sel_ex_type" onChange="javascript:updateExType()">
<%= categoryList.getSelectStr("---") %>
</select>
</td>
</tr>



<tr>
<td width="50%">Goal</td>
<td><div id="weekly_goal"></div></td>
<td>
<select name="sel_goal" onChange="javascript:updateGoal()">
<%= intSelectList.getSelectStr("---") %>
</select>
</td>
</tr>

<tr>
<td width="50%">Usual Distance</td>
<td><div id="usual_distance"></div></td>
<td>
<select name="sel_distance" onChange="javascript:updateDistance()">
<%= intSelectList.getSelectStr("---") %>
</select>
</td>
</tr>


<tr>
<td width="50%">Units</td>
<td><div id="unit_code"></div></td>
<td><a href="javascript:editUnitCode()"><img src="/life/image/edit.png" height=18/></a></td>
</tr>




<tr>
<td width="50%">Active?</td>
<td><span id="isactive"></span>

</td>
<td><a href="javascript:flipActive()"><img src="/life/image/cycle.png" height=18/></a></td>
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
<textarea id="fullitemdesc" name="fullitemdesc" rows="10" cols="50"></textarea>
</form>

<a href="javascript:saveNewDesc()">save desc</a>

</body>
</html>
