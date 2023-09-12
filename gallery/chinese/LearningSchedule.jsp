

<html>
<head>
<title>Character Learning Schedule</title>

<%= DataServer.include(request, "tables=palace_item,hanzi_data,learning_schedule,word_memory") %>

<script>

function handleNavBar() 
{
    populateTopNavBar(getPlanningHeader(), "Learning Schedule");
}

function addPalaceItem(charid)
{

    const charitem = W.lookupItem("hanzi_data", charid);

    // <td>${charitem.getHanziChar()}</td>
    // <td>${charitem.getPinYin()}</td>

    const mssg = `
        Going to add a palace item for ${charitem.getHanziChar()}

        Character will disappear from this screen, but will be present in character list

        Okay to proceed?
    `;

    if(confirm(mssg))
    {
        const newrec = {
            "hanzi_char" : charitem.getHanziChar(),
            "palace_note": "NotYetSet",
            "extra_note" : "...",
            "is_active" : 1,
            "extension" : "",
            "meaning": charitem.getDefinition()
        };      
        
        clearHanziDataCache();

        const newitem = W.buildItem("palace_item", newrec);
        newitem.syncItem();
        redisplay();
    }
}



// Get the Hanzi characters that are in words in the vocab log but not currently in the character study system.
function getVocabRequiredItems()
{
    const palaceset = new Set([W.getItemList("palace_item").map(item => item.getHanziChar())]);

    const requiredset = new Set();

    W.getItemList("word_memory").forEach(function(worditem) {

        if(worditem.getIsActive() == 0)
            { return; }

        const hanzistr = worditem.getSimpHanzi();
        for(var idx = 0; idx < hanzistr.length; idx++)
        { 
            const thechar = hanzistr[idx];
            const palitem = lookupPalaceItemByChar(thechar);
            if(palitem != null) 
                { continue; }

            const charitem = lookupHanziDataByChar(thechar);
            if(charitem == null) 
            {
                // So many Chinese characters that some of the characters in vocabulary are not in the main 
                // character DB!! For purposes of this widget, it is not a problem, you can just skip them
                console.log(`Character ${thechar} from vocab item ${hanzistr} not found in character DB`);
                continue;
            }


            if(charitem.getHskLevel() == 1 || charitem.getHskLevel() == -1)
                { continue; }

            if(charitem.getFreqRank() > 2000) 
                { continue; }

            requiredset.add(thechar);
        }
    });

    return requiredset;
}

// Map of character to count in Vocab data. 0 counts not present.
function getVocabCharCountMap() 
{
    const counts = {};

    W.getItemList("word_memory").forEach(function(worditem) {

        if(worditem.getIsActive() == 0)
            { return; }

        const hanzistr = worditem.getSimpHanzi();
        for(var idx = 0; idx < hanzistr.length; idx++)
        { 
            const thechar = hanzistr[idx];
            if (!(thechar in counts)) 
                { counts[thechar] = 0; }

            counts[thechar] += 1;
        }
    });

    return counts;
}


function getRemainingCount() 
{
    var numshow = 0;
    const schedlist = W.getItemList("learning_schedule");
    const today = getTodayCode().getDateString();

    schedlist.forEach(function(scheditem) {

        const palitem = lookupPalaceItemByChar(scheditem.getTheChar());
        if(palitem != null) 
            { return; }

        const target = scheditem.getDayCode();
        const isbefore = target <= today;

        if(isbefore)
            { return; }

        numshow += 1;

    });

    return numshow;
}

function generateVocabTableInfo()
{

    const reqdlist = getVocabRequiredItems();

    if(reqdlist.size == 0)
        { return; }


    var tablestr = `
        <h4>Vocab Items</h4>

        Have ${reqdlist.size} required for Vocab

        <table  class="basic-table" width="60%">
        <tr>
        <th>Character</th>
        <th>PinYin</th>
        <th>HSK Level</th>
        <th>Requested</th>
        <th>Freq Rank</th>
        </tr>
    `;


    reqdlist.forEach(function(thechar) {

        const charitem = lookupHanziDataByChar(thechar);

        const rowstr = `
            <tr>
            <td>${charitem.getHanziChar()}</td>
            <td>${charitem.getPinYin()}</td>
            <td>${charitem.getHskLevel()}</td>
            <td>${charitem.getIsRequested()}</td>
            <td>${charitem.getFreqRank()}</td>
            </tr>
        `;

        tablestr += rowstr;
    });




    tablestr += "</table>";
    return tablestr;
}



function generateTableInfo()
{

    var numshow = 0;

    var tablestr = `
        <table  class="basic-table" width="60%">
        <tr>
        <th>Character</th>
        <th>PinYin</th>
        <th>#Vocab / Req'd</th>
        <th>HSK Level</th>
        <th>Freq Rank</th>   
        <th>...</th>
        </tr>
    `;

    const vocabcount = getVocabCharCountMap();

    function getVc(charitem) {
        const thechar = charitem.getHanziChar();
        return (thechar in vocabcount) ? vocabcount[thechar] : 0;
    }

    const sortlist = W.getItemList("hanzi_data").sort(proxySort(charitem => [-charitem.getIsRequested(), -getVc(charitem)]));
    sortlist.forEach(charitem => {

        const thechar = charitem.getHanziChar();

        const palace = lookupPalaceItemByChar(thechar);

        // Already have a palace entry
        if(palace != null) 
            { return; }

        // Wrong level
        if(charitem.getHskLevel() != 5)
            { return; }

        // Don't have any vocab entries
        // if(!(thechar in vocabcount)) 
        //    { return; }

        const thecount = (thechar in vocabcount ? vocabcount[thechar] : 0);

        const rowstr = `
            <tr>
            <td>${thechar}</td>
            <td>${charitem.getPinYin()}</td>            
            <td>${thecount}/ ${charitem.getIsRequested()}</td>
            <td>${charitem.getHskLevel()}</td>
            <td>${charitem.getFreqRank()}</td>
            <td>

            <a href="javascript:addPalaceItem(${charitem.getId()})"><img src="/u/shared/image/add.png" height="18"/></a>

            </td>            
            </tr>
        `;

        tablestr += rowstr;
    });


    tablestr += `</table>`;

    return tablestr;
}

/*
function generateTableInfo(wantbefore)
{

    var numshow = 0;

    var tablestr = `
        <table  class="basic-table" width="60%">
        <tr>
        <th>TargetDate</th>
        <th>Character</th>
        <th>PinYin</th>
        <th>HSK Level</th>
        <th>Freq Rank</th>
        <th>...</th>
        </tr>
    `;

    const today = getTodayCode().getDateString();
    const schedlist = getItemList("learning_schedule");

    schedlist.forEach(function(scheditem) {

        const palitem = lookupPalaceItemByChar(scheditem.getTheChar());
        if(palitem != null) 
            { return; }

        const charitem = lookupHanziDataByChar(scheditem.getTheChar());

        const target = scheditem.getDayCode();
        const isbefore = target <= today;

        if(isbefore != wantbefore)
            { return; }

        const rowstr = `
            <tr>
            <td>${target}</td>
            <td>${charitem.getHanziChar()}</td>
            <td>${charitem.getPinYin()}</td>
            <td>${charitem.getHskLevel()}</td>
            <td>${charitem.getFreqRank()}</td>
            <td></td>
            </tr>
        `;

        tablestr += rowstr;
        numshow += 1;

    });

    /// this is a hack!!
    if(wantbefore) 
        { populateSpanData({"num_behind" : numshow }); }

    tablestr += `</table>`;

    return tablestr;
}
*/


function redisplay()
{
    handleNavBar();

    const total = getRemainingCount();

    populateSpanData({
        "vocabtable" : generateVocabTableInfo(),
        "nowtable" : generateTableInfo()
    })
}



</script>




</head>

<body onLoad="javascript:redisplay()">

<center>

<div class="topnav"></div>

<br/>
<br/>

<div id="nowtable"></div>


<br/>
<div id="vocabtable"></div>


<br/>

</center>
</body>
</html>
