
<%@include file="../../admin/AuthInclude.jsp_inc" %>

<html>
<head>
<title>Weight Log</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>



<%= DataServer.basicInclude(request) %>

<script>


EFFORT_CODE_MAP = {
    "E" : "Easy",
    "M" : "Medium",
    "H" : "Hard",
    "X" : "Too Hard"
}


// Eventually need to have a separate page for this, but hopefully can get away with this for a while
function createNewMovement()
{
    const newmove = prompt("This will create a new movement / exercise type. Enter the name: ");

    if(newmove)
    {
        const newrec = {
            "short_name" : newmove,
            "extra_info" : "",
            "is_active" : 1
        }

        const newitem = buildItem("movement", newrec);
        newitem.registerNSync();
        redisplay();

        alert("Created new movement!");
    }
}

function lookupRecent(moveid)
{
    const movelist = getItemList("weight_log")
                            .filter(item => item.getMoveId() == moveid)
                            .sort(proxySort(item => [item.getDayCode()])).reverse();

    return movelist.length > 0 ? movelist[0] : null;
}

function logNewMove()
{
    const daycode = getDocFormValue("day_code_sel");

    const moveid = parseInt(getDocFormValue("move_select"));
        
    const clonefrom = lookupRecent(moveid);

    // created_on, active_on, completed_on, dead_line
    const newrec = {
        "move_id" : moveid,
        "rep_info": clonefrom == null ? 4 : clonefrom.getRepInfo(),
        "weight" : clonefrom == null ? 135 : clonefrom.getWeight(),
        "effort" : clonefrom == null ? "M" : clonefrom.getEffort(),
        "notes" : "",
        "day_code" : daycode      
    };      
    
    const newitem = buildItem("weight_log", newrec);
    newitem.registerNSync();
    redisplay();
}

function editEffortLevel(itemid) 
{
    const item = lookupItem("weight_log", itemid);
    const effort = prompt("Enter effort level as E/M/H/X", item.getEffort());

    if(!effort) 
        { return; }


    const effortnorm = effort.toLocaleUpperCase();

    if(!(effortnorm in EFFORT_CODE_MAP))
    {
        alert("Please enter single letter E/M/H/X");
        return;
    }

    item.setEffort(effortnorm);
    item.syncItem();
    redisplay();
}

function editShortName()
{
    genericEditTextField("rage_log", "short_name", EDIT_STUDY_ITEM);
}

function editWeight(itemid)
{
    const item = lookupItem("weight_log", itemid);
    const nweight = prompt("Please enter a weight: ", item.getWeight());

    if(nweight)
    {
        if(!okayInt(nweight))
        {
            alert("Please enter a valid integer");
            return;
        }

        item.setWeight(nweight);
        item.syncItem();
        redisplay();
    }

}

function editRepInfo(itemid)
{
    // Do I want to do some data type checking here...?
    genericEditTextField("weight_log", "rep_info", itemid)
}

function editItemNotes(itemid)
{
    genericEditTextField("weight_log", "notes", itemid)
}

function removeItem(itemid) 
{
    genericDeleteItem("weight_log", itemid);
}

function redisplay()
{
    redisplayMainTable();

    // redisplayStudyItem();

    // setPageComponent(getPageComponent());
}


function getMondayList()
{
    var dc = getTodayCode().nDaysAfter(10);
    const mlist = [];

    for(var idx = 0; idx < 100; idx++)
    {
        dc = dc.dayBefore();

        if (dc.getShortDayOfWeek() == "Mon")
            { mlist.push(dc); }
    }

    return mlist;
}

// Monday of weight day --> List of records corresponding to that Monday
function getDataByMonday()
{

    const mondaymap = {};

    getItemList("weight_log").forEach(function(item) {

        const relmonday = getMonday4Date(lookupDayCode(item.getDayCode()));

        if(!(relmonday.getDateString() in mondaymap)) 
            { mondaymap[relmonday.getDateString()] = []; }

        mondaymap[relmonday.getDateString()].push(item);
    });

    return mondaymap;
}


function getWeightNameMap() {

    const nmap = {};

    getItemList("movement").forEach(function(item) {
        nmap[item.getId()] = item.getShortName();
    });

    return nmap;
}

function redisplayMainTable()
{

    const namemap = getWeightNameMap();
    namemap[-1] = "----";

    const optsel = buildOptSelector()
                        .setFromMap(namemap)
                        .setElementName("move_select")
                        .setOnChange("javascript:logNewMove()")
                        .sortByDisplay()
                        .getSelectString();

    const displaymap = getNiceDateDisplayMap(10);

    const datesel = buildOptSelector()
                    .setFromMap(displaymap)
                    .setSelectedKey(getTodayCode().dayBefore().getDateString())
                    .setElementName("day_code_sel")
                    .getSelectString();    

    var pagestr = `

        Log New: ${optsel}         

        &nbsp;
        &nbsp;
        &nbsp;
        &nbsp;

        <a href="javascript:createNewMovement()"><button>+movement</button></a>

        <br/>
        ${datesel}
        <br/>
    `;

    const mondayMap = getDataByMonday();

    getMondayList().forEach(function(monday) {


        const itemlist = (mondayMap[monday.getDateString()] || []).sort(proxySort(item => [item.getDayCode()])).reverse();

        if (itemlist.length == 0) 
            {return; }

        pagestr += `
            <h4>Week of Monday, ${monday.getDateString().substr(5)}</h4>

            <br/>
        `;

        pagestr += `
            <table class="basic-table"  width="80%">
            <tr>
            <th width="7%">Date</th>
            <th>Movement</th>
            <th colspan="2">Sets / Reps</th>
            <th colspan="2">Weight</th>
            <th colspan="2">Effort</th>
            <th colspan="2">Notes</th>
            <th></th>
            </tr>
        `;        

        var prevDay = itemlist[0].getDayCode();

        itemlist.forEach(function(item) {
                          
            const move = lookupItem("movement", item.getMoveId()); 
            const effortshow = item.getEffort() in EFFORT_CODE_MAP ? EFFORT_CODE_MAP[item.getEffort()] : "????";

            if(item.getDayCode() != prevDay)
            {

                const newDow = lookupDayCode(item.getDayCode()).getDayOfWeek();

                const blankrow = `
                    <tr>
                    <td colspan="11"><b>${newDow}</b></td>
                    </tr>
                `;

                prevDay = item.getDayCode();
                pagestr += blankrow;
            }


            const rowstr = `
                <tr>
                <td>${item.getDayCode().substr(5)}</td>
                <td>${move.getShortName()}</td>
                <td>
                ${item.getRepInfo()}
                </td>
                <td>
                <a href="javascript:editRepInfo(${item.getId()})"><img src="/life/image/edit.png" height="18"/></a>
                </td>                
                <td>
                ${item.getWeight()}
                </td>
                <td>
                <a href="javascript:editWeight(${item.getId()})"><img src="/life/image/edit.png" height="18"/></a>
                </td>

                <td>${effortshow}</td>
                <td>
                <a href="javascript:editEffortLevel(${item.getId()})"><img src="/life/image/edit.png" height="18"/></a>
                </td>

                <td width="20%">${item.getNotes()}</td>
                <td width="5%">
                <a href="javascript:editItemNotes(${item.getId()})"><img src="/life/image/edit.png" height="18"/></a>
                </td>

                <td>
                <a href="javascript:removeItem(${item.getId()})"><img src="/life/image/remove.png" height="16"></a>
                </td>

                </tr>
            `;

            pagestr += rowstr;
        });

        pagestr += "</table>";
    });


    /*
    pagestr += `
        <table class="basic-table"  width="80%">
        <tr>
        <th width="7%">Date</th>
        <th>Movement</th>
        <th>Sets / Reps</th>
        <th colspan="2">Weight</th>
        <th colspan="2">Effort</th>
        <th colspan="2">Notes</th>
        <th></th>
        </tr>
    `;
    
    const itemlist = getItemList("weight_log").sort(proxySort(item => [item.getDayCode()])).reverse();
    const breaker = "&nbsp;&nbsp;&nbsp;";


    itemlist.forEach(function(item) {
                      
        const move = lookupItem("movement", item.getMoveId()); 
        const effortshow = item.getEffort() in EFFORT_CODE_MAP ? EFFORT_CODE_MAP[item.getEffort()] : "????";

        const rowstr = `
            <tr>
            <td>${item.getDayCode().substr(5)}</td>
            <td>${move.getShortName()}</td>
            <td>
            ${item.getNumSets()}x
            ${item.getRepsPerSet()}
            <td>
            ${item.getWeight()}
            </td>
            <td>
            <a href="javascript:editWeight(${item.getId()})"><img src="/life/image/edit.png" height="18"/></a>
            </td>

            <td>${effortshow}</td>
            <td>
            <a href="javascript:editEffortLevel(${item.getId()})"><img src="/life/image/edit.png" height="18"/></a>
            </td>

            <td width="20%">${item.getNotes()}</td>
            <td width="5%">
            <a href="javascript:editItemNotes(${item.getId()})"><img src="/life/image/edit.png" height="18"/></a>
            </td>

            <td>
            <a href="javascript:removeItem(${item.getId()})"><img src="/life/image/remove.png" height="16"></a>
            </td>

            </tr>
        `;

        pagestr += rowstr;
    });

    pagestr += "</table>";

    */

    populateSpanData({"main_page" : pagestr });
}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<h2>Weight Log</h2>

<br/>

<div id="main_page"></div>

<br/>


</center>
</body>
</html>
