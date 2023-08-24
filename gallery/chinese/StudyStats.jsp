

<html>
<head>
<title>Character Learning Schedule</title>

<%= DataServer.basicIncludeOnly(request, "palace_item", "hanzi_data", "learning_schedule", "word_memory", "review_log", "vocab_log") %>

<script>

const LEVEL_LIST = [1, 2, 3, 4, 5, 6];

const NUM_CHAR_LIST = [1, 2, 3, 4, 5];

function handleNavBar() 
{
    populateTopNavBar(getPlanningHeader(), "Study Stats");
}



function getVocabStatInfo()
{

    const statmap = {};

    NUM_CHAR_LIST.concat([-1]).forEach(function(level) {
        statmap[level] = {
            "numword" : 0,
            "numreview" : 0
        };
    });

    getItemList("word_memory").forEach(function(item) {
        const numchar = item.getSimpHanzi().length;
        statmap[numchar]["numword"] += 1;
        statmap[-1]["numword"] += 1;
    });

    getItemList("vocab_log").forEach(function(item) {

        const worditem = lookupItem("word_memory", item.getItemId());
        if (worditem == null) 
            {return; }

        const numchar = worditem.getSimpHanzi().length;
        statmap[numchar]["numreview"] += 1;
        statmap[-1]["numreview"] += 1;
    });



    return statmap;

}

function getStatInfo()
{

    const statmap = {};

    LEVEL_LIST.concat([-1]).forEach(function(level) {
        statmap[level] = {
            "numstory" : 0,
            "numreview" : 0,
            "nummissing" : 0
        };
    });

    const storyset = new Set(getItemList("palace_item").map(item => lookupHanziDataByChar(item.getHanziChar()).getId()));
    // console.log(`SList size is ${storyset.size()}`);

    getItemList("hanzi_data").forEach(function(hzitem) {

        // const hzitem = lookupHanziDataByChar(item.getHanziChar());
        const hsklevel = hzitem.getHskLevel();

        if (hsklevel == -1) 
            { return; }

        const missing = hsklevel == 1 || storyset.has(hzitem.getId());

        const addkey = missing ? "numstory" : "nummissing";

        [-1, hsklevel].forEach(function(psitem) {

            const statitem = statmap[psitem];

            if(statitem == null) 
                { return; }

            statitem[addkey] += 1;
        });


    });



    getItemList("review_log").forEach(function(revitem) {

        const palitem = lookupItem("palace_item", revitem.getItemId());

        const hzitem = lookupHanziDataByChar(palitem.getHanziChar());

        // const hzitem = lookupHanziDataByChar(item.getHanziChar());
        const hsklevel = hzitem.getHskLevel();

        if (hsklevel == -1) 
            { return; }

        statmap[hsklevel]["numreview"] += 1;
        statmap[-1]["numreview"] += 1;


    });


    return statmap;
}


function getDisplayPage()
{

    const pstats = getStatInfo();

    var pagestr = `
        <table class="basic-table" width="50%">
        <tr>
        <th>HSK Level</th>
        <th>#Stories</th>
        <th>#Missing</th>
        <th>#Review</th>
        <th>Rev/Char</th>
        </tr>
    `;

    LEVEL_LIST.forEach(function(level) {

        const statitem = pstats[level];

        const revperchar = statitem["numreview"] / statitem["numstory"];

        const rowstr = `
            <tr>
            <td>${level}</td>
            <td>${statitem["numstory"]}</td>
            <td>${statitem["nummissing"]}</td>
            <td>${statitem["numreview"]}</td>
            <td>${revperchar.toFixed(1)}</td>
            </tr>
        `;

        pagestr += rowstr;
    });

    {
        const statitem = pstats[-1];
        const revperchar = statitem["numreview"] / statitem["numstory"];

        const rowstr = `
            <tr>
            <td><b>Total</b></td>
            <td>${statitem["numstory"]}</td>
            <td>${statitem["nummissing"]}</td>
            <td>${statitem["numreview"]}</td>
            <td>${revperchar.toFixed(1)}</td>            
            </tr>
        `;

        pagestr += rowstr;
    }

    const vocabmap = getVocabStatInfo();

    pagestr += `</table>

        <h4>Words</h4>

        <br/>

        <table class="basic-table" width="30%">
        <tr>
        <th>#Chars</th>
        <th>#Words</th>
        <th>#Review</th>
        <th>Rev/Word</th>
        </tr>
    `;

    NUM_CHAR_LIST.forEach(function(level) {

        const statitem = vocabmap[level];

        if(statitem["numword"] == 0) 
            { return; }

        const revperword = statitem["numreview"] / statitem["numword"];

        const rowstr = `
            <tr>
            <td>${level}</td>
            <td>${statitem["numword"]}</td>
            <td>${statitem["numreview"]}</td>   
            <td>${revperword.toFixed(1)}</td>         
            </tr>
        `;

        pagestr += rowstr;
    });    

    {
        const statitem = vocabmap[-1];
        const revperword = statitem["numreview"] / statitem["numword"];

        const rowstr = `
            <tr>
            <td><b>Total</b></td>
            <td>${statitem["numword"]}</td>
            <td>${statitem["numreview"]}</td>
            <td>${revperword.toFixed(1)}</td>            
            </tr>
        `;

        pagestr += rowstr;
    }


    pagestr += "</table>";

    return pagestr;


}

function redisplay()
{
    handleNavBar();

    const pagestr = getDisplayPage();

    populateSpanData({"mainpage" : pagestr });
}



</script>




</head>

<body onLoad="javascript:redisplay()">

<center>

<div class="topnav"></div>

<br/>


<h3>Study Stats</h3>


<div id="mainpage"></div>



</center>
</body>
</html>
