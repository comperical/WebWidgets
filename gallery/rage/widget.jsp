<%@ page session="false" import="com.caucho.vfs.*, com.caucho.server.webapp.*" %>

<%@ page import="java.util.*" %>

<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@ page import="lifedesign.basic.*" %>

<%@ page isELIgnored="true" %>

<%@include file="../../admin/AuthInclude.jsp_inc" %>


<html>
<head>
<title>Rage Log</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

<script>

function createNew()
{
	var shortname = prompt("ENRAGED about what?? : ");
	
	if(shortname)
	{
		var newid = newBasicId("rage_log");

		var todaycode = getTodayCode().getDateString();
		
		// created_on, active_on, completed_on, dead_line
		var newrec = {
			"id" : newid,
			"short_name" : shortname,
			"category": 'misc',
			"full_desc": "NotYetSet",
			"day_code" : todaycode		
		};		
		
		var newitem = buildRageLogItem(newrec);
		newitem.registerNSync();
		redisplay();
	}
}

function deleteItem(killid, shortname)
{
	if(confirm("Are you sure you want to delete item " + shortname + "?"))
	{
		lookupItem("rage_log", killid).deleteItem();
		
		redisplay();
	}
}


function getBasicDesc(rageitem)
{
	var fulldesc = rageitem.getFullDesc();
	var desclines = fulldesc.split("\n");
	return desclines[0];
}

function redisplay()
{
	var principlist = getItemList("rage_log");
	principlist.sort(proxySort(a => [a.getDayCode()])).reverse();
	
	// var lastlogmap = getLastLogMap();
					
	var activetable = $('<table></table>').addClass('dcb-basic').attr("id", "dcb-basic").attr("width", "80%");
	
	{
		const header = `
			<th width="7%">Date</th>
			<th>Category</th>
			<th>Name</th>
			<th>Desc</th>
			<th>Op</th>
		`;
		
		var row = $('<tr></tr>').html(header);
		
		activetable.append(row);	
	}
	
	principlist.forEach(function(princitem) {
				
		const rowstr = `
			<td>${princitem.getDayCode().substring(5)}</td>	
			<td>${princitem.getCategory()}</td>			
			<td>${princitem.getShortName()}</td>
			<td width="50%">${getBasicDesc(princitem)}</td>
			<td width="10%">
				<a href="RageItemEdit.jsp?item_id=${princitem.getId()}">
				<img src="/life/image/inspect.png" height=18"/></a>
				
				<%= HtmlUtil.nbsp(3) %>
				
				<a href="javascript:deleteItem(${princitem.getId()}, '${princitem.getShortName()}')">
				<img src="/life/image/remove.png" height="18"/></a>
			</td>
		`
		
		const row = $('<tr></tr>').addClass('bar').html(rowstr);

		activetable.append(row);
	});
	
	$('#maintable').html(activetable);


}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<h2>Rage Log</h2>

<a class="css3button" style="background:-webkit-gradient(linear,left top,left bottom,from(#c00),to(#800));"
onclick="javascript:createNew()">NEW</a>

<br/>
<br/>

<div id="maintable"></div>


<br/>



</center>
</body>
</html>
