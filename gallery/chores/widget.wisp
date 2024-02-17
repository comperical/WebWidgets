
<html>
<head>
<title>&#x1FA92 &#x1FAA3</title>

<style>

/* 
on a wide screen, use 80% of width, but on narrow screen use at least 800 pixel 
Goal here is to work with laptop and tablet, but not phone
*/
.smarttable {

    min-width: 800px;
    width: 80%;
}

</style>

<script src="https://unpkg.com/current-device/umd/current-device.min.js"></script>

<wisp/>

<wisp widgetname="minitask" tables="mini_task_list" okay_if_absent="true"/>

<script>

W.createIndexForTable("chore_comp", ["chore_id"]);

// If true, show study/edit page
var EDIT_STUDY_ITEM = -1;

// If true, show log, otherwise full list
var SHOW_BASIC_LOG = true;

function swap2MiniTask(choreid)
{
    const choreitem = W.lookupItem("chore_def", choreid);
    const todaycode = getTodayCode().getDateString();
    const shortdesc =  "LifeChore:" + choreitem.getShortName();
    
    const newrec = {
        "task_type" : "life",
        "short_desc" : shortdesc,
        "extra_info" : "",
        "alpha_date" : todaycode,
        "omega_date" : "",
        "priority" : 5,
        "is_backlog" : 0
    };
    
    const newitem = W.buildItem("mini_task_list", newrec);
    newitem.syncItem();
        
    if(confirm("Created MTL item, should I mark the chore as complete?")) 
    { 
        const comprec = {
            "chore_id" : choreid,
            "day_code" : todaycode
        };
        
        const compitem = W.buildItem("chore_comp", comprec);
        compitem.syncItem();
    }
    
    redisplay();
}

function markComplete(choreid)
{
    const newrec = {
        "chore_id" : choreid,
        "day_code" : getTodayCode().getDateString()
    };
    
    const newitem = W.buildItem("chore_comp", newrec);
    newitem.syncItem();
    redisplay();
}

function confirmComplete(choreid)
{

    const chore = W.lookupItem("chore_def", choreid);
    if(confirm(`Confirm completion of chore ${chore.getShortName()}?`))
    {
        markComplete(choreid);
    }
}


function getLastCompletedMap()
{
    var bigloglist = W.getItemList("chore_comp");
    
    bigloglist.sort(proxySort(logitem => [logitem.getDayCode()])).reverse();

    var compmap = {};
    
    bigloglist.forEach(function(compitem) {
            
        if(!compmap.hasOwnProperty(compitem.getChoreId()))
            { compmap[compitem.getChoreId()] = compitem.getDayCode(); }
    });
    
    return compmap;
}




function toggleChoreActive(choreid, chorename)
{
    genericToggleActive("chore_def", choreid);
}

function createNew()
{
    const chorename = prompt("Enter a name for the chore: ");
    
    if(chorename)
    {       
        const newrec = {
            "day_freq" : 30,
            "short_name" : chorename,
            "extra_info" : "",
            "promoted_on" : "",
            "is_active" : 1,
            "web_link" : ""
        };
        
        const newitem = W.buildItem("chore_def", newrec);
        newitem.syncItem();
        redisplay();
    }
}

function setEditStudyItem(itemid)
{
    EDIT_STUDY_ITEM = itemid;   
    redisplay();    
}

function return2Main()
{
    setEditStudyItem(-1);   
}

function getPageComponent()
{
    if(EDIT_STUDY_ITEM != -1)
        { return "chore_item"; }
    
    return SHOW_BASIC_LOG ? "chore_log" : "chore_list";
}

function handleNavBar() {

    const selected = SHOW_BASIC_LOG ? "Chore Log" : "Chore List";

    const headerinfo = [
        ["Chore Log", "javascript:goToLog()"],
        ["Chore List", "javascript:goToDefinition()"]
    ];

    populateTopNavBar(headerinfo, selected);
}


function redisplay()
{
    handleNavBar();

    redisplayChoreList();
    
    redisplayChoreItem();
    
    redisplayChoreLog();

    setPageComponent(getPageComponent());
}

function redisplayChoreList()
{
    const showinact = getUniqElementByName("show_inactive").checked;
    
    var itemlist = W.getItemList("chore_def");
    itemlist.sort(proxySort(a => [a.getShortName()]));
    
    var tablestr = `
        <table  class="basic-table smarttable">
        <tr>
        <th>Name</th>
        <th>Frequency</th>
        <th>Active?</th>
        <th>Op</th>
        </tr>
    `;
                
    
    itemlist.forEach(function(chore) {
        
        if(!showinact && chore.getIsActive() == 0) 
            { return; }
        
        const activestr = chore.getIsActive() == 1 ? "YES" : "NO";
        
        var weblinkstr = `<img src="/u/shared/image/purewhite.png" height="18"/>`;
        
        if(chore.getWebLink().length > 0)
        {
            weblinkstr = `
                &nbsp;&nbsp;
                <a href="${chore.getWebLink()}"><img src="/u/shared/image/chainlink.png" height="18"/></a>
            `;
            
        }
        
        
        const rowstr = `
            <tr>
            <td>${chore.getShortName()}</td>
            <td>${chore.getDayFreq()}</td>
            <td>${activestr}</td>
            <td width="15%">
                <a href="javascript:setEditStudyItem(${chore.getId()})">
                <img src="/u/shared/image/inspect.png" height=18"/a></a>
                
                &nbsp; 
                &nbsp; 
                &nbsp; 

                <a href="javascript:toggleChoreActive(${chore.getId()}, '${chore.getShortName()}')">
                <img src="/u/shared/image/cycle.png" height="18"/></a>              
            
                ${weblinkstr}
            </td>
            </tr>
        `;

        tablestr += rowstr;
        
    });
    
    tablestr += `
        </table>
    `;
    
    populateSpanData({'chore_list_table' : tablestr});
}

function redisplayChoreItem()
{
    if(EDIT_STUDY_ITEM == -1)
        { return; }
        
    const edititem = W.lookupItem("chore_def", EDIT_STUDY_ITEM);

    const extrainfo = edititem.getExtraInfo();
    
    // Okay, this took me a while to get right. The issue is that 
    // the standard string.replace(...) won't do a global, and there is no replaceAll
    const desclinelist = extrainfo.replace(/\n/g, "<br/>"); 
    
    const spanmap = {
        "item_id" :         edititem.getId(),
        "short_name" :      edititem.getShortName(),
        "day_freq" :        edititem.getDayFreq(),
        "isactive" :        edititem.getIsActive() == 1 ? "YES" : "NO",
        "web_link" :        edititem.getWebLink() == "" ? "--" : edititem.getWebLink(),
        "itemdescline" :    desclinelist
    };


    document.getElementById("fullitemdesc").value = edititem.getExtraInfo();
    
    populateSpanData(spanmap);
}


function goToLog() 
{
    SHOW_BASIC_LOG = true;
    redisplay();
}

function goToDefinition() 
{
    SHOW_BASIC_LOG = false;
    redisplay();
}

function promoteItem(choreid)
{
    const chore = W.lookupItem("chore_def", choreid);
    chore.setPromotedOn(getTodayCode().getDateString());
    chore.syncItem();
    redisplay();

}



function redisplayChoreLog()
{
    const showall = getUniqElementByName("show_all").checked;

    
    var itemlist = W.getItemList("chore_def");
    itemlist.sort(proxySort(a => [a.getShortName()]));
    
    // var lastlogmap = getLastLogMap();
    const maintable = getChoreLogTable(itemlist, showall, false);
    const promotable = getChoreLogTable(itemlist, showall, true);
    
    populateSpanData({
        'chore_log_table' : maintable,
        'promoted_table' : promotable
    });
}


function getChoreLogTable(itemlist, showall, ispromo)
{



    const getheader = function(headerstr)
    {

        if(device.mobile())
        {
            return `<h3>${headerstr}</h3>`;
        }

        return `
            <h3>${headerstr}</h3>


            <table class="basic-table smarttable">
            <tr>
            <th width="25%">Chore Name</th>
            <th>Last Completed</th>
            <th>Days Since</th>
            <th>Overdue</th>
            <th width="25%">...</th>
            </tr>
        `
    }

    function getfooter()
    {
        if(device.mobile())
        {
            return "";
        }

        return "</table>";
    }

    const getrow = function(chore)
    {

        const choreage = getChoreAge(chore);
        const lastupdate = getLastChoreCompletion(chore.getId());

        const okaypromo = isPromoValid(chore, lastupdate);
        const overdue = choreage - chore.getDayFreq();

        if (okaypromo != ispromo) 
            { return ""; }

        if(chore.getIsActive() == 0)
            { return ""; }
                
        if(!showall && overdue <= 0)
            { return ""; }

        var weblinkstr = `<a href="#"><img src="/u/shared/image/purewhite.png" height="18" width="18"></a>`;
        
        if(chore.getWebLink().length > 0) 
        {
            weblinkstr = weblinkstr.replace("purewhite", "chainlink").replace("#", chore.getWebLink());
        }
        
                    
        if(device.mobile())
        {
            const lastdisplay = lastupdate == null ? "never" : lookupDayCode(lastupdate).getNiceDisplay();

            return `
                <table class="basic-table" width="60%" onClick="javascript:confirmComplete(${chore.getId()})">
                <tr>
                <td colspan="2"><b>${chore.getShortName()}</b></td>
                </tr>

                <td>
                Last Done: ${lastdisplay}
                </td>

                <td>
                Overdue: ${overdue}
                </td>
                </tr>
                </table>

                <br/>
                <br/>
            `;
        }


        const lastdisplay = lastupdate == null ? "never" : lastupdate.substring(5);

        const promocell = ispromo 
                ? `<img src="/u/shared/image/purewhite.png" height=18"/>`
                : `<a href="javascript:promoteItem(${chore.getId()})"><img src="/u/shared/image/upicon.png" height=18"/></a>`


        return `
            <tr>
            <td>${chore.getShortName()}</td>
            <td>${lastdisplay}</td>
            <td>${choreage}</td>
            <td>${overdue}</td>
            <td>

                ${promocell}
                
                &nbsp;&nbsp;

                <a href="javascript:swap2MiniTask(${chore.getId()})">
                <img src="/u/shared/image/swap2mtl.png" height=18"/a></a>
                
                &nbsp;&nbsp;
            
                <a href="javascript:markComplete(${chore.getId()})">
                <img src="/u/shared/image/checkmark.png" height=18"/a></a>
                
                &nbsp;&nbsp;
                
                <a href="javascript:setEditStudyItem(${chore.getId()})">
                <img src="/u/shared/image/inspect.png" height=18"/a></a>
                
                &nbsp;&nbsp;

                                                
                ${weblinkstr}
            </td>
            </tr>
        `;
    }


    const header = ispromo ? "Promoted" : "Main";
    var activetable = getheader(header);
    
    itemlist.forEach(function(chore) {

        activetable += getrow(chore);
    });

    activetable += getfooter();

    return activetable;
}



function getEditStudyItem()
{
    return W.lookupItem("chore_def", EDIT_STUDY_ITEM);    
}

function editChoreFreq()
{
    const showItem = getEditStudyItem();
    
    var newfreq = prompt("Enter a new frequency for this chore: ", showItem.getDayFreq());
    
    if(!newfreq)
        { return; }
    
    if(!okayInt(newfreq))
    {
        alert("Invalid number, please reenter: " + newfreq);
        return;
    }
        
    showItem.setDayFreq(parseInt(newfreq));
    showItem.syncItem();
    redisplay();
}

function editChoreName()
{
    genericEditTextField("chore_def", "short_name", EDIT_STUDY_ITEM);
}


function editWebLink()
{
    var showItem = getEditStudyItem();

    var newlink = prompt("Enter a web link for this chore: ", showItem.getWebLink());

    if(newlink)
    {
        showItem.setWebLink(newlink);
        showItem.syncItem();
        redisplay();
    }
}

function saveNewDesc()
{
    const showItem = getEditStudyItem();
    const newDesc = getDocFormValue("fullitemdesc");
    
    showItem.setExtraInfo(newDesc);
    showItem.syncItem();
    redisplay();
}

function flipActive()
{
    const showItem = getEditStudyItem();
    const curActive = showItem.getIsActive();
    
    showItem.setIsActive(curActive == 1 ? 0 : 1);
    showItem.syncItem();
    redisplay();
}




</script>

</head>

<body onLoad="javascript:redisplay()"/>


<center>

<div class="topnav"></div>

<span class="page_component" id="chore_list">


<br/>

<form>
Show InActive
<input type="checkbox" name="show_inactive" onChange="javascript:redisplay()"/>
</form>

<div id="chore_list_table"></div>

<br/>

<a name="truebutton" class="css3button" onclick="javascript:createNew()">create</a>


</span>

<span class="page_component" id="chore_log">

<br/>

<form>
Show All: <input type="checkbox" name="show_all" onChange="javascript:redisplay()"/>
</form>

<div id="promoted_table"></div>

<br/>
<br/>


<div id="chore_log_table"></div>


</span>


<span class="page_component" id="chore_item">

<h2>Chore Info</h2>

<table class="basic-table" width="50%">
<tr>
<td width="25%">Back</td>
<td></td>
<td><a name="back_url" href="javascript:return2Main()"><img src="/u/shared/image/leftarrow.png" height="18"/></a></td>
</tr>
<tr>
<td>ID</td>
<td><span id="item_id"></span></td>
<td></td>
</tr>
<tr>
<td>Name</td>
<td><span id="short_name"></span></td>
<td><a href="javascript:editChoreName()"><img src="/u/shared/image/edit.png" height="18"/></a></td>
</tr>
<tr>
<td>Link</td>
<td><span id="web_link"></span></td>
<td><a href="javascript:editWebLink()"><img src="/u/shared/image/edit.png" height="18"/></a></td>
</tr>
<tr>
<td>Frequency</td>
<td><span id="day_freq"></span></td>
<td><a href="javascript:editChoreFreq()"><img src="/u/shared/image/edit.png" height="18"/></a></td>
</tr>
<tr>
<td width="50%">Active?</td>
<td><span id="isactive"></span>

</td>
<td><a href="javascript:flipActive()"><img src="/u/shared/image/cycle.png" height=18/></a></td>
</tr>

</table>


<br/>
<br/>

<!-- Full description table -->
<table class="basic-table" width="30%">
<tr>
<td>
<span id="itemdescline">xxx<br/>yyy</span>
</td>
</tr>
</table>

<br/>
<br/>

<form>
<textarea id="fullitemdesc" name="fullitemdesc" rows="10" cols="50"></textarea>
</form>

<a href="javascript:saveNewDesc()"><button>save</button></a>


</span>


</center>
</body>
</html>
