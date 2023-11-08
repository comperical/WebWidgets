

<html>
<head>
<title>&#128260; &#23383;</title>


<%= DataServer.include(request, "tables=confounder,hanzi_data,palace_item") %>

<script>

EDIT_STUDY_ITEM = -1;

SEARCH_INPUT = "";

function createNew()
{   
    // created_on, active_on, completed_on, dead_line
    const newrec = {
        "left_char" : "L",
        "rght_char" : "R",
        "extra_info" : "..."
    };      
    
    const newitem = W.buildItem("confounder", newrec);
    newitem.syncItem();
    EDIT_STUDY_ITEM = newitem.getId();
    redisplay();    
}

function deleteItem(killid)
{
    if(confirm("Are you sure you want to delete this item?"))
    {
        W.lookupItem("confounder", killid).deleteItem();
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
    SEARCH_INPUT = "";
    redisplay();
}

function getPageComponent()
{
    return EDIT_STUDY_ITEM == -1 ? "main_display" : "edit_item";
}

function redisplayMain()
{
    var mainstr = `
        <table  class="basic-table" width="70%">
        <tr>
        <th>Char 1</th>
        <th>Char 2</th>
        <th>Notes</th>
        <th>...</th>

        </tr>

    `;

    var itemlist = W.getItemList("confounder");

    itemlist.forEach(function(item) {

        const rowstr = `
            <tr>
            <td>${item.getLeftChar()}</td>
            <td>${item.getRghtChar()}</td>
            <td>${item.getExtraInfo()}</td>
            <td>
            <a href="javascript:inspectItem(${item.getId()})">
            <img src="/u/shared/image/inspect.png" height="18"/></a>

            &nbsp;&nbsp;&nbsp;

            <a href="javascript:deleteItem(${item.getId()})">
            <img src="/u/shared/image/remove.png" height="18"/></a>

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

    const studyitem = W.lookupItem("confounder", EDIT_STUDY_ITEM);

    populateSpanData({
        "left_char" : studyitem.getLeftChar(),
        "rght_char" : studyitem.getRghtChar(),
        "left_char_BIG" : studyitem.getLeftChar(),
        "rght_char_BIG" : studyitem.getRghtChar(),
        "extra_info" : studyitem.getExtraInfo()
    });


    const leftchar = lookupHanziDataByChar(studyitem.getLeftChar());
    const rghtchar = lookupHanziDataByChar(studyitem.getRghtChar());
    
    
    populateSpanData({
    	"extra_info_left" : getCharTable(leftchar, "Left"),	    
    	"extra_info_rght" : getCharTable(rghtchar, "Right")
    });
    
}

function getCharTable(charitem, tablename) 
{
	if(!charitem)
		{ return ""; }
	
	return `
		<table class="basic-table"  width="50%">
		<tr>
		<th colspan="2">${tablename}</th>
		</tr>
		<tr>
		<td width="20%">Meaning</td>
		<td>${charitem.getDefinition()}</td>
		</tr>          
		<tr>
		<td width="20%">PinYin</td>
		<td>${charitem.getPinYin()}</td>
		</tr>		
		</table>
	`;
}

function updateSearchInput()
{
    const newsearch = prompt("Search for ");

    if (newsearch)
    {
        SEARCH_INPUT = newsearch;
    }

    redisplay();
}


function clearSearchInput()
{
    SEARCH_INPUT = "";
    redisplay();
}

function markCharacter(palaceid, isleft)
{
    markCharacterSub(palaceid, isleft, "confounder");
}

function redisplay()
{
    redisplayMain();

    redisplayEdit();

    redisplaySearchInfo();

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


<table  class="basic-table" width="50%">
<tr>    
<td width="20%">
Back
</td>
<td>
</td>
<td>
<a href="javascript:back2Main()">
<img src="/u/shared/image/leftarrow.png" height="18"/></a>
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
<img src="/u/shared/image/edit.png" height="18"/>
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
<img src="/u/shared/image/edit.png" height="18"/>
</td>
</tr>

<tr>
<td colspan="2">
<div id="extra_info"></div>
</td>
<td>
<a href="javascript:editExtraInfo()">
<img src="/u/shared/image/edit.png" height="18"/>
</td>
</tr>


</table>

<br/>

<font size="60"><span id="left_char_BIG"></span></font>

<br/><br/><br/>

<font size="60"><span id="rght_char_BIG"></span></font>

<br/>
<br/>

<span id="extra_info_left"></span>

<br/>

<span id="extra_info_rght"></span>

<span id="search_info"></span>

</span>


<br/>



</center>
</body>
</html>
