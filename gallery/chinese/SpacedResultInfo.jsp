
<%@include file="../../admin/AuthInclude.jsp_inc" %>


<html>
<head>
<title>Spaced Result</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<script src="ChineseTech.js"></script>

<%= DataServer.basicIncludeOnly(request, "palace_item", "review_log", "hanzi_data", "confounder") %>


<script>

HANZI_ID = 300;

function redisplay() {

    populateSpanData({
        "studyinfo" : getStudyInfo(),
        "ready_card" : getReadyCardTable()
    });

}

function result2Score(rcode) {

    const scoremap = {
        'easy' : 4,
        'good' : 3,
        'bad' : 2
    }

    massert(rcode in scoremap, `Unknown result code ${rcode}`);
    return scoremap[rcode];
}

function getSpacedResultList() {

    const itemlist = getItemList("review_log").filter(item => item.getItemId() == HANZI_ID);
    var spacelist = [];
 
    itemlist.forEach(function(item) {

        const myscore = result2Score(item.getResultCode());

        const evaluation = { 'score' : myscore };
        const previous = spacelist.length == 0 ? getInitSpaceData() : spacelist[spacelist.length-1];

        var nextresult = super2SpacedResult(previous, evaluation);

        nextresult.log_id = item.getId();
        spacelist.push(nextresult);
    });


    return spacelist;
}

/**
 * This is the famous SM-2 algorithm from SuperMemo. It's simple enough to 
 * implement and understand, so a good place to learn about how spaced 
 * repetition algorithms work.
 *
 * See https://www.supermemo.com/en/archives1990-2015/english/ol/sm2
 */
function super2SpacedResult(previous, evaluation) {
    var n, efactor, interval

    massert(previous != null, "You must supply a non-null previous record");

    efactor = Math.max(1.3, previous.efactor + (0.1 - (5 - evaluation.score) * (0.08+(5 - evaluation.score)*0.02)))

    if (evaluation.score < 3) {
        n = 0
        interval = 1
    } else {
        n = previous.n + 1

        if (previous.n == 0) {
            interval = 1
        } else if (previous.n == 1) {
            interval = 6
        } else {
            interval = Math.ceil(previous.interval * efactor)
        }
    }

    interval = Math.min(interval, 200);

    return {n, efactor, interval}
}

function getInitSpaceData() {
    return { n: 0, efactor: 2.5, interval: 0.0, last_review: null };
}

function bounce2Id()
{

    const newid = prompt("Enter new Hanzi ID : ");

    if(newid) {
        HANZI_ID = newid;
        redisplay();
    }
}

// This is the big computation!!
// Return map : id -> SRS data block for all characters
function buildSpaceReadyData() {

    const spacedata = {};

    getItemList("palace_item").forEach(function(pitem) {
        // Do we need to augment this...?
        spacedata[pitem.getId()] = getInitSpaceData();
    });

    console.log(`Have ${Object.keys(spacedata).length} items`);

    const logrecords = getItemList("review_log").sort(proxySort(item => [item.getTimeStamp()]));

    logrecords.forEach(function(record) {

        if(!(record.getItemId() in spacedata)) {
            return;
        }

        const logdate = lookupDayCode(record.getTimeStamp().substring(0, 10));

        // Guaranteed not-null because of init 
        const prev = spacedata[record.getItemId()];

        const evaluation = { 'score' : result2Score(record.getResultCode()) };

        const updated = super2SpacedResult(prev, evaluation);

        updated.last_review = logdate;

        spacedata[record.getItemId()] = updated;

    });

    return spacedata;
}

function getReadyCardTable() {

    var tablestr = `

        <h2>Ready Cards</h2>


        <br/>
        <br/>


        <table class="basic-table" width="60%">
        <tr>
        <th>Character</th>
        <th>LastCheck</th>
        <th>Interval</th>
        <th>Streak</th>
        <th>EFactor</th>
        <th>Interval</th>        
        </tr>
    `;

    const spacedata = buildSpaceReadyData();

    var countready = 1;

    for(const palaceid in spacedata) {

        const spacestat = spacedata[palaceid];
        const palitem = lookupItem("palace_item", palaceid);

        const lastrev = spacestat.last_review;
        const nextrev = lastrev == null ? getTodayCode() : lastrev.nDaysAfter(spacestat.interval);

        // console.log("Hanzi ID is : " + hid);

        if(nextrev.getDateString() > getTodayCode().getDateString()) {
            continue;
        }

        const rowstr = `
            <tr>
            <td>${countready}</td>
            <td>${palitem.getHanziChar()}</td>
            <td>${lastrev == null ? "never" : lastrev.getDateString()}</td>
            <td>${spacestat.interval}</td>
            <td>${nextrev.getDateString()}</td>            
            <td>${spacestat.n}</td>
            <td>${spacestat.efactor.toFixed(2)}</td>
            </tr>
        `;

        tablestr += rowstr;

        countready += 1;
    }

    tablestr += "</table> <br/><br/>";

    return tablestr;
}

function getStudyInfo() {

    const hzitem = lookupItem("hanzi_data", HANZI_ID);

    var tablestr = `

        <font size="60">${hzitem.getHanziChar()}</font>

        <br/>
        <br/>

        <a href="javascript:bounce2Id()"><button>go2id</button></a>

        <br/>
        <br/>


        <table class="basic-table" width="60%">
        <tr>
        <th>TimeStamp</th>
        <th>Result</th>
        <th>Streak</th>
        <th>EFactor</th>
        <th>Interval</th>        
        <th>Next</th>        
        </tr>

    `
    const spacelist = getSpacedResultList();

    spacelist.forEach(function(sitem) {

        const logitem = lookupItem("review_log", sitem.log_id);

        const logdate = lookupDayCode(logitem.getTimeStamp().substring(0, 10));

        const nextdate = logdate.nDaysAfter(sitem.interval);

        const rowstr = `
            <tr>
            <td>${logitem.getTimeStamp()}</td>
            <td>${logitem.getResultCode()}</td>
            <td>${sitem.n}</td>            
            <td>${sitem.efactor.toFixed(2)}</td>
            <td>${sitem.interval}</td>
            <td>${nextdate.getDateString()}</td>            
            </tr>
        `;

        tablestr += rowstr;
    });

    tablestr += "</table>";

    return tablestr;
}


</script>




</head>

<body onLoad="javascript:redisplay()">

<center>

<div id="ready_card"></div>


<h2>Spacing Result</h2>

<br/>

<div id="studyinfo"></div>


</center>
</body>
</html>
