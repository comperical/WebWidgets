
<%@include file="../../admin/AuthInclude.jsp_inc" %>

<html>
<head>
<title>SampleTime</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

<%= DataServer.includeIfAvailable(request, "sms_box", "outbox") %>

<script>

var EDIT_STUDY_ITEM = -1;


// Return 2-element array of start/end time in millis for valid sample send times.
function getAlphaOmegaWindow(daycode)
{
    const alphastr = daycode.getDateString() + " 08:00:00";
    const omegastr = daycode.getDateString() + " 23:00:00";

    const alphamilli = exactMomentFromIsoBasic(alphastr, "PST").getEpochTimeMilli();
    const omegamilli = exactMomentFromIsoBasic(omegastr, "PST").getEpochTimeMilli();

    return [alphamilli, omegamilli];
}

// Given the window, return a UTC timestamp randomly chosen within that window.
// Note!!! window is reserved JavaScript keyword!!!
function getRandomUtcInWindow(milliwin)
{
    const delta = milliwin[1] - milliwin[0];
    const milli = milliwin[0] + Math.floor(Math.random() * delta);
    // console.log("Milliwin is " + milliwin  + ", selected " + milli);

    return new ExactMoment(milli).asIsoLongBasic("UTC");
}

function getRecentHistoryMap()
{
    const histmap = {};

    const cutoff = getTodayCode().nDaysBefore(30).getDateString();

    const itemlist = getItemList("samples").sort(proxySort(samp => [readyAtForSample(samp)]));

    itemlist.forEach(function(samp) {

        const sdc = samp.getDayCode();

        if(sdc < cutoff)
            { return; }

        if(!(sdc in histmap)) {
            histmap[samp.getDayCode()] = [];
        }

        histmap[samp.getDayCode()].push(samp);
    });

    return histmap;
}


function newBatch()
{

    const daycode = getTodayCode().dayAfter();

    if(!confirm("Okay to create a new batch of time samples for tomorrow, " + daycode.getDateString() + "?"))
        { return; }

    const milliwin = getAlphaOmegaWindow(daycode);

    for(var idx = 0; idx < 5; idx++)
    {
        const readyat = getRandomUtcInWindow(milliwin);

        const readymilli = exactMomentFromIsoBasic(readyat, "UTC").getEpochTimeMilli();
        const readypst = new ExactMoment(readymilli).asIsoLongBasic("PST").substring("2021-01-01 ".length);

        // console.log("Random ready-at: " + readyat + " UTC");

        const probeid = newBasicId("samples");
        const outboxid = newBasicId("outbox");

        const logurl = "https://danburfoot.net/u/dburfoot/sampletime/LogSample.jsp?id=" + probeid;

        const smsmssg = `SampleTime for ${readypst} PST: ${logurl}`;
        
        const proberec = {
            "id" : probeid,
            "outbox_id" : outboxid,
            "notes" : "", 
            "category" : "",
            "day_code" : daycode.getDateString()
        }

        const smsrec = {
            "id" : outboxid,
            "message" : smsmssg,
            "ready_at_utc" : readyat,
            "sent_at_utc" : ""
        }
        
        const probeitem = buildItem("samples", proberec);
        probeitem.registerNSync();

        const smsitem = buildItem("outbox", smsrec);
        smsitem.registerNSync();
    }

    redisplay();
}

function deleteItem(killid)
{
    const victim = lookupItem("samples", killid);

    const smsvictim = lookupItem("outbox", victim.getOutboxId());

    if(confirm("Are you sure you want to delete this item?"))
    {
        victim.deleteItem();

        if(smsvictim != null && smsvictim.getSentAtUtc().length == 0)
        {
            smsvictim.deleteItem();
            // alert("Also deleted SMS outbox record");
        }
    }

    redisplay();


}

function editStudyItem(itemid) 
{
    EDIT_STUDY_ITEM = itemid;
    redisplay();
}

function editShortName()
{
    genericEditTextField("rage_log", "short_name", EDIT_STUDY_ITEM);
}

function back2Main()
{
    EDIT_STUDY_ITEM = -1;
    redisplay();
}


function redisplay()
{
    redisplayMainTable();

    redisplayHistoryTable();

    setPageComponent(getPageComponent());
}

function getPageComponent()
{
    return EDIT_STUDY_ITEM == -1 ? "maintable_cmp" : "edit_item";
}

function readyAtForSample(sampitem)
{
    const smsitem = lookupItem("outbox", sampitem.getOutboxId());
    return smsitem == null  ? "---" : smsitem.getReadyAtUtc();
}


function redisplayMainTable()
{

    const historymap = getRecentHistoryMap();

    const tmrwlist = historymap[getTodayCode().dayAfter().getDateString()];

    if(tmrwlist == null || tmrwlist.length == 0)
    {
        const empty = `
            <h3>No probes scheduled for tomorrow</h3>
            <br/>
            <a class="css3button" onclick="javascript:newBatch()">SCHEDULE</a>
        `;



        populateSpanData({
            "maintable" : empty
        });

        return;
    }


    var tablestr = `

        <h3>Scheduled for Tomorrow</h3>


        <table id="dcb-basic" class="dcb-basic" width="60%">
        <tr>
        <th width="7%">ID</th>
        <th>Ready</th>
        <th>Message</th>        
        <th>Op</th>
        </tr>
    `;
    
    tmrwlist.forEach(function(item) {
                
        // const taglist = tagListFromItem(item).join(", ");
        const smsitem = lookupItem("outbox", item.getOutboxId());

        var sendtime = "???";
        var smsmssg = "???";

        if(smsitem != null)
        {
            const sendmoment = exactMomentFromIsoBasic(smsitem.getReadyAtUtc(), "UTC");

            if(!isNaN(sendmoment.getEpochTimeMilli()))
            {
                // console.log(sendmoment);
                sendtime = sendmoment.asIsoLongBasic("PST").substring("2020-01-01 ".length);                
            }

            smsmssg = smsitem.getMessage();
        }


        const rowstr = `
            <tr>
            <td>${item.getId()}</td> 
            <td>${sendtime}</td>
            <td>${item.getNotes()}</td>             
            <td width="10%">

                <a href="javascript:deleteItem(${item.getId()})">
                <img src="/life/image/remove.png" height=18"/></a>

                &nbsp;
                &nbsp;

                <a href="javascript:editStudyItem(${item.getId()})">
                <img src="/life/image/inspect.png" height=18"/></a>
                
            </td>
            </tr>
        `

        tablestr += rowstr;
    });

    tablestr += "</table>";

    populateSpanData({
        "maintable" : tablestr
    });
}

function redisplayHistoryTable()
{
    const todaydc = getTodayCode().getDateString();
    const historymap = getRecentHistoryMap();

    const daylist = Object.keys(historymap).sort().reverse();


    var bigfatstr = "";
    
    daylist.forEach(function(dcstr) {
                
        if(dcstr > todaydc) {
            return;
        }

        var tablestr = `

            <br/>
            <h3>${dcstr}</h3>

            <table id="dcb-basic" class="dcb-basic" width="80%">
            <tr>
            <th width="7%">ID</th>
            <th width="10%">Scheduled</th>
            <th width="10%">Send Delay</th>
            <th>Message</th>        
            <th>Op</th>
            </tr>
        `;

        const itemlist = historymap[dcstr];
        
        itemlist.forEach(function(item) {
                    
            // const taglist = tagListFromItem(item).join(", ");
            const smsitem = lookupItem("outbox", item.getOutboxId());

            var readytime = "???";
            var sendtime = "???";

            if(smsitem != null)
            {
                const readymoment = exactMomentFromIsoBasic(smsitem.getReadyAtUtc(), "UTC");


                if(!isNaN(readymoment.getEpochTimeMilli()))
                {
                    readytime = readymoment.asIsoLongBasic("PST").substring("2020-01-01 ".length);                

                    if(smsitem.getSentAtUtc().length == 0) 
                    {
                        sendtime = "N/Y/S";

                    } else {
                        // This one should be okay.... it's produced by the Twilio code!!!
                        const sendmoment = exactMomentFromIsoBasic(smsitem.getSentAtUtc(), "UTC");

                        const diffmin = (sendmoment.getEpochTimeMilli() - readymoment.getEpochTimeMilli()) / 1000;
                        sendtime = diffmin.toFixed(0) + " sec";
                    }

                }

            }


            const rowstr = `
                <tr>
                <td>${item.getId()}</td> 
                <td>
                ${readytime}
                </td>
                <td>
                ${sendtime}
                </td> 
                <td>${item.getNotes()}</td>             
                <td width="10%">

                    <a href="javascript:deleteItem(${item.getId()})">
                    <img src="/life/image/remove.png" height=18"/></a>

                    &nbsp;
                    &nbsp;
                    &nbsp;

                    <a href="javascript:editStudyItem(${item.getId()})">
                    <img src="/life/image/inspect.png" height=18"/></a>
                    
                </td>
                </tr>
            `;

            tablestr += rowstr;
        });

        tablestr += "</table>";

        bigfatstr += tablestr;
    });

    populateSpanData({
        "historytable" : bigfatstr
    });

}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<span class="page_component" id="maintable_cmp">

<h2>Time Samples</h2>

<br/>
<br/>

<div id="maintable"></div>

<br/><br/>

<div id="historytable"></div>


<br/>
</span>

<span class="page_component" id="edit_item">

<h3>Edit Item</h3>

<br/>

<table width="50%" id="dcb-basic">
<tr>
<td width="25%">Back</td>
<td></td>
<td width="30%"><a href="javascript:back2Main()"><img src="/life/image/leftarrow.png" height="18"/></a></td>
</tr>
<tr>
<td>Name</td>
<td><div id="short_name"></div></td>
<td><a href="javascript:editShortName()"><img src="/life/image/edit.png" height=18/></a></td>
</tr>
<tr>
<td>Tags</td>
<td><div id="category_list"></div></td>
<td>
<span id="add_tag_sel_span"></span>
</td>
</tr>
<tr>
<td>Date</td>
<td><span id="day_code"></span>
<td></td>
</tr>
</table>

<br/>
<br/>

<table id="dcb-basic" width="30%">
<tr>
<td>
<span id="itemdescline">xxx<br/>yyy</span>
</td>
</tr>
</table>

<br/>
<br/>

<form>
<textarea id="full_desc" name="full_desc" rows="10" cols="50"></textarea>
</form>

<a href="javascript:saveNewDesc()">save desc</a>

</span>


</center>
</body>
</html>
