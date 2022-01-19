
<html>
<head>
<title>Morning Routine</title>

<%= DataServer.basicInclude(request)  %>


<script>

function deleteItem(killid)
{
    lookupItem("mroutine_log", killid).deleteItem();
    redisplay();
}

function getLogMap()
{
    // Map of Phase ID :: last daycode update   
    var logmap = {};
    var loglist = getItemList("mroutine_log");
    loglist.sort(proxySort(a => [a.getLogTimePst()]));
    
    loglist.forEach(function(mrlog) {   
        var dc = mrlog.getLogTimePst().split(" ")[0];
        logmap[mrlog.getPhaseId()] = dc;
    });
    
    return logmap;
}

function getActivePhase()
{
    // Active Phase is the lowest ORDER KEY phase with no log item for the given day.
    var logmap = getLogMap();
    var phaselist = getItemList("mroutine_phase").filter(mrp => mrp.getIsActive() == 1);
    
    phaselist.sort(proxySort(a => [a.getOrderKey()]));
    const todayOfWeek = getTodayCode().getShortDayOfWeek();

    for(var pi in phaselist)
    {
        var phs = phaselist[pi];
        const lastup = logmap[phs.getId()];
        
        // If this phase does not display on today's day of week, skip.
        const showdays = getDayList4Item(phs);
        if(!showdays.includes(todayOfWeek))
            { continue; }

        if(lastup != getTodayCode().dateString)
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
    
    const newid = newBasicId("mroutine_log");
    const ltpst = calcFullLogTimeStr(new Date());   
    const comrecord = {
        "id" : newid,
        "phase_id" : actphase.getId(),
        "log_time_pst" : ltpst
    };
    
    const newitem = buildItem("mroutine_log", comrecord);
    newitem.syncItem();
    redisplay();    
    
}

function isTodayLog(mrlog)
{
    return mrlog.getLogTimePst().split(" ")[0] == getTodayCode().dateString;    
    
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
        ["Morning Routine", "widget.jsp"],
        ["Phases", "MroutineList.jsp"]
    ];

    populateTopNavBar(headerinfo, "Morning Routine");
}


function redisplay()
{
	handleNavBar();

    var mtstr = `
        <table  class="basic-table" width="30%">
        <tr>
        <th>Name</th>
        <th>LogTime</th>
        <th>...</th>
        </tr>
    `;


    var complist = getItemList("mroutine_log").filter(mrlog => isTodayLog(mrlog));
    complist.sort(proxySort(a => [a.getLogTimePst])).reverse()
    
    complist.forEach(function(logitem) {

        const cphase = lookupItem("mroutine_phase", logitem.getPhaseId());
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
    
    document.getElementById("logtable").innerHTML = mtstr;
    
    
    {
        const activephase = getActivePhase();
        var activetext = "complete";
        var activelink = "";
        
        if(activephase != null)
        {
            activetext = activephase.getShortName();
            activelink = `<a href="${activephase.getWebLink()}">LINK</a>`
        }
        
        const spandata = {
            "activephase" : activetext,
            "web_link" : activelink
        };
        
        populateSpanData(spandata);
    }
}




</script>

</head>

<body onLoad="javascript:redisplay()">


<center>

<div class="topnav"></div>

<br/>

<h3><div id="activephase">complete</div></h3>

<div id="web_link"></div>

<br/>

<a href="javascript:markDone()" class="css3button">done</a>

<br/><br/>

<div id="logtable"></div>


<br/>


</center>
</body>
</html>
