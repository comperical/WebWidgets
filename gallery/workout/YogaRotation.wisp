
<html>
<head>

<wisp tables="yoga_workout,yoga_log"/>

<script>

var EDIT_STUDY_ITEM = -1;


const YOGA_CATEGORY_DICT = {
	1 : "Yoga Video",
	2 : "Yoga Poses"
};


function deleteItem(itemid) {
	const item = W.lookupItem('yoga_workout', itemid)
	item.deleteItem();
	redisplay();
}

// Auto-generated create new function
function createNew() {

	const newrec = {
		'wo_name': 'NotYetSet',
		'category_id' : 1,
		'is_active' : 0,
		'web_link' : ''
	};
	const newitem = W.buildItem('yoga_workout', newrec);
	newitem.syncItem();
	redisplay();
}


function toggleWorkoutActive(itemid)
{
	genericToggleActive("yoga_workout", itemid);
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

function updateWoType()
{
	const newtype = parseInt(getDocFormValue("yoga_type_sel"));
	const yrecord = W.lookupItem("yoga_workout", EDIT_STUDY_ITEM);
	yrecord.setCategoryId(newtype);
	yrecord.syncItem();
	redisplay();
}

function refreshRotation(catid)
{
	const display = YOGA_CATEGORY_DICT[catid];

	if(confirm(`This will refresh the rotation for ${display}, okay?`))
	{
		// CREATE TABLE yoga_log (id int, category_id int, workout_id varchar(10), utc_timestamp varchar(100), primary key(id));

		const logdata = {
			"category_id" : catid,
			"workout_id" : -1,
			"utc_timestamp" : exactMomentNow().asIsoLongBasic("UTC")
		}

		W.buildItem("yoga_log", logdata).syncItem();
		redisplay();
	}
}

function logWorkout(workoutid)
{
	const woitem = W.lookupItem("yoga_workout", workoutid);

	const logdata = {
		"category_id" : woitem.getCategoryId(),
		"workout_id" : woitem.getId(),
		"utc_timestamp" : exactMomentNow().asIsoLongBasic("UTC")
	}

	W.buildItem("yoga_log", logdata).syncItem();
	redisplay();
}


function getLastCompletedMap()
{
	const sorted = W.getItemList("yoga_log").sort(proxySort(item => [item.getUtcTimestamp()])).reverse();
	const lastcomplete = new Map();

	sorted.forEach(function(item) {
		if(!lastcomplete.has(item.getWorkoutId()))
		{ 
			const datestr = item.getUtcTimestamp().substring(0, 10);
			lastcomplete.set(item.getWorkoutId(), datestr); 
		}
	});

	return lastcomplete;

}


// Category ID => list of recent completions
function getRecentCompletionMap()
{
	const compmap = new Map();
	compmap.set(1, []);
	compmap.set(2, []);

	const founddummy = new Set();
	const sorted = W.getItemList("yoga_log").sort(proxySort(item => [item.getUtcTimestamp()])).reverse();

	sorted.forEach(function(logitem) {

		if(founddummy.has(logitem.getCategoryId()))
			{ return; }

		if(logitem.getWorkoutId() == -1)
		{
			founddummy.add(logitem.getCategoryId());
			return;
		}

		// List is fine here, it's never going to be large
		compmap.get(logitem.getCategoryId()).push(logitem.getWorkoutId());
	});

	return compmap;
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

	const item = W.lookupItem('yoga_workout', EDIT_STUDY_ITEM);
	const typesel = buildOptSelector()
						.setFromMap(YOGA_CATEGORY_DICT)
						.setSelectedKey(item.getCategoryId())
						.insertStartingPair("---", "---")
						.setElementName("yoga_type_sel")
						.setOnChange("javascript:updateWoType()")
						.getSelectString();


	var typedisp = YOGA_CATEGORY_DICT[item.getCategoryId()];
	typedisp = (typedisp == null ? "--" : typedisp);


	var pageinfo = `
	<h4>Edit Item</h4>
	<table class="basic-table" width="50%">
	<tr>
	<td>Back</td>
	<td></td>
	<td><a href="javascript:back2Main()"><img src="/u/shared/image/leftarrow.png" height="18"/></a></td>
	</tr>

	<tr><td>Workout Name</td>
	<td>${item.getWoName()}</td>

	<td><a href="javascript:genericEditTextField('yoga_workout', 'wo_name', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td>


	</tr>

	<tr><td>Workout Type</td>
	<td>${typedisp}</td>
	<td>
	${typesel}
	</td>

	</tr>
	<tr><td>IsActive</td>
	<td>${item.getIsActive()}</td>
	<td><a href="javascript:genericEditIntField('yoga_workout', 'is_active', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
	</tr>
	<tr><td>Link</td>
	<td>${item.getWebLink()}</td>
	<td><a href="javascript:genericEditTextField('yoga_workout', 'web_link', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
	</tr>
	</table>
	`;
	return pageinfo;

}

function getCategoryTable(completemap, catid)
{
	const lastcomplete = getLastCompletedMap();
	const workoutlist = W.getItemList("yoga_workout").filter(item => item.getCategoryId() == catid);

	var tablestr = `
		<table class="basic-table" width="50%">
		<tr>
		<th>Name</th>
		<th>Last</th>
		<th>Link</th>
		<th>..</th>
		</tr>
	`;


	workoutlist.forEach(function(item) {

		const recent = completemap.get(catid);
		if(recent.includes(item.getId()))
			{ return; }


		if(item.getIsActive() == 0)
			{ return; }

		const laststr = lastcomplete.has(item.getId()) ? lastcomplete.get(item.getId()) : "---";

		var linkstr = "";
		if(item.getWebLink().length > 0)
		{
			linkstr = `<a href="${item.getWebLink()}"><img src="/u/shared/image/chainlink.png" height="18"/></a>`;
		}


		const rowstr = `

			<tr>
			<td>${item.getWoName()}</td>
			<td>${laststr}</td>

			<td>${linkstr}</td>
			<td>

			<a href="javascript:logWorkout(${item.getId()})"><img src="/u/shared/image/checkmark.png" height="18"/></a>
			</td>

			</tr>
		`;

		tablestr += rowstr;


	});



	tablestr += `
		</table>

		<br/> 

		<a href="javascript:refreshRotation(${catid})"><button>refresh</button></a>
	`;

	return tablestr;
}

function getMainPageInfo()
{

	const completemap = getRecentCompletionMap();

	var pageinfo = `
		<h3>Yoga Video</h3>
		<br/>

		${getCategoryTable(completemap, 1)}


		<br/>


		<h3>Yoga Poses</h3>

		<br/>

		${getCategoryTable(completemap, 2)}

		<br/>


		${getWorkoutDefInfo()}
	`;

	return pageinfo;
}


// Auto-generated getMainPageInfo function
function getWorkoutDefInfo() {

	var pageinfo = `
		<h3>Yoga Workouts</h3>


		<table class="basic-table" width="80%">
		<tr>
		<th>Name</th>
		<th>Type</th>
		<th>Active?</th>
		<th>Link</th>
		<th>..</th></tr>
	`;

	const itemlist = W.getItemList('yoga_workout').sort(proxySort(item => [item.getCategoryId()]));

	itemlist.forEach(function(item) {

		var weblink = "";

		if(item.getWebLink().length > 0)
		{
			weblink = `<a href="${item.getWebLink()}"><img src="/u/shared/image/chainlink.png" height="18"/></a>`;
		}


		const activstr = item.getIsActive() == 1 ? "Y" : "N";
		const yogadisp = YOGA_CATEGORY_DICT[item.getCategoryId()];

		const rowstr = `
			<tr>
			<td>${item.getWoName()}</td>
			<td>${yogadisp}</td>
			<td>${activstr}</td>
			<td>${weblink}</td>
			<td>
			<a href="javascript:editStudyItem(${item.getId()})"><img src="/u/shared/image/inspect.png" height="16"/></a>
			&nbsp;&nbsp;&nbsp;
			<a href="javascript:toggleWorkoutActive(${item.getId()})"><img src="/u/shared/image/cycle.png" height="16"/></a>
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


