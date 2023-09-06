
<html>
<head>
<title>Mistakes</title>

<%= DataServer.include(request) %>

<script src="MistakeLib.js"></script>

<script>

var EDIT_STUDY_ITEM = -1;

function createNew()
{
    const shortname = prompt("Enter mistake short description : ");
    
    //CREATE TABLE incident (id int, day_code varchar(10), short_desc varchar(30), extra_info varchar(400), tag_list varchar(100), status_code varchar(10), primary key(id));


    if(shortname)
    {
        const todaycode = getTodayCode().getDateString();
        
        // created_on, active_on, completed_on, dead_line
        const newrec = {
            "day_code" : todaycode,    
            "short_desc" : shortname,
            "extra_info" : "",
            "tag_list" : "",
            "severity" : 5,
            "status_code" : STATUS_CODE_LIST[0],
            "full_desc": "NotYetSet"    
        };      
        
        const newitem = buildItem("incident", newrec);
        newitem.syncItem();
        redisplay();
    }
}

function handleNavBar() 
{
    populateTopNavBar(getHeaderInfo(), "Mistake Log");
}

function redisplay()
{
    handleNavBar();

    const pageinfo = EDIT_STUDY_ITEM == -1 ? getMainTableInfo() : getEditItemInfo();

    populateSpanData({"mainpage" : pageinfo});
}

function getMainTableInfo()
{

    const mistlist = getItemList("incident");
    mistlist.sort(proxySort(a => [a.getDayCode()])).reverse();


    var tablestr = `

        <a href="javascript:createNew()"><button>new</button></a>

        <br/>
        <br/>
    `;

    tablestr += `
        <table class="basic-table"  width="80%">
        <tr>
        <th width="7%">Date</th>
        <th>Tags</th>
        <th>Name</th>
        <th>Status</th>
        <th>Sev'ty</th>
        <th>Desc</th>
        <th>Op</th>
        </tr>
    `;
    
    mistlist.forEach(function(item) {
                
        const taglist = tagListFromItem(item).join(", ");
                
        const rowstr = `
            <tr>
            <td>${item.getDayCode().substring(5)}</td>  
            <td>${taglist}</td>         
            <td>${item.getShortDesc()}</td>
            <td>${item.getStatusCode()}</td>
            <td width="5%">${item.getSeverity()}</td>
            <td width="40%">${getBasicMistakeDesc(item)}</td>
            <td width="10%">
                <a href="javascript:editStudyItem(${item.getId()})">
                <img src="/u/shared/image/inspect.png" height=18"/></a>
                
                &nbsp; &nbsp; &nbsp;
                
                <a href="javascript:deleteItem(${item.getId()}, '${item.getShortDesc()}')">
                <img src="/u/shared/image/remove.png" height="18"/></a>
            </td>
            </tr>
        `

        tablestr += rowstr;
    });

    tablestr += "</table>";

    return tablestr;
}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<span class="page_component" id="maintable_cmp">

<div class="topnav"></div>

<br/>
<br/>

<div id="mainpage"></div>


</center>
</body>
</html>
