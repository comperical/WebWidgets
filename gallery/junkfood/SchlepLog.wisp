
<html>
<head>
<title>&#x1F697 &#x1F69A</title>

<wisp/>

<script>

const SCHLEP_TYPE = ["car", "plane", "train", "bus", "badwalk"]

const MAIN_TABLE = "schlep_log";

function addNew()
{
    const hours = U.getDocFormValue("hours_sel");
    const categ = U.getDocFormValue("category_sel");
    addNewSub(hours, categ);
}

function addClean()
{
    addNewSub(0, "clean");
}

function addNewSub(hours, category)
{
    const daycode = U.getDocFormValue("day_code_sel");
    
    const newrec = {
        "category" : category,
        "hour" : parseFloat(hours),
        "day_code" : daycode,
        "notes": ""
    };
        
    const newitem = W.buildItem(MAIN_TABLE, newrec);
    newitem.syncItem();
    redisplay();    
}

function addGymRun()
{
    addStandardDrive(0.4, "standard gym drive");
}

function addDownTown()
{
    addStandardDrive(0.5, "downtown and back");
}

function addStandardDrive(drivehour, drivenote)
{
    const daycode = U.getDocFormValue("day_code_sel");
    
    const newrec = {
        category : "car",
        hour : drivehour,
        day_code : daycode,
        notes : drivenote
    };
        
    const newitem = W.buildItem(MAIN_TABLE, newrec);
    newitem.syncItem();
    redisplay();
}


function deleteItem(killid)
{
    U.genericDeleteItem(MAIN_TABLE, killid);
}

function editItemNote(itemid)
{
    U.genericEditTextField(MAIN_TABLE, "notes", itemid);
}

function editItemHour(itemid)
{
    U.genericEditFloatField(MAIN_TABLE, "hour", itemid);


}

function redisplay()
{
    redispControls();

    redispFullTable();
    
    // redispSummTable();

    // redispStatTable();
}

function redispControls()
{
    buildOptSelector()
        .configureFromList([... Array(10).keys()])
        .setSelectedKey(1)
        .setElementName("hours_sel")
        .autoPopulate();


    const displaymap = getNiceDateDisplayMap(14);

    buildOptSelector()
        .configureFromHash(displaymap)
        .setSelectedKey(U.getTodayCode().dayBefore().getDateString())
        .setElementName("day_code_sel")
        .autoPopulate();

    buildOptSelector()
        .configureFromList(SCHLEP_TYPE)
        .setElementName("category_sel")
        .autoPopulate();

}




function redispFullTable()
{
    var itemlist = W.getItemList(MAIN_TABLE);
    itemlist.sort(U.proxySort(a => [a.getDayCode()])).reverse();
        
    const cutoff = U.getTodayCode().nDaysBefore(90);
            
    var tablestr = `
        <table class="basic-table"  width="50%">
        <tr>
        <th>Day</th>
        <th>Date</th>
        <th>Hours</th>
        <th>Category</th>
        <th>Notes</th>
        <th>...</th>
        </tr>
    `;
    
    itemlist.forEach(function(item) {
            
        const daycode = lookupDayCode(item.getDayCode());
                        
        if(item.getDayCode() < cutoff.getDateString())
            { return; }
            
        const rowstr = `
            <tr>
            <td>${daycode.getShortDayOfWeek()}</td>
            <td>${item.getDayCode()}</td>
            <td
            class="editable" onClick="javascrpt:editItemHour(${item.getId()})">${item.getHour()}</td>
            <td>${item.getCategory()}</td>
            <td class="editable" onClick="javascript:editItemNote(${item.getId()})">
            ${item.getNotes()}</td>
            <td>
            <a href="javascript:deleteItem(${item.getId()})">
            <img src="/u/shared/image/remove.png" height="16"/>
            </a>


            </td>
            </tr>
        `;
        
        tablestr += rowstr;
    }); 
    
    tablestr += `
        </table>
    `;
    
    
    document.getElementById('fulltable').innerHTML = tablestr;
}


</script>

</head>

<body onLoad="javascript:redisplay()">


<center>

<h3>Schlep Log</h3>

<center>


<form>
Hours:
<span id="hours_sel_span"></span>

Date:
<span id="day_code_sel_span"></span>

Type:
<span id="category_sel_span"></span>

</form>


<a href="javascript:addNew()"><button>add</button></a>

&nbsp;
&nbsp;
&nbsp;
&nbsp;

<a href="javascript:addClean()"><button>clean</button></a>

&nbsp;
&nbsp;
&nbsp;
&nbsp;

<a href="javascript:addGymRun()"><button>gym</button></a>

&nbsp;
&nbsp;
&nbsp;
&nbsp;

<a href="javascript:addDownTown()"><button>downtown</button></a>

<br/>




<h4>Full Log</h4>

<div id="fulltable"></div>


</center>
</body>
</html>
