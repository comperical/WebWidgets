
<html>
<head>
<title>Visit Info</title>

<!-- standard wisp include tag -->
<wisp/>

<script>

var EDIT_STUDY_ITEM = -1;

function deleteItem(itemid) {
	const item = W.lookupItem('visit_info', itemid)
	item.deleteItem();
	redisplay();
}

// Auto-generated create new function
function createNew() {

	const startday = getDocFormValue("new_visit_start");

	const newrec = {
		'start_day' : startday,
		'num_day' : 3,
		'is_active' : 1,
		'notes' : ''
	};
	const newitem = W.buildItem('visit_info', newrec);
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

	const item = W.lookupItem('visit_info', EDIT_STUDY_ITEM);
	var pageinfo = `
	<h4>Edit Item</h4>
	<table class="basic-table" width="50%">
	<tr>
	<td>Back</td>
	<td></td>
	<td><a href="javascript:back2Main()"><img src="/u/shared/image/leftarrow.png" height="18"/></a></td>
	</tr>


	<tr><td>Start</td>
	<td>${item.getStartDay()}</td>
	<td><a href="javascript:genericEditTextField('visit_info', 'start_day', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td>
	</tr>

	<tr><td>NumDay</td>
	<td>${item.getNumDay()}</td>
	<td><a href="javascript:genericEditIntField('visit_info', 'num_day', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td>
	</tr>



	<tr><td>Notes</td>
	<td>${item.getNotes()}</td>
	<td><a href="javascript:genericEditTextField('visit_info', 'notes', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td>
	</tr>


	</table>
	`;
	return pageinfo;

}


// Auto-generated getMainPageInfo function
function getMainPageInfo() {

	var pageinfo = `<h3>Visit Info</h3>


	    New Visit Start: <input name="new_visit_start" type="date"/>

	    <a href="javascript:createNew()"><button>+new</button></a>

	    <br/>
	    <br/>


		<table class="basic-table" width="80%">
		<tr>
		<th>Start</th>
		<th>#Day</th>
		<th>Notes</th>
		<th>..</th></tr>
	`;

	const itemlist = W.getItemList('visit_info');

	itemlist.forEach(function(item) {
		const rowstr = `
			<tr>
			<td>${item.getStartDay()}</td>
			<td>${item.getNumDay()}</td>
			<td>${shorten4Display(item.getNotes())}</td>
			<td>

			<a href="CalendarView.wisp?startvisit=${item.getId()}"><img src="/u/shared/image/calendar.png" height="16"/></a>

			&nbsp;&nbsp;&nbsp;


			<a href="javascript:toggleActive(${item.getId()})"><img src="/u/shared/image/cycle.png" height="16"/></a>

			&nbsp;&nbsp;&nbsp;

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
<div id="page_info"></div>

</center>
</body>
</html>


