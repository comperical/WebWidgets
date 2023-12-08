

<html>
<head>
<title>Dogs</title>

<!-- standard wisp include tag -->
<wisp/>

<script>

var EDIT_STUDY_ITEM = -1;

function deleteItem(itemid) {
	const item = W.lookupItem('dog_info', itemid)
	item.deleteItem();
	redisplay();
}

// Auto-generated create new function
function createNew() {

	const newrec = {
		'owner_name' : '',
		'address' : '',
		'dog_breed' : '',
		'dog_name' : '',
		'facility' : '',
		'other_notes' : '',
		'latitude' : 0.0,
		'longitude' : 0.0,
		'is_active' : 1
	};
	const newitem = W.buildItem('dog_info', newrec);
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

	const item = W.lookupItem('dog_info', EDIT_STUDY_ITEM);
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

	<tr><td>Name</td>
	<td>${item.getDogName()}</td>
	<td><a href="javascript:genericEditTextField('dog_info', 'dog_name', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td>
	</tr>


	<tr><td>Breed</td>
	<td>${item.getDogBreed()}</td>
	<td><a href="javascript:genericEditTextField('dog_info', 'dog_breed', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td>
	</tr>

	<tr><td>Address</td>
	<td>${item.getAddress()}</td>
	<td><a href="javascript:genericEditTextField('dog_info', 'address', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td>
	</tr>


	<tr><td>Active</td>
	<td>${item.getIsActive()}</td>
	<td></td>
	</tr>



	<tr><td>Owner Name</td>
	<td>${item.getOwnerName()}</td>
	<td><a href="javascript:genericEditTextField('dog_info', 'owner_name', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td>
	</tr>


	<tr><td>Facility</td>
	<td>${item.getFacility()}</td>
	<td><a href="javascript:genericEditTextField('dog_info', 'facility', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td>
	</tr>


	<tr><td>Notes</td>
	<td>${item.getOtherNotes()}</td>
	<td><a href="javascript:genericEditTextField('dog_info', 'other_notes', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td>
	</tr>
	</table>
	`;
	return pageinfo;

}


// Auto-generated getMainPageInfo function
function getMainPageInfo() {

	var pageinfo = `

		${getSimpleHeader()}

		<br/>

		<h3>Dog Info</h3>


		<table class="basic-table" width="80%">
		<tr>
		<th>Name</th>
		<th>Breed</th>
		<th>Owner Name</th>
		<th>Address</th>
		<th>Facility</th>
		<th>Notes</th>
		<th>..</th></tr>
	`;

	const itemlist = W.getItemList('dog_info');

	itemlist.forEach(function(item) {
		const rowstr = `
			<tr>
			<td>${shorten4Display(item.getDogName())}</td>
			<td>${shorten4Display(item.getDogBreed())}</td>
			<td>${shorten4Display(item.getOwnerName())}</td>
			<td>${shorten4Display(item.getAddress())}</td>
			<td>${shorten4Display(item.getFacility())}</td>
			<td>${shorten4Display(item.getOtherNotes())}</td>
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


