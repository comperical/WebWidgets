<html>
<head>

<%= DataServer.include(request, "tables=phonetic_link,hanzi_data,palace_item") %>


<title>Phonetic Link</title>

<script>

var EDIT_STUDY_ITEM = -1;

var SEARCH_INPUT = "";

function deleteItem(itemid) {
	const item = W.lookupItem('phonetic_link', itemid)
	item.deleteItem();
	redisplay();
}

// Auto-generated create new function
function createNew() {

	const newrec = {
		'left_char' : '',
		'rght_char' : '',
		'extra_info' : ''
	};
	const newitem = W.buildItem('phonetic_link', newrec);
	newitem.syncItem();

    EDIT_STUDY_ITEM = newitem.getId();
	redisplay();
}


// Auto-generated redisplay function
function editStudyItem(itemid) {
	EDIT_STUDY_ITEM = itemid;
	redisplay();
}

function back2Main() {
	EDIT_STUDY_ITEM = -1;
	SEARCH_INPUT = "";
	redisplay();
}

function getPageComponent()
{
    return EDIT_STUDY_ITEM == -1 ? "main_display" : "edit_item";
}

function redisplay()
{
    redisplayMain();

    redisplayEdit();

    redisplaySearchInfo();

    setPageComponent(getPageComponent());
}

function redisplayEdit() {

    if(EDIT_STUDY_ITEM == -1)
        { return; }

    const studyitem = W.lookupItem("phonetic_link", EDIT_STUDY_ITEM);

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



function editRghtChar()
{
	genericEditTextField("phonetic_link", "rght_char", EDIT_STUDY_ITEM);
}

function editLeftChar()
{
	genericEditTextField("phonetic_link", "left_char", EDIT_STUDY_ITEM);
}

function editExtraInfo()
{
	genericEditTextField("phonetic_link", "extra_info", EDIT_STUDY_ITEM);
}

function redisplayMain()
{
	populateSpanData({ "maintable" : getMainPageInfo() });
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
    markCharacterSub(palaceid, isleft, "phonetic_link");
}

// Auto-generated getMainPageInfo function
function getMainPageInfo() {

	var pageinfo = `

		<br/>
		<table class="basic-table" width="50%">
		<tr>
		<th width="15%">L</th>
		<th width="15%">R</th>
		<th>Notes</th>
		<th>..</th></tr>`

	const itemlist = W.getItemList('phonetic_link');

	itemlist.forEach(function(item) {
		const rowstr = `
			<tr>
			<td>${item.getLeftChar()}</td>
			<td>${item.getRghtChar()}</td>
			<td>${item.getExtraInfo()}</td>
			<td>
			<a href="javascript:editStudyItem(${item.getId()})"><img src="/u/shared/image/inspect.png" height="16"/></a>
			&nbsp;&nbsp;&nbsp;
			<a href="javascript:deleteItem(${item.getId()})"><img src="/u/shared/image/remove.png" height="16"/></a>
			</td>
			</tr>
		`;
		pageinfo += rowstr;
	});

	pageinfo += `</table>`;
	return pageinfo;
}

</script>
<body onLoad="javascript:redisplay()">

<center>

<span class="page_component" id="main_display">

<h2>Phonetic Link</h2>
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
