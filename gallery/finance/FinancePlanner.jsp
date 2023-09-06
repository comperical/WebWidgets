
<html>
<head>
<title>Finance Categories</title>

<%= DataServer.include(request) %>

<script>

var EDIT_STUDY_ITEM = -1;

function createNew()
{
    const shortname = prompt("New Category Name : ");
    
    if(shortname)
    {        
        // created_on, active_on, completed_on, dead_line
        const newrec = {
            "category": shortname,
            "monthly_target" : 100,
            "extra_info" : "NotYetSet"     
        };      
        
        const newitem = buildItem("finance_plan", newrec);
        newitem.syncItem();
        redisplay();
    }
}

function deleteItem(killid, shortname)
{
    if(confirm("Are you sure you want to delete item " + shortname + "?"))
    {
        lookupItem("rage_log", killid).deleteItem();
        
        redisplay();
    }
}

function editStudyItem(itemid) 
{
    EDIT_STUDY_ITEM = itemid;
    redisplay();
}

function editMonthlyTarget()
{
    const showitem = lookupItem("finance_plan", EDIT_STUDY_ITEM);

    const target = prompt("Enter a new MONTHLY target: ", showitem.getMonthlyTarget());

    if(target)
    {
        if(!okayInt(target))
        {
            alert("Please enter a valid integer");
            return;
        }

        showitem.setMonthlyTarget(parseInt(target));
        showitem.syncItem();
        redisplay();   
    }
}

function back2Main()
{
    EDIT_STUDY_ITEM = -1;
    redisplay();
}

function handleNavBar() 
{
    populateTopNavBar(getFinanceHeaderInfo(), "Finance Plan");
}

function redisplay()
{
    handleNavBar();

    const pagestr = EDIT_STUDY_ITEM == -1 ? getMainTableString() : getStudyItemString();

    populateSpanData({"mainpage" : pagestr });
}

function editCatNote() 
{

    const studyitem = lookupItem("finance_plan", EDIT_STUDY_ITEM);

    const newnote = prompt("Enter a new note for category ", studyitem.getExtraInfo());

    if(newnote)
    {
        studyitem.setExtraInfo(newnote);
        studyitem.syncItem(newnote);
        redisplay();
    }
}

function getStudyItemString()
{
    const studyitem = lookupItem("finance_plan", EDIT_STUDY_ITEM);

    const dailytarget = studyitem.getMonthlyTarget() / 30;

    var mainstr = `


        <table width="50%" class="basic-table">
        <tr>
        <td width="25%">Back</td>
        <td></td>
        <td width="30%"><a href="javascript:back2Main()"><img src="/u/shared/image/leftarrow.png" height="18"/></a></td>
        </tr>
        <tr>
        <td>Category</td>
        <td>${studyitem.getCategory()}</td>
        <td></td>
        </tr>
        <tr>
        <td>Monthly Target</td>
        <td>$ ${studyitem.getMonthlyTarget()}</td>
        <td><a href="javascript:editMonthlyTarget()"><img src="/u/shared/image/edit.png" height=18/></a></td>
        </tr>
        <tr>
        <td>Daily Target</td>
        <td>$ ${dailytarget.toFixed(2)}</td>
        <td></td>
        </tr>

        <tr>
        <td>Note</td>
        <td>${studyitem.getExtraInfo()}</td>
        <td><a href="javascript:editCatNote()"><img src="/u/shared/image/edit.png" height=18/></a></td>
        </tr>

        </table>
    `;

    return mainstr;
}

function getMainTableString()
{
    var mainstr = `

        <a href="javascript:createNew()"><button>+cat</button></a>

        <br/>
        <br/>

        <table class="basic-table" width="50%">
        <tr>
        <th>Category</th>
        <th>Daily</th>
        <th>Monthly</th>
        <th>Yearly</th>
        <th>...</th>
        </tr>
    `;

    const itemlist = getItemList("finance_plan").sort(proxySort(a => [-a.getMonthlyTarget()]));
    var totalmonthly = 0;

    itemlist.forEach(function(item) {


        mainstr += `
            <tr>
            <td>${item.getCategory()}</td>
            <td>${(item.getMonthlyTarget() / 30).toFixed(2)}</td>
            <td>${item.getMonthlyTarget()}</td>
            <td>${item.getMonthlyTarget() * 12}</td>            
            <td>

            <a href="javascript:editStudyItem(${item.getId()})"><img src="/u/shared/image/inspect.png" height="18"/></a>

            </td>
            </tr>
        `;

        totalmonthly += item.getMonthlyTarget();

    });



    {
        mainstr += `
            <tr>
            <td><b>total</b></td>
            <td>${(totalmonthly / 30).toFixed(2)}</td>
            <td>${totalmonthly}</td>
            <td>${totalmonthly * 12}</td>
            <td></td>
            </tr>
        `;

    }


    mainstr += "</table>";

    return mainstr;
}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<div class="topnav"></div>

<br/>

<div id="mainpage"></div>


</center>
</body>
</html>
