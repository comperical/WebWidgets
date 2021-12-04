
<%@include file="../../admin/AuthInclude.jsp_inc" %>

<html>
<head>
<title>Memory Palace Listing</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<script src="ChineseTech.js?bust_cache=12"></script>


<%= DataServer.basicIncludeOnly(request, "palace_item", "review_log") %>


<script>

STUDY_PALACE_ID = 21;

PRIOR_PROB_GOOD = 0.1;

// This is the big parameter that controls the half-life of a review result.
// After N days, the impact of a review will fall in half.
HALF_LIFE_OF_RESULT = 45;

REVIEW_DECAY_PARAM = Math.log(0.5)/HALF_LIFE_OF_RESULT;

JITTER_SCALE = 0.05;

function markStudyItem(palaceid)
{
    STUDY_PALACE_ID = palaceid;
    redisplay();
}

function bayesianStatInfo()
{
    return bayesianStatInfoCalc("palace_item", "review_log")
}

function bayesianUpdate(ritem)
{
    const rescode = ritem.getResultCode();
    massert(["easy", "good", "bad"].includes(rescode), "Bad review code: " +rescode);

    const badresult = (rescode == "bad"); // treat good and easy in the same way
    
    // Look up the daycode of the item.
    // Calculate number of days since review.    
    const daytimestr = ritem.getTimeStamp().substring(0, 10);
    const itemdate = lookupDayCode(daytimestr);
    massert(itemdate != undefined, "Failed to find day time string " + daytimestr); 
    var ageindays = itemdate.daysUntil(getTodayCode());
    ageindays = ageindays == 0 ? 1 : ageindays; // 0 result here will give P=1 below
    
    // This is the probability that the current status agrees with the result.
    const probagree = 0.5 * (1 + Math.exp(ageindays * REVIEW_DECAY_PARAM));

    const probgood = badresult ? 1 - probagree : probagree;
    return [probgood, 1-probgood];
}

function bayesianStatInfoCalc(itemtable, logtable)
{
    const palacelist = getItemList(itemtable).filter(item => item.getIsActive() == 1);
    const reviewlist = getItemList(logtable).sort(proxySort(item => [item.getTimeStamp()]));

    var statmap = {};
    
    palacelist.forEach(function(pitem) {
        var statpack = new Object();
        statpack["num_review"] = 0;
        statpack["log_prob_good"] = Math.log(PRIOR_PROB_GOOD);
        statpack["log_prob_badd"] = Math.log(1 - PRIOR_PROB_GOOD);
        statpack["last_review"] = "2000";
        statmap[pitem.getId()] = statpack;                      
    });
    
    reviewlist.forEach(function(ritem) {
    
        // This is an FKEY error            
        if(!statmap.hasOwnProperty(ritem.getItemId()))
            { return; }
        
        const myitem = statmap[ritem.getItemId()];
        // const basescore = singleReviewItemScore(ritem);
        const basescore = 0.1;

        const goodbadd = bayesianUpdate(ritem);
        // console.log("Update Good/Badd is " + goodbadd);
        
        // Sort by review timestamp
        myitem["last_review"] = ritem.getTimeStamp();
        myitem["num_review"] += 1;

        myitem["log_prob_good"] += Math.log(goodbadd[0]);
        myitem["log_prob_badd"] += Math.log(goodbadd[1]);
    });


    palacelist.forEach(function(pitem) {

        const statpack = statmap[pitem.getId()];

        // These are unnormalized.
        var probgood = Math.exp(statpack["log_prob_good"]);
        var probbadd = Math.exp(statpack["log_prob_badd"]);

        massert(0 < probgood && probgood < 1, "Bad value for good prob: " + probgood);
        massert(0 < probbadd && probbadd < 1, "Bad value for badd prob: " + probbadd);
        //  && 0 < probbadd && probbadd < 1);
        const partfunc = probgood + probbadd;

        probgood /= partfunc;
        probbadd /= partfunc;

        statpack["prob_good"] = probgood;
        statpack["prob_badd"] = probbadd;

        statpack["base_score"] = probgood;
        statpack["net_score"] = probgood + (Math.random() - 0.5) * JITTER_SCALE;
    });    

    return statmap; 
    
    
    
}


function redisplay()
{
    
    reDispAggTable();
    
    // reDispBdTable();
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
    
    const statinfo = bayesianStatInfo();
    
    const sortedids = Object.keys(statinfo).sort(proxySort(myid => [statinfo[myid]["net_score"]])); 
    
    sortedids.forEach(function(palaceid) {
            
        const statpack = statinfo[palaceid];            
        const palaceitem = lookupItem("palace_item", palaceid);
        
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
            <img src="/life/image/inspect.png" height="18" /></a>
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
    
    const itemlist = getItemList("review_log").filter(ritem => ritem.getItemId() == bditem);
    itemlist.sort(proxySort(a => [a.getTimeStamp()])).reverse();

    const palaceitem = lookupItem("palace_item", bditem);
    
    var netscore = 0;
    
    var principlist = getItemList("palace_item");
        
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
            <img src="/life/image/remove.png" height="18"></a>

            </td>
            </tr>
        `;
    
        
        tablestr += rowstr;     
    });
    

    const jitter = (Math.random() - 0.5) * JITTER_SCALE;
        
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

<br/>
<br/>

<h3>Aggregates</h3>

<div id="aggregate_table"></div>



<br/>



</center>
</body>
</html>
