

<html>
<head>

<wisp/>

<script>

var EDIT_STUDY_ITEM = -1;

function deleteItem(itemid) {
	const item = W.lookupItem('stuff_loc', itemid)
	item.deleteItem();
	redisplay();
}

// Auto-generated create new function
function createNew() {

	const newrec = {
		'loc_name' : ''
	};
	const newitem = W.buildItem('stuff_loc', newrec);
	newitem.syncItem();
	redisplay();
}


// Auto-generated redisplay function
function editStudyItem(itemid) {
	EDIT_STUDY_ITEM = itemid;
	redisplay();
}

function back2Main() {
	EDIT_STUDY_ITEM = -1;
	redisplay();
}

function shorten4Display(ob) {
	const s = '' + ob;
	if(s.length < 40) { return s; }
	return s.substring(0, 37) + '...';
}

function handleNavBar() 
{
    const current = "Locations";

    populateTopNavBar(WO_HEADER_INFO, current);
}


// Auto-generated redisplay function
function redisplay() {

	handleNavBar();

	const pageinfo = EDIT_STUDY_ITEM == -1 ? getMainPageInfo() : getEditPageInfo();
	U.populateSpanData({"page_info" : pageinfo });
}

// Auto-generated getEditPageInfo function
function getEditPageInfo() {

	const item = W.lookupItem('stuff_loc', EDIT_STUDY_ITEM);
	var pageinfo = `
	<h4>Edit Item</h4>
	<table class="basic-table" width="50%">
	<tr>
	<td>Back</td>
	<td></td>
	<td><a href="javascript:back2Main()"><img src="/u/shared/image/leftarrow.png" height="18"/></a></td>
	</tr>
	<tr><td>Id</td>
	<td>${item.getId()}</td>
	<td></td>
	</tr>
	<tr><td>Location Name</td>
	<td>${item.getLocName()}</td>
	<td><a href="javascript:U.genericEditTextField('stuff_loc', 'loc_name', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
	</tr>
	</table>
	`;
	return pageinfo;

}


// Auto-generated getMainPageInfo function
function getMainPageInfo() {

	var pageinfo = `
		<br/>
		<br/>

		<table class="basic-table" width="50%">
		<tr>
		<th>Location Name</th>
		<th># Items</th>
		<th>..</th></tr>
	`;

	const itemlist = W.getItemList('stuff_loc');
	const countmap = getLocationCountInfo();

	itemlist.forEach(function(item) {


		const subcount = countmap.get(item.getId());

		const rowstr = `
			<tr>
			<td>${shorten4Display(item.getLocName())}</td>
			<td>${subcount}</td>
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
	pageinfo += `<br/><br/><a href="javascript:createNew()"><button>new</button></a>`;
	return pageinfo;
}

</script>
<body onLoad="javascript:redisplay()">
<center>

<div class="topnav"></div>


<div id="page_info"></div>

</center>
</body>
</html>


