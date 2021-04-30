
<%@include file="../../admin/AuthInclude.jsp_inc" %>


<html>
<head>
<title>Character Learning Schedule</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<script src="ChineseTech.js"></script>

<%= DataServer.basicIncludeOnly(request, "palace_item", "hanzi_data", "learning_schedule") %>

<script>

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

function redisplay()
{
    populateSpanData({
        "nowtable" : generateTableInfo(true),
        "futuretable" : generateTableInfo(false)
    })
}



</script>




</head>

<body onLoad="javascript:redisplay()">

<center>

<br/>

<h3>Learn Now!!</h3>

<h4>Behind by <span id="num_behind"></span></h4>

<div id="nowtable"></div>


<br/>
<br/>

<h3>Future Target</h3>

<div id="futuretable"></div>



</center>
</body>
</html>
