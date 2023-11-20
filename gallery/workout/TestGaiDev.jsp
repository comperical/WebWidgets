
<html>
<head>
<%= DataServer.include(request) %>

<script>


// Mapping for category_id to its display counterparts.
var CATEGORY_MAP = {1: "Yoga Poses", 2: "Yoga Video"};

// Controls which item is under inspection
var EDIT_STUDY_ITEM = -1;

// Category ID for Yoga Poses
var YOGA_POSES_CATEGORY_ID = 1;

// Category ID for Yoga Videos
var YOGA_VIDEOS_CATEGORY_ID = 2;

// Create a yoga log entry.
// The function takes a workout id, category_id, and an optional flag that indicates whether this is being used to hide the workout from the 'Current' sections,
// then creates an entry in the yoga log with the current timestamp.
function addYogaLogEntry(workoutId, categoryId, isHideAction = false) {
    const workoutIdToLog = isHideAction ? -1 : workoutId;
    const timestamp = getCurrentTimestamp();
    const newLog = {
        'category_id' : categoryId,                                                             
        'workout_id' : workoutIdToLog,
        'utc_timestamp' : timestamp,
    };
    const newItem = W.buildItem('yoga_log', newLog);
    newItem.syncItem();
    redisplay();
}


function back2Main() {
	EDIT_STUDY_ITEM = -1;
	redisplay();
}


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


function deleteItem(itemid) {
	const item = W.lookupItem('yoga_workout', itemid)
	item.deleteItem();
	redisplay();
}


// This function is used to delete a specific log item from 'yoga_log' table. It retrives the item using its ID and delete it.
// After deleting, redisplay() method is called to reflect changes to the user.
function deleteLogItem(itemid) {
    const item = W.lookupItem('yoga_log', itemid)
    item.deleteItem();
    redisplay();
}


function editStudyItem(itemid) {
	EDIT_STUDY_ITEM = itemid;
	redisplay();
}


// Function that returns the current timestamp in UTC Timezone in "YYYY-MM-DD HH:MM:SS" format.
function getCurrentTimestamp() {
    const now = new Date();
    const year = now.getUTCFullYear();
    const month = String(now.getUTCMonth() + 1).padStart(2, "0");
    const date = String(now.getUTCDate()).padStart(2, "0");
    const hours = String(now.getUTCHours()).padStart(2, "0");
    const minute = String(now.getUTCMinutes()).padStart(2, "0");
    const second = String(now.getUTCSeconds()).padStart(2, "0");
    return `${year}-${month}-${date} ${hours}:${minute}:${second}`;
}


// This function generates the HTML for the 'Current Yoga Poses' section on the main page. 
// Only the active and not recently used records from the yoga_workout table with category_id for Yoga Poses are displayed.
// It also adds a new button to create a yoga log entry with the current workout id which is used to hide this workout.
function getCurrentYogaPoses() {
   var pageinfo = `<h3>Current Yoga Poses</h3>
       <table class="basic-table" width="80%">
       <tr>
       <th>Workout Name</th>
       <th>Active</th>
       <th>Web Link</th>
       <th>..</th></tr>
       `;
   const recentWorkoutMap = getRecentWorkoutMap();
   const itemlist = W.getItemList('yoga_workout').filter(item => item.getCategoryId() === YOGA_POSES_CATEGORY_ID && item.getIsActive() && !recentWorkoutMap.get(YOGA_POSES_CATEGORY_ID).includes(item.getId()));
   itemlist.forEach(function(item) {
       const rowstr = `
           <tr>
           <td>${shorten4Display(item.getWoName())}</td>
           <td>${item.getIsActive()? 'Y' : 'N'}</td>
           <td>${shorten4Display(item.getWebLink())}</td>
           <td><a href="javascript:addYogaLogEntry(${item.getId()}, ${YOGA_POSES_CATEGORY_ID}, true)"><img src="/u/shared/image/checkmark.png" height="16"/></a></td>
           </tr>
       `;
       pageinfo += rowstr;
   });
   pageinfo += `</table>`;
   return pageinfo;
}


// This function generates the HTML for the 'Current Yoga Videos' section on the main page. 
// Only the active and not recently used records from the yoga_workout table with category_id for Yoga Videos are displayed.
// It also adds a button to create a yoga log entry with the current workout id which is used to hide this workout.
function getCurrentYogaVideos() {
    var pageinfo = `<h3>Current Yoga Videos</h3>
       <table class="basic-table" width="80%">
       <tr>
       <th>Workout Name</th>
       <th>Active</th>
       <th>Web Link</th>
       <th>..</th></tr>
       `;
   const recentWorkoutMap = getRecentWorkoutMap();
   const itemlist = W.getItemList('yoga_workout').filter(item => item.getCategoryId() === YOGA_VIDEOS_CATEGORY_ID && item.getIsActive() && !recentWorkoutMap.get(YOGA_VIDEOS_CATEGORY_ID).includes(item.getId()));
   itemlist.forEach(function(item) {
       const rowstr = `
           <tr>
           <td>${shorten4Display(item.getWoName())}</td>
           <td>${item.getIsActive()? 'Y' : 'N'}</td>
           <td>${shorten4Display(item.getWebLink())}</td>
           <td><a href="javascript:addYogaLogEntry(${item.getId()}, ${YOGA_VIDEOS_CATEGORY_ID}, true)"><img src="/u/shared/image/checkmark.png" height="16"/></a></td>
           </tr>
       `;
       pageinfo += rowstr;
   });
   pageinfo += `</table>`;
   return pageinfo;
}


// This function is responsible for making an HTML page that edits items. 
// The function formats the category_id using translateCategoryId().
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
    <tr><td>Category</td>
    <td>${translateCategoryId(item.getCategoryId())}</td>
    <td><a href="javascript:genericEditIntField('yoga_workout', 'category_id', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
    </tr>
    <tr><td>Active</td>
    <td>${item.getIsActive()?'Y':'N'}</td>
    <td><a href="javascript:genericEditIntField('yoga_workout', 'is_active', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
    </tr>
    <tr><td>Web Link</td>
    <td>${item.getWebLink()}</td>
    <td><a href="javascript:genericEditTextField('yoga_workout', 'web_link', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
    </tr>
    </table>
    `;
    return pageinfo;
}


// This function generates the HTML for displaying workout details on the main page. 
// Revised to display category_name based on category_id using translateCategoryId().
// Added a new button for toggling the active state of an item.
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
            <td>${translateCategoryId(item.getCategoryId())}</td>
            <td>${item.getIsActive()? 'Y' : 'N'}</td>
            <td>${shorten4Display(item.getWebLink())}</td>
            <td>
            <a href="javascript:editStudyItem(${item.getId()})"><img src="/u/shared/image/inspect.png" height="16"/></a>
            &nbsp;&nbsp;&nbsp;
            <a href="javascript:toggleActiveState(${item.getId()})"><img src="/u/shared/image/cycle.png" height="16"/></a>
            &nbsp;&nbsp;&nbsp;
            <a href="javascript:deleteItem(${item.getId()})"><img src="/u/shared/image/remove.png" height="16"/></a>
            </td>
            </tr>
        `;
        pageinfo += rowstr;
    });
    pageinfo += `</table>`;
    pageinfo += `<br/><br/>
        <a href="javascript:createNew()"><button>new</button></a> 
        <a href="javascript:refreshYogaPoses()"><button>Refresh Yoga Poses</button></a>
        <a href="javascript:refreshYogaVideos()"><button>Refresh Yoga Videos</button></a>
    `;
    return pageinfo;
}


// It generates a Map with category IDs as keys and lists of workout IDs as values.
// The lists contain the IDs of the active workouts being displayed in the 'Current' sections, ignoring the entries resulting from a hide action.
function getRecentWorkoutMap() {
    const yogaLogList = W.getItemList('yoga_log');
    yogaLogList.sort((a, b) => b.getUtcTimestamp().localeCompare(a.getUtcTimestamp()));
    const workoutMap = new Map();
    workoutMap.set(YOGA_POSES_CATEGORY_ID, []);
    workoutMap.set(YOGA_VIDEOS_CATEGORY_ID, []);
    yogaLogList.forEach((logEntry) => {
        if (logEntry.getWorkoutId() !== -1 && !workoutMap.get(logEntry.getCategoryId()).includes(logEntry.getWorkoutId())) {
            workoutMap.get(logEntry.getCategoryId()).push(logEntry.getWorkoutId());
        }
    });
    return workoutMap;
}


// This function generates the HTML for displaying yoga log details.
// Now, it displays full UTC timestamp and the 'Date' column is renamed to 'UTC Timestamp'.
function getYogaLogInfo() {
	var pageinfo = `<h3>Yoga Log</h3>
        <table class="basic-table" width="80%">
        <tr>
        <th>Category</th>
        <th>Workout ID</th>
        <th>UTC Timestamp</th>
        <th>..</th></tr>
    `;
    const itemlist = W.getItemList('yoga_log');
    itemlist.forEach(function(item) {
        // Display the full UTC timestamp
        const timestamp = item.getUtcTimestamp();
        const rowstr = `
            <tr>
            <td>${translateCategoryId(item.getCategoryId())}</td>
            <td>${item.getWorkoutId()}</td>
            <td>${timestamp}</td>
            <td>
            <a href="javascript:deleteLogItem(${item.getId()})"><img src="/u/shared/image/remove.png" height="16"></a>
            </td></tr>
        `;
        pageinfo += rowstr;
    });
    pageinfo += `</table>`;
    return pageinfo;
}


// This function combines the HTML for the 'Current Yoga Poses', 'Current Yoga Videos', 'Main Listing' and 'Yoga Log' sections,
// and displays them in the specified sequence.
function redisplay() {
    let pageinfo;
    if (EDIT_STUDY_ITEM == -1) {
        pageinfo = getCurrentYogaPoses() + getCurrentYogaVideos() + getMainPageInfo() + getYogaLogInfo();
    } else {
        pageinfo = getEditPageInfo();
    }
    populateSpanData({"page_info" : pageinfo });
}


// This function adds a new log for all active Yoga Poses workouts.
function refreshYogaPoses() {
    const timestamp = getCurrentTimestamp();
    const itemlist = W.getItemList('yoga_workout').filter(item => item.getCategoryId() === YOGA_POSES_CATEGORY_ID && item.getIsActive());
    itemlist.forEach(function(item) {
        const newLog = {
            'category_id' : YOGA_POSES_CATEGORY_ID,
            'workout_id' : item.getId(),
            'utc_timestamp' : timestamp
        };
        const newItem = W.buildItem('yoga_log', newLog);
        newItem.syncItem();
    });
    redisplay();
}


// This function adds a new log for all active Yoga Videos workouts.
function refreshYogaVideos() {
    const timestamp = getCurrentTimestamp();
    const itemlist = W.getItemList('yoga_workout').filter(item => item.getCategoryId() === YOGA_VIDEOS_CATEGORY_ID && item.getIsActive());
    itemlist.forEach(function(item) {
        const newLog = {
            'category_id' : YOGA_VIDEOS_CATEGORY_ID,
            'workout_id' : item.getId(),
            'utc_timestamp' : timestamp
        };
        const newItem = W.buildItem('yoga_log', newLog);
        newItem.syncItem();
    });
    redisplay();
}


function shorten4Display(ob) {
	const s = '' + ob;
	if(s.length < 40) { return s; }
	return s.substring(0, 37) + '...';
}


// This function takes the id of a workout item, it retrieves the item from the datasource,
// toggles the value of its 'is_active' property and synchronizes the item back to the server to persist changes.
function toggleActiveState(itemid) {
    const item = W.lookupItem('yoga_workout', itemid);
    item.setIsActive(item.getIsActive() ? 0 : 1); // toggle the is_active field
    item.syncItem(); // send update back to server
    redisplay(); // show the updated data to the user
}


// This function translates category_id to its corresponding display name.
// If unknown category_id occurs, it returns "???".
function translateCategoryId(id) {
    return CATEGORY_MAP[id] || "???";
}



</script>
<body onLoad="javascript:redisplay()">
<center>
<div id="page_info"></div>

</center>
</body>
</html>
