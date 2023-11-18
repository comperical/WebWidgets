
<html>
<head>
<%= DataServer.include(request) %>

<script>

var EDIT_STUDY_ITEM = -1;

function deleteItem(itemid) {
	const item = W.lookupItem('yoga_workout', itemid)
	item.deleteItem();
	redisplay();
}

// Auto-generated create new function
function createNew() {

	const newrec = {
		'wo_name' : '',
		'category_id' : 0,
		'is_active' : 0,
		'web_link' : ''
	};
	const newitem = W.buildItem('yoga_workout', newrec);
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
	const mainpageinfo = EDIT_STUDY_ITEM == -1 
				? getCategoryTable("Yoga Poses", 2) + getCategoryTable("Yoga Videos", 1) + getMainPageInfo() 
				: getEditPageInfo();
				

	const logpageinfo = getYogaLogPageInfo();
	populateSpanData({"page_info": mainpageinfo + logpageinfo + "<br/><br/><button onclick='javascript:createNewLog()'>New Log</button>"});
}

// Auto-generated getEditPageInfo function
function getEditPageInfo() {
    const item = W.lookupItem('yoga_workout', EDIT_STUDY_ITEM);
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
    <td><a href="javascript:genericEditTextField('yoga_workout', 'wo_name', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
    </tr>
    <tr><td>Category Id</td>
    <td>${item.getCategoryId()}</td>
    <td><a href="javascript:genericEditIntField('yoga_workout', 'category_id', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
    </tr>
    <tr><td>Active</td>
    <td>${item.getIsActive() == 1 ? 'Y' : 'N'}</td>
    <td><a href="javascript:toggleActive(EDIT_STUDY_ITEM)"><img src="/u/shared/image/cycle.png" height="18"></a></td></tr>
    </tr>
    <tr><td>Web Link</td>
    <td>${item.getWebLink()}</td>
    <td><a href="javascript:genericEditTextField('yoga_workout', 'web_link', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
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
	<th>Workout Name</th>
	<th>Category</th>
	<th>Active</th>
	<th>Web Link</th>
	<th>..</th></tr>
	`; 
	
	const itemlist = W.getItemList('yoga_workout');
	
	itemlist.forEach(function(item) {
			const rowstr = `
			<tr>
			<td>${shorten4Display(item.getWoName())}</td>
			<td>${shorten4Display(getCategoryName(item.getCategoryId()))}</td>
			<td>${shorten4Display(item.getIsActive() == 1 ? 'Y' : 'N')}</td>
			<td>${shorten4Display(item.getWebLink())}</td>
			<td>
			<a href="javascript:editStudyItem(${item.getId()})"><img src="/u/shared/image/inspect.png" height="16"/></a>
			&nbsp;&nbsp;&nbsp;
			<a href="javascript:deleteItem(${item.getId()})"><img src="/u/shared/image/remove.png" height="16"/></a>
			&nbsp;&nbsp;&nbsp;
			<a href="javascript:toggleActive(${item.getId()})"><img src="/u/shared/image/cycle.png" height="16"/></a>
			</td>
			</tr>
			`;
			pageinfo += rowstr;
	});
	
	pageinfo += `</table>`;
	pageinfo += `<br/><br/><a href="javascript:createNew()"><button>new</button></a>`;
	return pageinfo;
}

function toggleActive(itemid) {
    const item = W.lookupItem('yoga_workout', itemid);
    item.setIsActive(item.getIsActive() == 1 ? 0 : 1);
    item.syncItem();
    redisplay();
}


function createNewLog() {
    const newlog = {
        'category_id' : 0,
        'workout_id' : 0,
        'utc_timestamp' : new Date().toISOString(),
    };
    const newitem = W.buildItem('yoga_log', newlog);
    newitem.syncItem();
    redisplay();
}



function getYogaLogPageInfo() {
	var pageinfo = '<h3>Yoga Log</h3><table class="basic-table" width="80%"><tr><th>Category</th><th>Workout Id</th><th>Timestamp</th></tr>';
	
	const loglist = W.getItemList('yoga_log');
	
	loglist.forEach(function(log) {
			const rowstr = `
			<tr>
			<td>${shorten4Display(getCategoryName(log.getCategoryId()))}</td>
			<td>${shorten4Display(log.getWorkoutId())}</td>
			<td>${shorten4Display(log.getUtcTimestamp())}</td>
			</tr>
			`;
			pageinfo += rowstr;
	});
	
	pageinfo += '</table>';
	return pageinfo;
}

function getCategoryName(catid) {
	const categoryNames = {
		'1' : 'Yoga Video',
		'2' : 'Yoga Poses'
	};
	return categoryNames[catid];
}


        function getCategoryTable(categoryName, categoryId) {
            var pageinfo = `<h3>${categoryName}</h3>
                    <table class="basic-table" width="80%">
                    <tr>
                    <th>Workout Name</th>
                    <th>Active</th>
                    <th>Web Link</th>
                    <th>..</th></tr>
                `; 

            const itemlist =  W.getItemList("yoga_workout").filter(item => item.getCategoryId() == categoryId);

            itemlist.forEach(function(item) {
                const rowstr = `
                    <tr>
                    <td>${shorten4Display(item.getWoName())}</td>
                    <td>${shorten4Display(item.getIsActive() == 1 ? 'Y' : 'N')}</td>
                    <td>${shorten4Display(item.getWebLink())}</td>
                    <td>
                    <img src="/u/shared/image/checkmark.png" height="16" onclick='javascript:completeWorkout(${item.getId()});'/>
                    </td>
                    </tr>
                `;
                pageinfo += rowstr;
            });

            pageinfo += `</table>`;
            return pageinfo;
        }
        function completeWorkout(workout_id) {
            const workout = W.lookupItem('yoga_workout', workout_id);
            createNewLogWithID(workout.getCategoryId(), workout_id);
        }

        function createNewLogWithID(category_id, workout_id) {
            const newlog = {
                'category_id' : category_id,
                'workout_id' : workout_id,
                'utc_timestamp' : new Date().toISOString(),
            };
            const newitem = W.buildItem('yoga_log', newlog);
            newitem.syncItem();
            redisplay();
        }


</script>
<body onLoad="javascript:redisplay()">
<center>
<div id="page_info"></div>

</center>
</body>
</html>


