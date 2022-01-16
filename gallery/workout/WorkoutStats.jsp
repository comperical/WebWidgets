
<%@include file="../../admin/AuthInclude.jsp_inc" %>

<html>
<head>
<title>Workout Stats</title>

<%= DataServer.basicInclude(request) %>

<script>

DATE_SEL_CODE = "last_270";

function redisplay()
{
    redisplayMainTable();
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
    // wo_type --> [total, weighted]
    const statpack = {};

    itemlist.forEach(function(item) {

        if(item.getNotes().indexOf("FAIL") > -1) 
        {
            if(!("FAIL" in statpack)) 
                { statpack["FAIL"] = 0; }

            statpack["FAIL"] += 1;
            return;
        }

        const wotype = item.getWoType();
        // console.log("Weight is " + weight);
        if(!(wotype in statpack)) {
            statpack[wotype] = 0;
        }

        statpack[wotype] += item.getWoUnits();
    });

    return statpack;

}

function getFilteredItemList()
{

    const itemlist = getItemList("workout_log");

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

function getWoTypeMap()
{
    const wtypemap = {};

    getItemList("exercise_plan").forEach(function(epitem) {
        wtypemap[epitem.getShortCode()] = epitem.getUnitCode();
    });

    wtypemap["FAIL"] = "---";

    return wtypemap;
}

function redisplayMainTable()
{

    var tablestr = `
        <table class="basic-table"  width="40%">
        <tr>
        <th>Workout</th>
        <th>Total</th>
        <th>Per Day</th>
        <th>Units</th>
        </tr>
    `;
    
    const filterlist = getFilteredItemList();

    const minmax = getMinMaxDates(filterlist);
    const daytimespan = lookupDayCode(minmax[0]).daysUntil(lookupDayCode(minmax[1]));

    const statpack = getStatInfo(filterlist);
    const wotypemap = getWoTypeMap();
    console.log(wotypemap);

    const typelist = Object.keys(statpack).sort(proxySort(wtype => [-statpack[wtype]]));

    typelist.forEach(function(wtype) {

        const total = statpack[wtype];
        const density = total / daytimespan;
        const wounits = wotypemap[wtype];


        const rowstr = `
            <tr>
            <td>${wtype}</td>
            <td>${total}</td>
            <td>${density.toFixed(2)}</td>
            <td>${wounits}</td>            
            </tr>
        `;

        // alltotals[0] += totals[0];
        // alltotals[1] += totals[1];

        tablestr += rowstr;
    });

    // const totaldensity = alltotals[1] / daytimespan;

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

<h2>Workout Stats &nbsp;&nbsp;&nbsp; <a href="widget.jsp"><button>log</button></a></h2>

Dates: <span id="date_sel_span"></span>
<br/>
<h3>#Days :: <span id="number_of_days"></span></h3>
<br/>


<div id="maintable"></div>


</center>
</body>
</html>
