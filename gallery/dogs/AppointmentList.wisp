


<html>
<head>

<title>Appointment List</title>
<!-- standard wisp include tag -->
<wisp/>

<script>

var EDIT_STUDY_ITEM = -1;

function deleteItem(itemid) {
	const item = W.lookupItem('schedule_info', itemid)
	item.deleteItem();
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

// Auto-generated redisplay function
function redisplay() {
	const pageinfo = EDIT_STUDY_ITEM == -1 ? getMainPageInfo() : getEditPageInfo();
	populateSpanData({"page_info" : pageinfo });
}




// Auto-generated getMainPageInfo function
function getMainPageInfo() {

	var pageinfo = `

		${getSimpleHeader()}

		<br/>

		<h3>Appointment List</h3>

		<br/>

		<table class="basic-table" width="80%">
		<tr>
		<th>Dog</th>
		<th>Date</th>
		<th>Time</th>
		<th>Length</th>
		<th>Notes</th>
		<th>..</th></tr>
	`;

	const itemlist = W.getItemList('schedule_info');

	itemlist.forEach(function(item) {

		var dogdisp = "???";
		if(W.haveItem("dog_info", item.getDogId()))
		{
			const dogitem = W.lookupItem("dog_info", item.getDogId());
			dogdisp = `${dogitem.getDogName()}`
		}


		const rowstr = `
			<tr>
			<td>${dogdisp}</td>
			<td>${item.getApptDate()}</td>
			<td>${item.getApptTime()}</td>
			<td>${item.getApptLength()}</td>
			<td>${item.getNotes()}</td>
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

	const doginfo = getDogInfoMap();

	dogSel = buildOptSelector()
				.setFromMap(doginfo)
				.insertStartingPair("-1", "----")
				.setElementName("new_appt_dog_id")
				.setOnChange("javascript:createNewAppt()")
				.getSelectString();


	pageinfo += `
		<br/>
		New Appt With: ${dogSel}
		<br/>
	`

	return pageinfo;
}

</script>
<body onLoad="javascript:redisplay()">
<center>
<div id="page_info"></div>

</center>
</body>
</html>


