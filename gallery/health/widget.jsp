
<%@include file="../../admin/AuthInclude.jsp_inc" %>

<html>
<head>
<title>Health Log</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

<script>

function newGood()
{
    createNewSub(100, "good");
}

function newFromBump()
{
    const itemlist = getItemList("health_log").sort(proxySort(a => [a.getDayCode()])).reverse();

    const lastitem = itemlist[0];

    createNewSub(lastitem.getRating(), lastitem.getNotes());
}

function createNewSub(rating, notestr)
{    
    const todaycode = getTodayCode().getDateString();
    
    // created_on, active_on, completed_on, dead_line
    const newrec = {
        "rating" : rating,
        "notes" : notestr,
        "day_code" : todaycode      
    };
    
    const newitem = buildItem("health_log", newrec);
    newitem.registerNSync();
    redisplay();
}

function deleteItem(killid)
{
    genericDeleteItem("health_log", killid);
}

function editItemDesc(itemid)
{
    genericEditTextField("health_log", "notes", itemid);
}

function editItemRating(itemid)
{
    genericEditIntField("health_log", "rating", itemid);
}


function redisplay()
{
    // handleNavBar();

    redisplayMainTable();
}


function redisplayMainTable()
{

    const itemlist = getItemList("health_log");
    itemlist.sort(proxySort(a => [a.getDayCode()])).reverse();

    var tablestr = `
        <table class="basic-table"  width="60%">
        <tr>
        <th>Date</th>
        <th colspan="2">Rating</th>
        <th width="50%">Notes</th>
        <th>Op</th>
        </tr>
    `;
    
    itemlist.forEach(function(item) {

        const rowstr = `
            <tr>
            <td>${item.getDayCode()}</td>
            <td>${item.getRating()}</td>
            <td>
            <a href="javascript:editItemRating(${item.getId()})"><img src="/life/image/edit.png" height="18"/></a>
            </td>
            <td>${item.getNotes()}</td>
            <td>

            <a href="javascript:editItemDesc(${item.getId()})"><img src="/life/image/edit.png" height="18"/></a>

            &nbsp;
            &nbsp;

            <a href="javascript:deleteItem(${item.getId()})"><img src="/life/image/remove.png" height="18"/></a>

            </td>            
            </tr>
        `

        tablestr += rowstr;
    });

    tablestr += "</table>";

    populateSpanData({"maintable" : tablestr });
}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>


<h3>Health Log</h3>

<br/>

<a href="javascript:newGood()"><button>good</button></a>

&nbsp;
&nbsp;
&nbsp;

<a href="javascript:newFromBump()"><button>copy</button></a>


<br/>
<br/>

<div id="maintable"></div>

<br/>

</center>
</body>
</html>
