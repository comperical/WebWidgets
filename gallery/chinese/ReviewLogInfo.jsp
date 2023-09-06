
<html>
<head>
<title>Memory Palace Listing</title>

<%= DataServer.include(request, "tables=palace_item,review_log") %>

<script>

STUDY_PALACE_ID = 21;

BAYESIAN_STAT_MAP = fullBuildBayesStatMap("palace_item", "review_log");		


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
	var tablestr = `
		<table  class="basic-table" width="70%">
		<tr>
		<th>ID</th>
		<th>Character</th>
		<th>NumReview</th>
		<th>LastReview</th>
		<th>Base Score</th>
		<th>Net Score</th>
		<th>...</th>
		</tr>
	`;
	
	const statinfo = BAYESIAN_STAT_MAP;
	
	const sortedids = Object.keys(statinfo).sort(proxySort(myid => [statinfo[myid]["net_score"]]));	
	
	sortedids.forEach(function(palaceid) {
			
		const statpack = statinfo[palaceid];			
		const palaceitem = W.lookupItem("palace_item", palaceid);
		
		if(palaceitem == undefined)
			{ return; }

		var lastrevtime = statpack["num_review"] == 0 ? "new" : peelTimeString(statpack["last_review"]);
				
		const rowstr = `
			<tr>
			<td>${palaceitem.getId()}</td>
			<td>${palaceitem.getHanziChar()}</td>
			<td>${statpack["num_review"]}</td>
			<td>${lastrevtime}</td>
			<td>${statpack["base_score"].toFixed(2)}</td>
			<td>${statpack["net_score"].toFixed(2)}</td>
			<td>
			<a href="javascript:markStudyItem(${palaceid})">
			<img src="/u/shared/image/inspect.png" height="18" /></a>
			</td>
			</tr>
		`;
		
		tablestr += rowstr;
			
	});

	tablestr += "</table>";

	populateSpanData({"aggregate_table" : tablestr });	
}



function reDispBdTable()
{
	const bditem = STUDY_PALACE_ID;
	
	const itemlist = W.getItemList("review_log").filter(ritem => ritem.getItemId() == bditem);
	itemlist.sort(proxySort(a => [a.getTimeStamp()])).reverse();

	const palaceitem = W.lookupItem("palace_item", bditem);
	
	var netscore = 0;
	
	var principlist = W.getItemList("palace_item");
		
	var tablestr = `
		<table  class="basic-table" width="40%">	
		<tr>
		<th>Result</th>
		<th>Time</th>
		<th>Score</th>
		<th>...</th>
		</tr>
	`;

	
	itemlist.forEach(function(ritem) {
			
		var probscore = singleReviewItemScore(ritem);
		netscore += probscore;

		const rowstr = `
			<tr>
			<td>${ritem.getResultCode()}</td>
			<td>${peelTimeString(ritem.getTimeStamp())}</td>
			<td>${probscore.toFixed(2)}</td>
			<td>

			<a href="javascript:deleteItem(${ritem.getId()})">
			<img src="/u/shared/image/remove.png" height="18"></a>

			</td>
			</tr>
		`;
	
		
		tablestr += rowstr;		
	});
	

	// const jitter = (Math.random() - 0.5) * JITTER_SCALE;
	const jitter = 0;
		
	populateSpanData({
		"bd_numreview" : itemlist.length,
		"bd_character" : palaceitem.getHanziChar(),
		"bd_basescore" : netscore.toFixed(2),
		"bd_netscore" : (netscore + jitter).toFixed(2)
	});	

	tablestr += "</table>";

	populateSpanData({"breakdown_table" : tablestr });
}



</script>




</head>

<body onLoad="javascript:redisplay()">

<center>

<h2>Review Log</h2>

<table width="30%" class="basic-table" align="center">
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
