<%@ page session="false" import="com.caucho.vfs.*, com.caucho.server.webapp.*" %>

<%@ page import="java.util.*" %>

<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@ page import="lifedesign.basic.*" %>
<%@ page import="lifedesign.classic.*" %><%@ page import="lifedesign.classic.JsCodeGenerator.*" %>

<%@include file="../AuthInclude.jsp_inc" %>

<%
	ArgMap argMap = HtmlUtil.getArgMap(request);
	
	OptSelector hskSelector = new OptSelector(Util.range(1, 6)).addKey("---");
	
	OptSelector palaceSelector = new OptSelector(Util.listify(true, false)).addKey("---");
	
%>


<html>
<head>
<title>Character Central</title>

<%@include file="../AssetInclude.jsp_inc" %>

<script src="ChineseTech.js"></script>

<%= JsCodeGenerator.getScriptInfo(request, "chinese", Util.listify("palace_item", "hanzi_data", "review_log")) %>

<script>

function createPalaceItem(hdid) 
{

	const createfrom = lookupItem("hanzi_data", hdid);
	console.log(createfrom);

	const newid = newBasicId("palace_item");
	
	const newrec = {
		"id" : newid,
		"hanzi_char" : createfrom.getHanziChar(),
		"palace_note": "EnterNoteHere",
		"extra_note" : "...",
		"meaning": createfrom.getDefinition()
	};		
	
	clearHanziDataCache();

	const newitem = buildPalaceItemItem(newrec);
	newitem.registerNSync();
	redisplay();

	alert("Created memory palace item, open in new tab to view");
}


function filterDisplayList(hdlist)
{
	const results = [];
	
	const hsklevel = getDocFormValue("hsk_level");
	const havepalace = getDocFormValue("have_palace");
	const searchdef = getDocFormValue("search4_define");
	const searchpin = getDocFormValue("search4_pinyin");
	
	hdlist.forEach(function(hditem) {
					
		if(hsklevel != "---" && hditem.getHskLevel() != parseInt(hsklevel))
			{ return; }
		
		if(havepalace != "---") 
		{
			const palaceitem = lookupPalaceItemByChar(hditem.getHanziChar());
			
			if(havepalace == "true" && palaceitem == null)
				{ return; }
			
			if(havepalace == "false" && palaceitem != null)
				{ return; }
		}
		
		if(searchdef.length > 0 && hditem.getDefinition().indexOf(searchdef) == -1)
			{ return; }
		
		if(searchpin.length > 0) 
		{
			const nodiac = stripDiacritics(hditem.getPinYin());
			
			if(nodiac != searchpin)
				{ return; }
		}
			
		results.push(hditem);		
			
	});
	
	return results;
	
}

function redisplay()
{
	var hanzilist = getItemList("hanzi_data");
	// principlist.sort(proxySort(a => [a.getId()])).reverse();
	
	// var lastlogmap = getLastLogMap();
					
	var activetable = $('<table></table>').addClass('dcb-basic').attr("id", "dcb-basic").attr("width", "70%");
	
	{
		var row = $('<tr></tr>').addClass('bar');
	
		["Character", "PinYin", "Radical", "Definition", "HSK", "Frequency", "Palace?", "..."].forEach( function (hname) {
		
			row.append($('<th></th>').text(hname));
		});
		
		activetable.append(row);	
	}
	
	hanzilist = filterDisplayList(hanzilist);
	
	hanzilist = hanzilist.slice(0, 400);
	
	statinfo = computeStatInfo();
	
	hanzilist.forEach(function(hditem) {
			
		var row = $('<tr></tr>').addClass('bar');
							
		row.append($('<td></td>').text(hditem.getHanziChar()));				
		
		row.append($('<td></td>').text(hditem.getPinYin()));
		
		row.append($('<td></td>').text(hditem.getRadical()));
		
		row.append($('<td></td>').text(hditem.getDefinition()));
		
		row.append($('<td></td>').text(hditem.getHskLevel()));
		
		row.append($('<td></td>').text(hditem.getFreqRank()));

		const palaceitem = lookupPalaceItemByChar(hditem.getHanziChar());
		
		const palacestr = palaceitem == null ? "---" :  statinfo[palaceitem.getId()].num_review;
		
		row.append($('<td></td>').text(palacestr));

		
		{
		
			var opcell = $('<td></td>').attr("width", "8%");

			// for(var i = 0; i < 3; i++)
			// 	{ opcell.append("&nbsp;"); }
			
			if(palaceitem != null) 
			{
					
				var viewurl = "PalaceItemEdit.jsp?item_id=" + palaceitem.getId();				
				
				var studyref = $('<a></a>').attr("href", viewurl).append(
										$('<img></img>').attr("src", "/life/image/inspect.png").attr("height", 18)
								);
				
				opcell.append(studyref);

			} else {

				var createurl = "javascript:createPalaceItem(" + hditem.getId() + ")";			
				
				var studyref = $('<a></a>').attr("href", createurl).append(
										$('<img></img>').attr("src", "/life/image/add.png").attr("height", 18)
								);
				
				opcell.append(studyref);
			}
			
			row.append(opcell);		
		}		

		activetable.append(row);		
	});
	
	$('#maintable').html(activetable);

	$('#itemcount').html(hanzilist.length);
}



</script>




</head>

<body onLoad="javascript:redisplay()">

<center>

<h2>Character Central</h2>

<br/>

#HSK Level : 
<select name="hsk_level" onChange="javascript:redisplay()">
<%= hskSelector.getSelectStr("---") %>
</select>

Have Palace : 
<select name="have_palace" onChange="javascript:redisplay()">
<%= palaceSelector.getSelectStr("---") %>
</select>

<br/>

Definition: <input type="text" name="search4_define" onChange="javascript:redisplay()" />

PinYin: <input type="text" name="search4_pinyin" onChange="javascript:redisplay()" />


<br/><br/>

Showing <span id="itemcount"></span> items

<div id="maintable"></div>


<br/>



</center>
</body>
</html>
