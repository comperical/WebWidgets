<html>
<head>
<%= DataServer.include(request) %>

<script>

var EDIT_STUDY_ITEM = 8;

function deleteItem(itemid) {
	const item = W.lookupItem('link_main', itemid)
	item.deleteItem();
	redisplay();
}

// Auto-generated create new function
function createNew() {

	const newrec = {
		'cat_id' : 0,
		'short_desc' : '',
		'link_url' : ''
	};
	const newitem = W.buildItem('link_main', newrec);
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

// Auto-generated redisplay function
function redisplay() {
	const pageinfo = EDIT_STUDY_ITEM == -1 ? getMainPageInfo() : getEditPageInfo();
	populateSpanData({"page_info" : pageinfo });
}

// Auto-generated getEditPageInfo function
function getEditPageInfo() {

	const item = W.lookupItem('link_main', EDIT_STUDY_ITEM);
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
	<tr><td>CatId</td>
	<td>${item.getCatId()}</td>
	<td><a href="javascript:genericEditIntField('link_main', 'cat_id', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
	</tr>
	<tr><td>ShortDesc</td>
	<td>${item.getShortDesc()}</td>
	<td><a href="javascript:genericEditTextField('link_main', 'short_desc', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
	</tr>
	<tr><td>LinkUrl</td>
	<td>${item.getLinkUrl()}</td>
	<td><a href="javascript:genericEditTextField('link_main', 'link_url', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
	</tr>
	</table>
	`;
	return pageinfo;

}


// Auto-generated getMainPageInfo function
function getMainPageInfo() {

	var pageinfo = `<h3>Main Listing</h3>
		<table class="basic-table" width="80%">
		<tr>
		<th>id</th>
		<th>cat_id</th>
		<th>short_desc</th>
		<th>link_url</th>
<th>..</th></tr>`

	const itemlist = W.getItemList('link_main');

	itemlist.forEach(function(item) {
		const rowstr = `
			<tr>
			<td>${shorten4Display(item.getId())}</td>
			<td>${shorten4Display(item.getCatId())}</td>
			<td>${shorten4Display(item.getShortDesc())}</td>
			<td>${shorten4Display(item.getLinkUrl())}</td>
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
<div id="page_info"></div>

</center>
</body>
</html>
