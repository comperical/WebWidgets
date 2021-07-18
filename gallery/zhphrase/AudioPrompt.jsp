
<%@include file="../../admin/AuthInclude.jsp_inc" %>


<html>
<head>

<title>Audio Phrase Study</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<script src="../chinese/ChineseTech.js"></script>

<%= DataServer.basicInclude(request) %>

<script>

RECENT_ANSWER = null;

// Toggle this to flip between prompt and response
IS_PROMPT = true;

CURRENT_PROMPT_ITEM = computePromptItem();

function submitResponse()
{
    RECENT_ANSWER = getDocFormValue("user_response");

    redisplay();
}

function computePhraseStatInfo()
{
    return computeStatInfoSub("short_phrase", "zh_phr_rev_log");  
}

function markResult(resultcode)
{   
    const timestamp = calcFullLogTimeStr(new Date());
    const newrec = {
        "study_code" : "zh_phrase",
        "item_id" : CURRENT_PROMPT_ITEM.getId(),
        "result_code" : resultcode,
        "time_stamp" : timestamp,
        "extra_info" : ""
    };
    
    const newitem = buildItem("zh_phr_rev_log", newrec);
    newitem.registerNSync();
    
    // clear recent answer
    RECENT_ANSWER = null;

    CURRENT_PROMPT_ITEM = computePromptItem();
    redisplay();    
}


function repeatPrompt()
{
    RECENT_ANSWER = null;

    redisplay();
}

// TODO: this code is replicated in StudyPrompt, other places
function getRecentPromptIdSet() 
{
    var items = getItemList("zh_phr_rev_log").sort(proxySort(itm => [itm.getId()])).reverse();
    var recentlist = [];
    
    items.forEach(function(itm) {
    
        if(recentlist.length > 50)
            { return; }
        
        recentlist.push(itm.getItemId());
    });
    
    return recentlist;  
}


// TODO: this code is replicated in StudyPrompt.jsp
function computePromptItem()
{
    // Okay this is the computation of the item with the lowest score
    const statinfo = computePhraseStatInfo();
    const recentids = getRecentPromptIdSet();

    // GOD DAMMIT JAVASCRIPT
    var okayids = Object.keys(statinfo).filter(charid => recentids.indexOf(parseInt(charid)) == -1);
    // console.log(okayids);

    if(okayids.length == 0) {
        // corner case where you studied all the IDs recently
        // This really just means you should add more records
        okayids = Object.keys(statinfo);
    }

    const lowestid = minWithProxy(okayids, it => statinfo[it]["net_score"]);
    return lookupItem("short_phrase", lowestid);
}


function redisplay()
{
    const curitem = CURRENT_PROMPT_ITEM;

    const prompt = curitem.getSimpHanzi();

    var mainstr = "";

    const pystr = curitem.getPinYin();

    const engstr = curitem.getEnglish();

    if(RECENT_ANSWER == null) 
    {
        mainstr = `

            <br/>

            <h2>${prompt}</h2>

            <h4>${pystr}</h4>

            <h4>${engstr}</h4>

            <input type="text" size="50" name="user_response"/>

            <br/><br/>

            <a href="javascript:submitResponse()"><button>submit</button></a>
        `;

    } else {

        mainstr = `

            <br/>
            <br/>

            <table width="40%" class="basic-table">
            <tr>
            <td>prompt</td>
            <td>${prompt}</td>
            </tr>
            <tr>
            <td>response</td>
            <td>${RECENT_ANSWER}</td>
            </tr>
            </table>

            <br/>
            <br/>

            <a href="javascript:repeatPrompt()"><button>repeat</button></a>

            <br/>
            <br/>



            <a href="javascript:markResult('good')"><button>good</button></a>

            &nbsp;
            &nbsp;
            &nbsp;

            <a href="javascript:markResult('bad')"><button>bad</button></a>


        `;
    }




    populateSpanData({ "maindata" : mainstr });
    
}




</script>




</head>

<body onLoad="javascript:redisplay()">

<center>

<h2>Pronounciation Drill</h2>


<center>

<span id="maindata"></span>

<br/>
<br/>

</center>
</body>
</html>
