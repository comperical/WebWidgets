
<%@include file="../AuthInclude.jsp_inc" %>


<html>
<head>
<title>Confounders!!</title>

<%@include file="../AssetInclude.jsp_inc" %>

<script src="ChineseTech.js"></script>

<%= DataServer.basicIncludeOnly(request, "confounder") %>

<script>

EDIT_STUDY_ITEM = -1;

function createNew()
{   
    const newid = newBasicId("confounder");
    
    // created_on, active_on, completed_on, dead_line
    const newrec = {
        "id" : newid,
        "left_char" : "L",
        "rght_char" : "R",
        "extra_info" : "..."
    };      
    
    const newitem = buildItem("confounder", newrec);
    newitem.registerNSync();
    EDIT_STUDY_ITEM = newid;
    redisplay();    
}

function deleteItem(killid)
{
    if(confirm("Are you sure you want to delete this item?"))
    {
        lookupItem("confounder", killid).deleteItem();
        redisplay();
    }
}

function inspectItem(itemid)
{
    EDIT_STUDY_ITEM = itemid;
    redisplay();
}

function back2Main()
{
    EDIT_STUDY_ITEM = -1;
    redisplay();
}

function getPageComponent()
{
    return EDIT_STUDY_ITEM == -1 ? "main_display" : "edit_item";
}

function redisplayMain()
{
    var mainstr = `
        <table class="dcb-basic" id="dcb-basic" width="60%">
        <tr>
        <th>Char 1</th>
        <th>Char 2</th>
        <th>Notes</th>
        <th>...</th>

        </tr>

    `;

    var itemlist = getItemList("confounder");

    itemlist.forEach(function(item) {

        const rowstr = `
            <tr>
            <td>${item.getLeftChar()}</td>
            <td>${item.getRghtChar()}</td>
            <td>${item.getExtraInfo()}</td>
            <td>
            <a href="javascript:inspectItem(${item.getId()})">
            <img src="/life/image/inspect.png" height="18"/></a>

            &nbsp;&nbsp;&nbsp;

            <a href="javascript:deleteItem(${item.getId()})">
            <img src="/life/image/remove.png" height="18"/></a>

            </td>
            </tr>
        `;

        mainstr += rowstr;

    });


    mainstr += `</table>`;

    populateSpanData({
        "maintable" : mainstr
    });


}

function redisplayEdit()
{
    if(EDIT_STUDY_ITEM == -1)
        { return; }

    const studyitem = lookupItem("confounder", EDIT_STUDY_ITEM);

    populateSpanData({
        "left_char" : studyitem.getLeftChar(),
        "rght_char" : studyitem.getRghtChar(),
        "left_char_BIG" : studyitem.getLeftChar(),
        "rght_char_BIG" : studyitem.getRghtChar(),
        "extra_info" : studyitem.getExtraInfo()
    });


}

function redisplay()
{
    redisplayMain();

    redisplayEdit();

    setPageComponent(getPageComponent());
}


function editLeftChar()
{
    genericEditTextField("confounder", "left_char", EDIT_STUDY_ITEM);
}

function editRghtChar()
{
    genericEditTextField("confounder", "rght_char", EDIT_STUDY_ITEM);
}

function editExtraInfo()
{
    genericEditTextField("confounder", "extra_info", EDIT_STUDY_ITEM);
}

</script>
</head>

<body onLoad="javascript:redisplay()">

<center>

<span class="page_component" id="main_display">

<h2>Confounder List</h2>
<a class="css3button" onclick="javascript:createNew()">NEW</a>

<br/>
<br/>

<div id="maintable"></div>
</span>



<span class="page_component" id="edit_item">

<h2>Edit Item</h2>


<table class="dcb-basic" id="dcb-basic" width="50%">
<tr>    
<td width="20%">
Back
</td>
<td>
</td>
<td>
<a href="javascript:back2Main()">
<img src="/life/image/leftarrow.png" height="18"/></a>
</td>
</tr>

<tr>    
<td>
Left
</td>
<td>
<div id="left_char"></div>
</td>
<td>
<a href="javascript:editLeftChar()">
<img src="/life/image/edit.png" height="18"/>
</td>
</tr>

<tr>
<td>
Right
</td>
<td>
<div id="rght_char"></div>
</td>
<td>
<a href="javascript:editRghtChar()">
<img src="/life/image/edit.png" height="18"/>
</td>
</tr>

<tr>
<td colspan="2">
<div id="extra_info"></div>
</td>
<td>
<a href="javascript:editExtraInfo()">
<img src="/life/image/edit.png" height="18"/>
</td>
</tr>




</table>

<br/>

<font size="60"><span id="left_char_BIG"></span></font>

<br/><br/><br/>

<font size="60"><span id="rght_char_BIG"></span></font>




<br/>
<br/>

</span>



<br/>



</center>
</body>
</html>
