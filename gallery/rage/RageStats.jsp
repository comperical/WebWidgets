
<%@include file="../../admin/AuthInclude.jsp_inc" %>

<html>
<head>
<title>Rage Log</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

<script>

DATE_SEL_CODE = "all";

function redisplay()
{
    handleNavBar();

    redisplayMainTable();
}

function handleNavBar() 
{
    const headerinfo = [
        ["Rage Log", "widget.jsp"],
        ["Rage Stats", "RageStats.jsp"]
    ];

    populateTopNavBar(headerinfo, "Rage Stats");
}


function tagListFromItem(ritem) 
{
    const tagstr = ritem.getCategory().trim();
    return tagstr.length == 0 ? [] : tagstr.split(";");
}

function getDateSelCodeMap()
{
    return {
        "all" : "all",
        "year_2020" : "2020",
        "year_2021" : "2021",
        "last_365" : "last year",
        "last_270" : "last 9 months",
        "last_180" : "last 6 months",
        "last_90" : "last 3 months"
    }
}

function getMinMaxDates(itemlist)
{
    const alldates = itemlist.map(item => item.getDayCode()).sort();
    return [alldates[0], alldates[alldates.length-1]];
}


function getStatInfo(itemlist)
{
    // Tag --> [total, weighted]
    const statpack = {};

    itemlist.forEach(function(item) {

        const taglist = tagListFromItem(item);
        if(taglist.length == 0) 
            { return; }
        const weight = 1.0 / (taglist.length);
        // console.log("Weight is " + weight);

        taglist.forEach(function(tag) {

            if(!(tag in statpack)) {
                statpack[tag] = [0, 0];
            }

            statpack[tag][0] += 1;
            statpack[tag][1] += weight;

        });
    });

    return statpack;

}

function getFilteredItemList()
{

    const itemlist = getItemList("rage_log");

    if(DATE_SEL_CODE == "all") {
        return itemlist;
    }

    if(DATE_SEL_CODE.startsWith("year")) {
        const tokens = DATE_SEL_CODE.split("_");
        return itemlist.filter(item => item.getDayCode().startsWith(tokens[1]));
    }

    if(DATE_SEL_CODE.startsWith("last")) {

        const daysago = parseInt(DATE_SEL_CODE.split("_")[1]);
        const cutoff = getTodayCode().nDaysBefore(daysago).getDateString();
        return itemlist.filter(item => item.getDayCode() >= cutoff);
    }



}

function updateDateDisplay()
{
    DATE_SEL_CODE = getDocFormValue("date_sel");
    redisplay();
}

function redisplayMainTable()
{

    var tablestr = `
        <table class="basic-table"  width="40%">
        <tr>
        <th>Tag</th>
        <th>number</th>
        <th>weighted</th>
        <th>density</th>
        </tr>
    `;
    
    const filterlist = getFilteredItemList();
    const minmax = getMinMaxDates(filterlist);
    const statpack = getStatInfo(filterlist);
    const taglist = Object.keys(statpack).sort(proxySort(tag => [-statpack[tag][0]]));


    const daytimespan = lookupDayCode(minmax[0]).daysUntil(lookupDayCode(minmax[1]));

    const alltotals = [0, 0];

    taglist.forEach(function(tag) {

        const totals = statpack[tag];
        const density = totals[1] / daytimespan;

        const rowstr = `
            <tr>
            <td>${tag}</td>
            <td>${totals[0]}</td>
            <td>${totals[1].toFixed(1)}</td>
            <td>${density.toFixed(3)}</td>
            </tr>
        `;

        alltotals[0] += totals[0];
        alltotals[1] += totals[1];

        tablestr += rowstr;
    });

    const totaldensity = alltotals[1] / daytimespan;

    tablestr += `
        <tr>
        <td><b>total</b></td>
        <td></td>
        <td>${alltotals[1].toFixed(0)}</td>
        <td>${totaldensity.toFixed(2)}</td>
        </tr>
    `;

    tablestr += "</table>";


    const selspan = buildOptSelector()
                        .setFromMap(getDateSelCodeMap())
                        .setSelectOpener(`<select name="date_sel" onChange="javascript:updateDateDisplay()">`)
                        .setSelectedKey(DATE_SEL_CODE)
                        .getSelectString()

    populateSpanData({
        "maintable" : tablestr,
        "date_sel_span" : selspan,
        "number_of_days" : daytimespan
    });
}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<div class="topnav"></div>

<br/>
<br/>


Dates: <span id="date_sel_span"></span>
<br/>
<h3>#Days :: <span id="number_of_days"></span></h3>
<br/>


<div id="maintable"></div>


</center>
</body>
</html>
