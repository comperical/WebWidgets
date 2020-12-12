
<%@include file="../../admin/AuthInclude.jsp_inc" %>


<html>
<head>
<title>Memory Palace Listing</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<script src="ChineseTech.js"></script>

<%= DataServer.basicIncludeOnly(request, "palace_item", "review_log", "hanzi_data", "confounder") %>

<%= DataServer.includeIfAvailable(request, "minitask", "mini_task_list") %>

<%= DataServer.includeIfAvailable(request, "cedict", "hanzi_example") %>


<script>

CURRENT_PROMPT_ITEM = computePromptItem();

function markResult(resultcode)
{	
	// This creates a review_log item and then redisplays the quiz.
	const newid = newBasicId("review_log");
	const timestamp = calcFullLogTimeStr(new Date());
	const newrec = {
		"id" : newid,
		"study_code" : "palace",
		"item_id" : CURRENT_PROMPT_ITEM.getId(),
		"result_code" : resultcode,
		"time_stamp" : timestamp,
		"extra_info" : ""
	};
	
	const newitem = buildReviewLogItem(newrec);
	newitem.registerNSync();
	
	CURRENT_PROMPT_ITEM = computePromptItem();
	redisplay();	

	toggleHidden4Class('prompt_answer');	
}

function createMiniTaskNote()
{
	if(!haveTable("mini_task_list"))
	{
		alert("You don't have a Notes widget. \n\nPlease ask your friendly admin to set one up!!");
		return;
	}
	
	const basicprompt = "MiniTaskNote for character=" + CURRENT_PROMPT_ITEM.getHanziChar() + ", ID=" + CURRENT_PROMPT_ITEM.getId() + " : ";
	
	const notename = prompt("Enter note : ", basicprompt);
	
	const weblink = "\nhttps://danburfoot.net/life/chinese/CharacterCentral.jsp?item_id=" + CURRENT_PROMPT_ITEM.getId();
	
	if(notename)
	{
		const newrec = {
			"id" : newBasicId("mini_task_list"),
			"alpha_date" : getTodayCode().getDateString(),
			"omega_date" : "",
			"is_backlog" : 0,
			"priority" : 1,
			"short_desc" : notename,
			"task_type" : "life",
			"extra_info" : weblink
		};		
		
		const newitem = buildMiniTaskListItem(newrec);
		newitem.registerNSync();
		
		alert("Created new MTL item");
	}
	
}

function showStats() 
{
	const progmap = getPalaceProgress();
	
	const mystring = 
		"Today: " + progmap[0] + "\n" +
		"Last week: " + progmap[7] + "\n" +
		"Last month: " + progmap[30];
		
	alert(mystring);
}

function showAnswer()
{
	// This doesn't do anything, not even redisplay
	toggleHidden4Class('prompt_answer');
}

function getRecentPromptIdSet() 
{
	var items = getItemList("review_log").sort(proxySort(itm => [itm.getId()])).reverse();
	var recentlist = [];
	
	items.forEach(function(itm) {
	
		if(recentlist.length > 50)
			{ return; }
		
		recentlist.push(itm.getItemId());
	});
	
	return recentlist;	
}


function computePromptItem()
{
	// Okay this is the computation of the item with the lowest score
	const statinfo = computeStatInfo();
	const recentids = getRecentPromptIdSet();
	// console.log(recentids);
	// GOD DAMMIT JAVASCRIPT
	const okayids = Object.keys(statinfo).filter(charid => recentids.indexOf(parseInt(charid)) == -1);
	// console.log(okayids);

	const lowestid = minWithProxy(okayids, it => statinfo[it]["net_score"]);
	
	// const allitems = getItemList("palace_item");	
	// return allitems[Math.floor(Math.random()*allitems.length)];
	const promptitem = lookupItem("palace_item", lowestid);
	
	return lookupItem("palace_item", lowestid);
}


function redisplay()
{	
	var confounderstr = "...";
	{
		const confidx = getConfounderIndex();
		if(CURRENT_PROMPT_ITEM.getHanziChar() in confidx) 
		{
			// TODO: should eventually show ALL of these, there might be many.
			const confitem = confidx[CURRENT_PROMPT_ITEM.getHanziChar()][0];
			confounderstr = `
				${confitem.getLeftChar()} / ${confitem.getRghtChar()}  :
				${confitem.getExtraInfo()}
			`;

			// console.log("Found confounder: " + confitem);
		}
	}

	const hanzidata = lookupHanziDataByChar(CURRENT_PROMPT_ITEM.getHanziChar());
						
	const storyhtml = CURRENT_PROMPT_ITEM.getPalaceNote().replace(/\n/g, "<br/>");


	var examplestr = "";
	const foundex = findExample(CURRENT_PROMPT_ITEM.getHanziChar());
	if(foundex)
	{
		const pinyinstr = foundex.getConvertedPy();

		examplestr = `
			<tr>
			<td width="20%"><b>Example</b></td>
			<td>${foundex.getSimpHanzi()} (${pinyinstr}) ${foundex.getEnglish()}</td>
			</tr>
		`;
	}


	var infotable = `
		<table id="dcb-basic" width="50%" border="0">
		<tr>
		<td width="20%"><b>Meaning</b></td>
		<td>${CURRENT_PROMPT_ITEM.getMeaning()}</td>
		<tr>
		<td width="20%"><b>PinYin</b></td>
		<td>${hanzidata.getPinYin()}</td>
		<tr>
		<td width="20%"><b>Notes</b></td>
		<td>${CURRENT_PROMPT_ITEM.getExtraNote()}</td>
		</tr>

		<tr>
		<td width="20%"><b>Confounder</b></td>
		<td>${confounderstr}</td>
		</tr>

		${examplestr}
		</table>

	`;

	populateSpanData({
		"thestory" : storyhtml,
		"info_table" : infotable,
		"thecharacter" : CURRENT_PROMPT_ITEM.getHanziChar()
	});


}



</script>




</head>

<body onLoad="javascript:redisplay()">

<center>

<h2>Study Hanzi</h2>

<br/>
<br/>

<font size="60"><span id="thecharacter"></span></font>


<br/></br>
<br/>
<br/>


<span class="prompt_answer">

<a class="css3button" onclick="javascript:showAnswer()">SHOW</a> 

&nbsp; 
&nbsp; 
&nbsp; 
&nbsp; 

<a class="css3button" onclick="javascript:showStats()">STATS</a> 


</span>

<span class="prompt_answer" hidden>

<table id="dcb-basic" width="50%" border="0">
<tr>
<td width="20%"><b>Story</b></td>
<td><span id="thestory"></span></td></tr>
</table>

<br/>
<br/>

<span id="info_table"></span>

<br/><br/>

<a class="css3button" onclick="javascript:markResult('easy')">TOO EASY</a> 


&nbsp; 
&nbsp; 
&nbsp; 
&nbsp; 
&nbsp; 

<a class="css3button" onclick="javascript:markResult('good')">GOOD</a> 


&nbsp; 
&nbsp; 
&nbsp; 
&nbsp; 
&nbsp; 

<a class="css3button" style="background:-webkit-gradient(linear,left top,left bottom,from(#c00),to(#800));"
onclick="javascript:markResult('bad')">BAD</a> 


&nbsp; 
&nbsp; 
&nbsp; 
&nbsp; 
&nbsp; 

<a class="css3button" style="background:-webkit-gradient(linear,left top,left bottom,from(#cc0),to(#880));"
onclick="javascript:createMiniTaskNote()">NOTE</a> 

</span>

<br/>
<br/>



<br/>



</center>
</body>
</html>
