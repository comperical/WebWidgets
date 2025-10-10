
<html>
<head>
<title>&#x1F305 &#x2600</title>

<wisp view_prefixes="recent"/>

<style>



  .flat-button-small {
    background-color: SlateBlue; /* Dark blue */
    color: white;
    border: none;
    border-radius: 4px;
    padding: 6px 12px;
    font-size: 14px;
    cursor: pointer;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    transition: box-shadow 0.3s ease, transform 0.2s ease;
  }

</style>


<script>

const CLOCK_EMOJI = "&#128368;&#65039;";

function deleteItem(killid)
{
    W.lookupItem("mroutine_log", killid).deleteItem();
    redisplay();
}

function getLogHash()
{
    // Map of Phase ID :: last daycode update
    const logmap = {};
    const loglist = W.getItemList("mroutine_log");
    loglist.sort(U.proxySort(a => [a.getLogTimePst()]));
    
    loglist.forEach(function(mrlog) {
        var dc = mrlog.getLogTimePst().split(" ")[0];
        logmap[mrlog.getPhaseId()] = dc;
    });
    
    return logmap;
}

function getActivePhase()
{
    // Active Phase is the lowest ORDER KEY phase with no log item for the given day.
    var logmap = getLogHash();
    var phaselist = W.getItemList("mroutine_phase").filter(mrp => mrp.getIsActive() == 1);
    
    phaselist.sort(U.proxySort(a => [a.getOrderKey()]));
    const todayOfWeek = U.getTodayCode().getShortDayOfWeek();

    for(var pi in phaselist)
    {
        var phs = phaselist[pi];
        const lastup = logmap[phs.getId()];
        
        // If this phase does not display on today's day of week, skip.
        const showdays = getDayList4Item(phs);
        if(!showdays.includes(todayOfWeek))
            { continue; }

        if(lastup != U.getTodayCode().dateString)
            { return phs; }
    }
    
    return null;
}

function markDone()
{
    var actphase = getActivePhase();
    
    if(actphase == null)
    {
        alert("Morning Routine complete");
        return; 
    }
    
    const ltpst = exactMomentNow().asIsoLongBasic(MY_TIME_ZONE);
    const comrecord = {
        "phase_id" : actphase.getId(),
        "log_time_pst" : ltpst
    };
    
    const newitem = W.buildItem("mroutine_log", comrecord);
    newitem.syncItem();
    redisplay();
    
}

function isTodayLog(mrlog)
{
    return mrlog.getLogTimePst().split(" ")[0] == U.getTodayCode().dateString;
    
}

function getDayList4Item(phaseitem)
{
    const daystr = phaseitem.getOnDayList();

    if(daystr == "" || daystr == "all")
        { return [... SHORT_DAY_WEEK_LIST]; }

    return daystr.split(",");
}


function handleNavBar() {

	const headerinfo = [
        ["Morning Routine", "widget.wisp"],
        ["Phases", "MroutineList.wisp"]
    ];

    populateTopNavBar(headerinfo, "Morning Routine");
}


function redisplay()
{
	handleNavBar();

    // activephase = null impliies we're done with the day
    const activephase = getActivePhase();
    var activetext = "complete";
    var activelink = "";
    
    if(activephase != null)
    {
        activetext = activephase.getShortName();
        activelink = `<a href="${activephase.getWebLink()}"><button class="flat-button-small">LINK</button></a>`
    }

    var mtstr = `
        <h3>${activetext}</h3>
        ${activelink}
        <br/>
        <br/>
    `;

    if(activephase != null) {

        mtstr += `
            <a href="javascript:markDone()" class="css3button">done</a>
            <br/>
            <br/>
        `;
    }

    mtstr += `

        <table  class="basic-table" width="30%">
        <tr>
        <th>Name</th>
        <th>${CLOCK_EMOJI}</th>
        <th>...</th>
        </tr>
    `;


    var complist = W.getItemList("mroutine_log").filter(mrlog => isTodayLog(mrlog));
    complist.sort(U.proxySort(a => [a.getLogTimePst])).reverse()
    
    complist.forEach(function(logitem) {

        const cphase = W.lookupItem("mroutine_phase", logitem.getPhaseId());
        const tstamp = logitem.getLogTimePst().split(" ")[1].substring(0, 5);
        const itemrow = `
            <tr>
            <td>${cphase.getShortName()}</td>
            <td>${tstamp}</td>
            <td>
            <a href="javascript:deleteItem(${logitem.getId()})">
            <img src="/u/shared/image/remove.png" height="18"></a>
            </td>
            </tr>
        `;
        
        mtstr += itemrow;
    });
        
    mtstr += "</table>";
    
    U.populateSpanData({ "mainpage" : mtstr });
}




</script>

</head>

<body onLoad="javascript:redisplay()">


<center>

<div class="topnav"></div>

<br/>

<div id="mainpage"></div>

<br/>


</center>
</body>
</html>
