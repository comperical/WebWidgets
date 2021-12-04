
<%@include file="../../admin/AuthInclude.jsp_inc" %>


<html>
<head>
<title>Character Learning Schedule</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<script src="ChineseTech.js"></script>

<%= DataServer.include(request, "tables=palace_item,hanzi_data,learning_schedule,word_memory") %>

<script>

// Get the Hanzi characters that are in words in the vocab log but not currently in the character study system.
function getVocabRequiredItems()
{
    const palaceset = new Set([getItemList("palace_item").map(item => item.getHanziChar())]);
    console.log(palaceset);

    const requiredset = new Set();

    getItemList("word_memory").forEach(function(worditem) {

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

    getItemList("word_memory").forEach(function(worditem) {

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
    const schedlist = getItemList("learning_schedule");
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
        <th>#Vocab</th>
        <th>HSK Level</th>
        <th>Freq Rank</th>        
        </tr>
    `;

    const vocabcount = getVocabCharCountMap();

    getItemList("hanzi_data").forEach(charitem => {

        const thechar = charitem.getHanziChar();

        const palace = lookupPalaceItemByChar(thechar);

        // Already have a palace entry
        if(palace != null) 
            { return; }

        // Wrong level
        if(charitem.getHskLevel() != 5)
            { return; }

        // Don't have any vocab entries
        if(!(thechar in vocabcount)) 
            { return; }

        const rowstr = `
            <tr>
            <td>${thechar}</td>
            <td>${charitem.getPinYin()}</td>            
            <td>${vocabcount[thechar]}</td>
            <td>${charitem.getHskLevel()}</td>
            <td>${charitem.getFreqRank()}</td>
            </tr>
        `;

        tablestr += rowstr;
    });

    /*
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
    */

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

<br/>


<h3>Learn Now!!</h3>

<div id="nowtable"></div>


<br/>
<div id="vocabtable"></div>


<br/>

</center>
</body>
</html>
