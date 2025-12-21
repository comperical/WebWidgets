
<html>
<head>
<title>Sleep Log</title>

<!-- standard wisp include tag -->
<wisp/>

<style>

.editable:hover {
	background-color: lightskyblue;
}

</style>

<script>

var EDIT_STUDY_ITEM = -1;

function deleteItem(itemid) {
	const item = W.lookupItem('sleep_log', itemid)
	item.deleteItem();
	redisplay();
}

// Auto-generated create new function
function createNew() {

	const scorestr = prompt('Please enter the sleep score');

	if(scorestr)
	{
		if(scorestr == null || !okayInt(scorestr))
		{
			alert("Please enter an integer");
			return;
		}

		createNewSub(parseInt(scorestr));
	}
}

function createGood() {
	createNewSub(100);
}


function copyToNewDay(itemid)
{
	const copyitem = W.lookupItem("sleep_log", itemid);
	const newrec = {
		'sleep_score' : copyitem.getSleepScore(),
		'notes' : copyitem.getNotes(),
		'day_code' : U.getTodayCode().dayBefore().getDateString()
	};


	const newitem = W.buildItem('sleep_log', newrec);
	newitem.syncItem();
	redisplay();
}

function createNewSub(score)
{
	const newrec = {
		'sleep_score' : score,
		'notes' : '' ,
		'day_code' : U.getTodayCode().dayBefore().getDateString()
	};
	const newitem = W.buildItem('sleep_log', newrec);
	newitem.syncItem();
	redisplay();
}

function editNoteInfo(itemid)
{
	U.genericEditTextField('sleep_log', 'notes', itemid);

}

function editSleepScore(itemid)
{
	U.genericEditIntField("sleep_log", "sleep_score", itemid);
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

function redisplay() {
	// No longer any need for an EDIT page view - you just edit directly from the main view
	// by clicking on the table cells
	U.populateSpanData({"page_info" : getMainPageInfo() });
}


// Auto-generated getMainPageInfo function
function getMainPageInfo() {

	var pageinfo = `<h3>Sleep Log</h3>

		<a href="javascript:createNew()"><button>new</button></a>

		&nbsp;
		&nbsp;
		&nbsp;

		<a href="javascript:createGood()"><button>good</button></a>


		<br/>
		<br/>


		<table class="basic-table" width="70%">
		<tr>
		<th>Date</th>
		<th>Score</th>
		<th>Notes</th>
		<th>..</th></tr>
	`;

	const itemlist = W.getItemList('sleep_log').sort(proxySort(item => [item.getDayCode()])).reverse();

	itemlist.forEach(function(item) {
		const rowstr = `
			<tr>
			<td>${item.getDayCode()}</td>
			<td class="editable" onClick="javascript:editSleepScore(${item.getId()})">
			${item.getSleepScore()}</td>

			<td class="editable" onClick="javascript:editNoteInfo(${item.getId()})">
			${item.getNotes()}</td>

			<td>
            <a href="javascript:copyToNewDay(${item.getId()})"><img src="/u/shared/image/upicon.png" height="18"/></a>

            &nbsp;
            &nbsp;

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


