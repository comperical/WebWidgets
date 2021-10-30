
<%@ page import="java.util.*" %>

<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.DbUtil.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@ page import="lifedesign.basic.*" %>

<%@include file="../../admin/AuthInclude.jsp_inc" %>

<html>
<head>
<title>Weight Log</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>


<%
    OptSelector dayCodeSel = LifeUtil.standardDateSelector(14);
%>



<%= DataServer.basicInclude(request) %>

<script>


EFFORT_CODE_MAP = {
    "E" : "Easy",
    "M" : "Medium",
    "H" : "Hard",
    "X" : "Too Hard"
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
    const daycode = getDocFormValue("day_code");

    const moveid = parseInt(getDocFormValue("move_select"));
        
    const clonefrom = lookupRecent(moveid);

    // created_on, active_on, completed_on, dead_line
    const newrec = {
        "move_id" : moveid,
        "num_sets": clonefrom == null ? 4 : clonefrom.getNumSets(),
        "reps_per_set" : clonefrom == null ? 6 : clonefrom.getRepsPerSet(),
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
                        .setSelectOpener(`<select name="move_select" onChange="javascript:logNewMove()">`)
                        .sortByDisplay()
                        .getSelectString();

    // Gah, so ugly!!!
    // Need a JS version of the date selector
    var pagestr = `

        Log New: ${optsel}

        <br/>

        <select name="day_code">
        <%= dayCodeSel.getSelectStr(DayCode.getToday().dayBefore()) %>
        </select>        

        <br/>
        <br/>
    `;


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
