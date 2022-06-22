
<html>
<head>
<title>Mini Task List</title>

<%= DataServer.basicInclude(request) %>

<%= DataServer.include(request, "widgetname=mailbox") %>


<script>

var TODAY_CODE = getTodayCode();

var EDIT_STUDY_ITEM = 3763;

// In this widget, this list is hardcoded
const MASTER_TYPE_LIST = ["chinese", "crm", "life", "work"];

// Gets the task's age. 
// For purposes of efficiency, caller should supply a reference to todaycode
function getTaskAge(thetask)
{
    // console.log("Task alpha is " + thetask.getAlphaDate());
    
    var alphadc = lookupDayCode(thetask.getAlphaDate());
    
    return alphadc.daysUntil(TODAY_CODE);
}

function createTaskMail()
{

    if(confirm("This will create an WidgetMail message for the task items shown below, okay?"))
    {
        const sendtarget = exactMomentNow().asIsoLongBasic("UTC");        
        const tableinfo = getActiveTableInfo(2);

        const content = `
            ${tableinfo}
        `;

        const newrec = {
            "send_target_utc" : sendtarget,
            "sent_at_utc" : "",
            "recipient" : "daniel.burfoot@gmail.com",
            "subject" : "Mini Task List",
            "is_text" : 0,
            "email_content" : content
        };
    
        const mailitem = W.buildItem("outgoing", newrec);
        mailitem.syncItem();

        alert("Mail created!");
    }
}



function getTaskItemList(wantcompleted)
{
    var tasklist = [];
    
    var biglist = W.getItemList("mini_task_list").filter(item => item.getIsBacklog() == 0);
        
    biglist.sort(proxySort(item => [item.getAlphaDate()])).reverse();
    
    for(var bi in biglist)
    {   
        var taskitem = biglist[bi];
        
        // console.log(taskitem.getAlphaDate());
        
        var taskcomplete = taskitem.getOmegaDate().length > 0;
        
        if(!wantcompleted && !taskcomplete)
        { 
            tasklist.push(taskitem);
            continue; 
        }
        
        if(wantcompleted && taskcomplete)
        {
            tasklist.push(taskitem);
        }
        
        if(wantcompleted && tasklist.length > 50)
            { break; }
    }
    
    // Sort completed tasks by finish date.
    if(wantcompleted)
    {
        // tasklist.sort(function(a, b) { return b.getOmegaDate().localeCompare(a.getOmegaDate()); });
        
        tasklist.sort(proxySort(item => [item.getOmegaDate()])).reverse();
    }
    

    return tasklist;
}

function getShowTypeList()
{
    var hits = [];
    
    document.getElementsByName("show_task_type").forEach(function(n) {
        if(!n.checked)
            { return; }
        
        hits.push(n.value);
    });
    
    if(hits.length == 0 || hits[0] == "all")
        { return MASTER_TYPE_LIST; }
    
    return hits;
}

function setDefaultShow()
{
    const params = getUrlParamHash();
    if (!('default_show' in params)) 
        {params['default_show'] = 'life';}

    var foundit = false;

    document.getElementsByName("show_task_type").forEach(function(n) {
        const checkit = params['default_show'] == n.value;
        if (checkit) {
            n.checked = true;
            foundit = true;
        }
    });
    
    if(!foundit) {
        alert(`Warning, requested default show ${params['default_show']}, but options are ${MASTER_TYPE_LIST}`);
    }

    redisplay();
}

function reDispActiveTable()
{
    populateSpanData({
        "activetable" : getActiveTableInfo(1000000)
    });
}

function getActiveTableInfo(maxrecord)
{

    var activelist = getTaskItemList(false).slice(0, maxrecord)
    
    // Sort by effective priority
    activelist.sort(proxySort(actrec => [-actrec.getPriority()]));
    
    var tablestr = `
        <table class="basic-table"  width="70%">
        <tr>
        <th>Type</th>
        <th>ShortDesc</th>
        <th>Start</th>
        <th>Age</th>
        <th>Priority</th>
        </tr>
    `;
    
    const showtypelist = getShowTypeList();
    
    activelist.forEach(function(activitem) {
            
        if(showtypelist.indexOf(activitem.getTaskType()) == -1)
            { return; }
    
        const dayage = getTaskAge(activitem);
        
        var rowstr = `
            <tr>
            <td>${activitem.getTaskType()}</td>
            <td>${activitem.getShortDesc()}</td>            
            <td>${activitem.getAlphaDate().substring(5)}</td>   
            <td>${dayage}</td>          
        `;

        // Intrinsic priority
        {
            rowstr += `
                <td>
                ${activitem.getPriority()}
                </td>
            `;
        }

            
        rowstr += "</tr>";
        
        tablestr += rowstr; 
    });

    tablestr += "</table>";
    return tablestr;    
}

function redisplay()
{
    _TASK_AGE_MAP = {};
        
    reDispActiveTable();
}





</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<span class="main2edit">



<h3>Mini Task List</h3>

<br/>

<a name="truebutton" class="css3button" onclick="javascript:createTaskMail()">mail</a>

<br/>
<br/>


<form>
<input type="radio" name="show_task_type" value="all" onChange="javascript:redisplay()">
<label>All</label>
&nbsp;
&nbsp;
&nbsp;
&nbsp;



<input type="radio" name="show_task_type" value="crm" onChange="javascript:redisplay()">
<label>CRM</label>
&nbsp;
&nbsp;
&nbsp;
&nbsp;

<input type="radio" name="show_task_type" value="life" onChange="javascript:redisplay()" checked>
<label>Life</label>
&nbsp;
&nbsp;
&nbsp;
&nbsp;

<input type="radio" name="show_task_type" value="work" onChange="javascript:redisplay()">
<label>Work</label>

&nbsp;
&nbsp;
&nbsp;
&nbsp;


<input type="radio" name="show_task_type" value="chinese" onChange="javascript:redisplay()">
<label>Chinese</label>

</form>  

<br/>

<div id="activetable"></div>


</body>
</html>
