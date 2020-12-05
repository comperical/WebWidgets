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

<%= JsCodeGenerator.getScriptInfo(request, "chinese", Util.listify("palace_item", "review_log")) %>

<script>

STUDY_PALACE_ID = 21;

function markStudyItem(palaceid)
{
	STUDY_PALACE_ID = palaceid;
	redisplay();
}

function redisplay()
{
	
	reDispAggTable();
	
	reDispBdTable();
}

function peelTimeString(timestamp)
{
	return timestamp.substring(5, timestamp.length-3);
}



function reDispAggTable()
{
	
	
	var mytable = $('<table></table>').addClass('dcb-basic').attr("id", "dcb-basic").attr("width", "70%");
	
	{
		var row = $('<tr></tr>').addClass('bar');
	
		["ID", "Character", "NumReview", "LastReview", "NetScore", "..."].forEach( function (hname) {
				
			row.append($('<th></th>').text(hname));
		});
		
		mytable.append(row);	
	}
	
	const statinfo = computeStatInfo();
	
	const sortedids = Object.keys(statinfo).sort(proxySort(myid => [statinfo[myid]["net_score"]]));	
	
	sortedids.forEach(function(palaceid) {
			
		const statpack = statinfo[palaceid];			
		const palaceitem = lookupItem("palace_item", palaceid);
		
		if(palaceitem == undefined)
			{ return; }
				
		var row = $('<tr></tr>').addClass('bar');
		
		row.append($('<td></td>').text(palaceitem.getId()));
		
		row.append($('<td></td>').text(palaceitem.getHanziChar()));
				
		row.append($('<td></td>').text(statpack["num_review"]));				
		
		row.append($('<td></td>').text(peelTimeString(statpack["last_review"])));				
		
		row.append($('<td></td>').text(statpack["net_score"].toFixed(2)));				
					
		
		{
		
			var opcell = $('<td></td>').attr("width", "15%");
						
			{
				var deleteref = "javascript:markStudyItem(" + palaceid + ")";
				
				var addtimeref = $('<a></a>').attr("href", deleteref).append(
										$('<img></img>').attr("src", "/life/image/inspect.png").attr("height", 18)
								);
				
				opcell.append(addtimeref);
			} 	
				
			row.append(opcell);		
		

		}	
		
		mytable.append(row);			
			
	});
	
	$('#aggregate_table').html(mytable);
	
}



function reDispBdTable()
{
	const bditem = STUDY_PALACE_ID;
	
	const itemlist = getItemList("review_log").filter(ritem => ritem.getItemId() == bditem);
	
	const palaceitem = lookupItem("palace_item", bditem);
	
	var netscore = 0;
	
	// var principlist = getItemList("palace_item");
	// principlist.sort(proxySort(a => [a.getDayCode()])).reverse();
	
	// var lastlogmap = getLastLogMap();
					
	var mytable = $('<table></table>').addClass('dcb-basic').attr("id", "dcb-basic").attr("width", "40%");
	
	{
		var row = $('<tr></tr>').addClass('bar');
	
		["Result", "Time", "Score", "..."].forEach( function (hname) {		
			row.append($('<th></th>').attr("width", "7%").text(hname));
		});
		
		mytable.append(row);	
	}
	
	itemlist.forEach(function(ritem) {
			
		var row = $('<tr></tr>').addClass('bar');
		
		// row.append($('<td></td>').text(ritem.getId()));				
				
		// row.append($('<td></td>').text(palaceitem.getHanziChar()));
		
		row.append($('<td></td>').text(ritem.getResultCode()));				
		
		row.append($('<td></td>').text(peelTimeString(ritem.getTimeStamp())));				

		var probscore = singleReviewItemScore(ritem);
		netscore += probscore;
		row.append($('<td></td>').text(probscore.toFixed(2)));		
		
		{
		
			var opcell = $('<td></td>');
						
			{
				var deleteref = "javascript:deleteItem(" + ritem.getId() + ")";
				
				var addtimeref = $('<a></a>').attr("href", deleteref).append(
										$('<img></img>').attr("src", "/life/image/remove.png").attr("height", 18)
								);
				
				opcell.append(addtimeref);
			} 	
				
			row.append(opcell);		
		}	
		
		mytable.append(row);
		
		
		// const palnote = getFirstPalaceNote(ritem.getPalaceNote());
		// row.append($('<td></td>').text(palnote));		
	});
	

	const jitter = (Math.random() - 0.5) * JITTER_SCALE;
		
	$('#bd_numreview').html(itemlist.length);
	$('#bd_character').html(palaceitem.getHanziChar());	
	
	$('#bd_basescore').html(netscore.toFixed(2));	
	$('#bd_netscore').html((netscore + jitter).toFixed(2));	
	



	$('#breakdown_table').html(mytable);	
}



</script>




</head>

<body onLoad="javascript:redisplay()">

<center>

<h2>Review Log</h2>

<br/></br>
<br/>
<br/>

<table width="30%" id="dcb-basic" align="center">
<tr>
<td>Character</td>
<td><span id="bd_character"></span></td>
</tr>
<tr>
<td>NumReviews</td>
<td><span id="bd_numreview"></span></td>
</tr>
<tr>
<td>BaseScore</td>
<td><span id="bd_basescore"></span></td>
</tr>
<tr>
<td>NetScore</td>
<td><span id="bd_netscore"></span></td>
</tr>
</table>

</br>


<div id="breakdown_table"></div>


<br/>
<br/>

<h3>Aggregates</h3>

<div id="aggregate_table"></div>



<br/>



</center>
</body>
</html>
