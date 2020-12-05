<%@ page session="false" import="com.caucho.vfs.*, com.caucho.server.webapp.*" %>

<%@ page import="java.util.*" %>

<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@ page import="lifedesign.basic.*" %>
<%@ page import="lifedesign.classic.*" %><%@ page import="lifedesign.classic.JsCodeGenerator.*" %>

<%@include file="../../admin/AuthInclude.jsp_inc" %>


<html>
<head>
<title>Memory Palace Listing</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<script src="ChineseTech.js"></script>

<%= JsCodeGenerator.getScriptInfo(request, "chinese", Util.listify("palace_item")) %>

<script>

function createNew()
{	
	var newid = newBasicId("palace_item");
	
	// created_on, active_on, completed_on, dead_line
	var newrec = {
		"id" : newid,
		"hanzi_char" : "x",
		"palace_note": "EnterNoteHere",
		"extra_note" : "...",
		"meaning": "EnterMeaningHere"
	};		
	
	const newitem = buildPalaceItemItem(newrec);
	newitem.registerNSync();
	redisplay();
	
	const newurl = "PalaceItemEdit.jsp?item_id=" + newid;
	window.location.href=newurl;
}

function deleteItem(killid)
{
	if(confirm("Warning: it's usually better to deactivate or edit!! \n\nAre you sure you want to delete this character item?"))
	{
		lookupItem("palace_item", killid).deleteItem();
		
		redisplay();
	}
}

function redisplay()
{
	var principlist = getItemList("palace_item");
	principlist.sort(proxySort(a => [a.getId()])).reverse();
	
	// var lastlogmap = getLastLogMap();
					
	var activetable = $('<table></table>').addClass('dcb-basic').attr("id", "dcb-basic").attr("width", "70%");
	
	{
		var row = $('<tr></tr>').addClass('bar');
	
		["ID", "Character", "Meaning", "Note", "..."].forEach( function (hname) {
		
			if(hname == "Date")
			{
				row.append($('<th></th>').attr("width", "7%").text(hname));
			} else {
				row.append($('<th></th>').text(hname));
			}
		});
		
		activetable.append(row);	
	}
		
	for(var pi in principlist)
	{
	
		var princitem = principlist[pi];
	
		var row = $('<tr></tr>').addClass('bar');
			
		// row.append($('<td></td>').text(princitem.getId()));					
		
		row.append($('<td></td>').text(princitem.getId()));				
		
		row.append($('<td></td>').text(princitem.getHanziChar()));				

		row.append($('<td></td>').text(princitem.getMeaning()));				
	
		const palnote = getFirstPalaceNote(princitem.getPalaceNote());
		row.append($('<td></td>').text(palnote));				
				
		{
		
			var opcell = $('<td></td>').attr("width", "15%");
			

			for(var i = 0; i < 3; i++)
				{ opcell.append("&nbsp;"); }
				
			{
				var viewurl = "PalaceItemEdit.jsp?item_id=" + princitem.getId();				
				
				var studyref = $('<a></a>').attr("href", viewurl).append(
										$('<img></img>').attr("src", "/life/image/inspect.png").attr("height", 18)
								);
				
				opcell.append(studyref);
			} 						
			
			
			for(var i = 0; i < 3; i++)
				{ opcell.append("&nbsp;"); }				
			
			
			{
				var deleteref = "javascript:deleteItem(" + princitem.getId() + ")";
				
				var addtimeref = $('<a></a>').attr("href", deleteref).append(
										$('<img></img>').attr("src", "/life/image/remove.png").attr("height", 18)
								);
				
				opcell.append(addtimeref);
			} 	
				
			row.append(opcell);		
		

		}
		
		activetable.append(row);
	}
	
	
	$('#maintable').html(activetable);


}



</script>




</head>

<body onLoad="javascript:redisplay()">

<center>

<h2>Memory Palace</h2>

<a class="css3button" onclick="javascript:createNew()">NEW</a>

<br/>
<br/>

<div id="maintable"></div>


<br/>



</center>
</body>
</html>
