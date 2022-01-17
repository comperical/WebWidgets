
<html>
<head>
<title>Memory Palace Listing</title>

<script src="ChineseTech.js"></script>
<script src="../hanyu/pin_yin_converter.js"></script>


<%= DataServer.include(request, "tables=palace_item,review_log,hanzi_data,confounder,word_memory") %>

<%= DataServer.includeIfOkay(request, "widgetname=minitask&tables=mini_task_list") %>

<%= DataServer.includeIfOkay(request, "widgetname=cedict&tables=hanzi_example") %>

<script>

TARGET_REVIEWS_PER_DAY = 30;

CURRENT_PROMPT_ITEM = computePromptItem();

CHARACTER_VOCAB_MAP = buildChar2VocabMap(getItemList("word_memory"));

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
	newitem.syncItem();
	
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

	const hanzidata = lookupHanziDataByChar(CURRENT_PROMPT_ITEM.getHanziChar());

	/// const pinyinstr = PinyinConverter.convert(vocab.getPinYin());

	// 	<td>${hanzidata.getPinYin()}</td>

	
	const basicprompt = `MiniTaskNote for character=${CURRENT_PROMPT_ITEM.getHanziChar()} (${hanzidata.getPinYin()}), ID=${CURRENT_PROMPT_ITEM.getId()}`;
	
	const notename = prompt("Enter note : ", basicprompt);
	
	const weblink = "\nhttps://webwidgets.io/u/dburfoot/chinese/CharacterCentral.jsp?item_id=" + CURRENT_PROMPT_ITEM.getId();
	
	if(notename)
	{
		const newrec = {
			"id" : newBasicId("mini_task_list"),
			"alpha_date" : getTodayCode().getDateString(),
			"omega_date" : "",
			"is_backlog" : 0,
			"priority" : 1,
			"short_desc" : notename,
			"task_type" : "chinese",
			"extra_info" : weblink
		};		
		
		const newitem = buildMiniTaskListItem(newrec);
		newitem.syncItem();
		
		alert("Created new MTL item");
	}
	
}

function showStats() 
{
	const progmap = getPalaceProgress("review_log");
	
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


/* 
Okay, this approach based on time analysis has TONS of problems.
One is time parsing, which is a fiasco
But also, the code becomes very slow since you need to do time computations on all these records, 
and there are a lot of them
Instead, just look at the most recent N records, and skip them
*/
/*
function getRecentPromptIdSet() 
{
    const cutoff = exactMomentNow().withAddedMilli(-DAY_MILLI)

    const recentset = new Set();

    getItemList("review_log").forEach(function(itm) {
    
        // Violating my own rule, timestamps should have timezone as part of variable or column name.
        const logmoment = exactMomentFromIsoBasic(itm.getTimeStamp(), "PST");

        console.log("Item time: " + logmoment.getEpochTimeMilli());
        console.log("Cutoff time: " + cutoff.getEpochTimeMilli());

        if(logmoment.getEpochTimeMilli() < cutoff.getEpochTimeMilli())
            { return; }

        recentset.add(itm.getItemId());
    });
    
    return recentset;  
}
*/

function getRecentPromptIdSet(backup) 
{
	const recentlist = getItemList("review_log").sort(proxySort(item => [item.getTimeStamp()]));
    const recentset = new Set();

    while(recentset.size < backup && recentlist.length > 0) {
    	const nextone = recentlist.pop();
    	// console.log("Adding next one " + nextone.getTimeStamp() + " ID is " + nextone.getItemId());
    	recentset.add(nextone.getItemId());
    }

    return recentset;
}

function computePromptItem()
{
	// Okay this is the computation of the item with the lowest score
	const statinfo = computeStatInfo();
	const recentids = getRecentPromptIdSet(TARGET_REVIEWS_PER_DAY);
	
	// console.log("Stat Info size is " + Object.keys(statinfo).length);
	// console.log("receit IDs are " + recentids);
	// GOD DAMMIT JAVASCRIPT
	// This line has fucked me up MULTIPLE times

	// Okay the issue here is that somehow when you call Object.keys, or even iterate through the keys,
	// you get STRINGS instead of integers, even though the keys of statinfo are integers!!!!
	// Since the recent ID set holds integers, the containment check will return false
	// Okay, the point is that Javascript objects have property NAMES
	const okayids = Object.keys(statinfo).filter(function(charid) { return !recentids.has(parseInt(charid)); });	
	const lowestid = minWithProxy(okayids, it => statinfo[it]["net_score"]);

	// console.log("All IDS " + Object.keys(statinfo).length);

	// console.log("Recents IDS " + recentids.size);
	// console.log("Okay IDS " + okayids.length);

	
	// const allitems = getItemList("palace_item");	
	// return allitems[Math.floor(Math.random()*allitems.length)];
	const promptitem = lookupItem("palace_item", lowestid);
	
	return lookupItem("palace_item", lowestid);
}

function redisplay()
{	

	const hanzidata = lookupHanziDataByChar(CURRENT_PROMPT_ITEM.getHanziChar());
						
	const storyhtml = CURRENT_PROMPT_ITEM.getPalaceNote().replace(/\n/g, "<br/>");

	var infotable = `
		<table class="basic-table" width="50%" border="0">
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
	`;

	{
		const confidx = getConfounderIndex();
		if(CURRENT_PROMPT_ITEM.getHanziChar() in confidx) 
		{
			// TODO: should eventually show ALL of these, there might be many.
			const conflist = confidx[CURRENT_PROMPT_ITEM.getHanziChar()];
			conflist.forEach(function(confitem) {

				infotable += `
					<tr>
					<td width="20%"><b>Confounder</b></td>
					<td>
					${confitem.getLeftChar()} / ${confitem.getRghtChar()}  :
					${confitem.getExtraInfo()}
					</td>
					</tr>
				`;
			});
		}
	}


	const vocabex = CHARACTER_VOCAB_MAP[CURRENT_PROMPT_ITEM.getHanziChar()] || [];

	for(var idx = 0; idx < vocabex.length; idx++) {

		const vocab = vocabex[idx];
		const promptstr = (idx == 0 ? "Vocab" : "");

		const pinyinstr = PinyinConverter.convert(vocab.getPinYin());
		const engremoved = removeClCruft(vocab.getEnglish());

		infotable += `
			<tr>
			<td width="20%"><b>${promptstr}</b></td>
			<td>${vocab.getSimpHanzi()} (${pinyinstr}) ${engremoved}</td>
			</tr>
		`;
	}

	infotable += "</table>";


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

<table class="basic-table" width="50%" border="0">
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
