
<html>
<head>
<title>&#x1F697 &#x1F69A</title>

<wisp/>

<script>

const SCHLEP_TYPE = ["car", "plane", "train", "bus", "badwalk"]

const MAIN_TABLE = "schlep_log";

function addNew()
{   
    const hours = getDocFormValue("hours_sel");
    const categ = getDocFormValue("category_sel");
    addNewSub(hours, categ);
}

function addClean()
{
    addNewSub(0, "clean");
}

function addNewSub(hours, category)
{
    const daycode = getDocFormValue("day_code_sel");
    
    const newrec = {
        "category" : category,
        "hours" : parseInt(hours),
        "day_code" : daycode,
        "notes": ""
    };      
        
    const newitem = W.buildItem(MAIN_TABLE, newrec);
    newitem.syncItem();
    redisplay();    
}



function deleteItem(killid)
{
    genericDeleteItem(MAIN_TABLE, killid);
}

function editItemNote(itemid)
{
    genericEditTextField(MAIN_TABLE, "notes", itemid);
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
        .setKeyList([... Array(10).keys()])
        .setSelectedKey(1)
        .setElementName("hours_sel")
        .autoPopulate();


    const displaymap = getNiceDateDisplayMap(14);

    buildOptSelector()
        .setFromMap(displaymap)
        .setSelectedKey(getTodayCode().dayBefore().getDateString())
        .setElementName("day_code_sel")
        .autoPopulate();

    buildOptSelector()
        .setKeyList(SCHLEP_TYPE)
        .setElementName("category_sel")
        .autoPopulate();

}




function redispFullTable()
{
    var itemlist = W.getItemList(MAIN_TABLE);
    itemlist.sort(proxySort(a => [a.getDayCode()])).reverse();
        
    const cutoff = getTodayCode().nDaysBefore(90);
            
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
            
        var rowstr = `
            <tr>
            <td>${daycode.getShortDayOfWeek()}</td>
            <td>${item.getDayCode()}</td>
            <td>${item.getHours()}</td> 
            <td>${item.getCategory()}</td>                       
            <td>${item.getNotes()}</td>
            <td>
            <a href="javascript:editItemNote(${item.getId()})">
            <img src="/u/shared/image/edit.png" height="16"/></a>

            &nbsp;
            &nbsp;
            &nbsp;

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

<br/>


<h4>Full Log</h4>

<div id="fulltable"></div>


</center>
</body>
</html>
