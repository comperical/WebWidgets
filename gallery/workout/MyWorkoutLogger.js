
const WO_HEADER_INFO = [
    ["W/O Log", "widget.wisp"],
    ["W/O Planner", "ExercisePlanner.wisp"],
    ["W/O Layout", "PlanLayout.wisp"],
    ["W/O Definition", "ExerciseTemplate.wisp"],
    ["W/O Stats", "WorkoutStats.wisp"],

];


// TODO: this function exists in a lot of different places, need to consolidate
function buildGenericDict(items, keyfunc, valfunc)
{
    const mydict = {};

    items.forEach(function(itm){
        const k = keyfunc(itm);
        const v = valfunc(itm);
        mydict[k] = v;
    });

    return mydict;
}

// Nice display map for the the last N days
// Keys are normal ISO dates, values are nice displays like "Fri, 10/30"
function getNiceDateDisplayMap(daysago)
{
    const daylist = [... Array(daysago).keys()].map(n => getNDaysAgo(n));

    const displaymap = {};

    daylist.forEach(function(dc) {
        displaymap[dc.getDateString()] = dc.getNiceDisplay();
    });

    return displaymap;
}


function getActiveLayoutName()
{
	const names = new Set(W.getItemList("plan_layout")
								.filter(item => item.getIsActive() == 1)
								.map(item => item.getLayoutName()));


	if(names.size == 0)
		{ return null; }

	// massert(names.size > 0, "No recent layouts found");
	massert(names.size == 1, `Have too many recent layout names ${[... names]}`);
	return [... names][0];
}

function WorkoutLogger(workouts, goals)
{
	const mondaylist = getMondayList();
	
	// Monday daycode :: list of log IDs for that week
	var monday2WorkOut = {};

	// Goal ID :: total distance logged for it.
	var goalId2Total = {};
	
	workouts = workouts.sort(U.proxySort(witem => [witem.getDayCode(), witem.getId()]));
	
	goals = goals.sort(U.proxySort(gitem => [gitem.getMondayCode()]));
	
	// Map :: workout type :: list of unfilled goals
	var unfilled = {};
	
	mondaylist.forEach(function(mnday) {
			
		monday2WorkOut[mnday] = [];
	});
	
	goals.forEach(function(gitem) {
			
		const wotype = gitem.getShortCode();
		
		if(!(wotype in unfilled)) 
			{ unfilled[wotype] = []; }
		
		unfilled[wotype].push(gitem);
		
		goalId2Total[gitem.getId()] = 0;
		
		monday2WorkOut[gitem.getMondayCode()] = [];
	});
	
	workouts.forEach(function(woitem) {
	
		const wotype = woitem.getWoType();
			
		if(!(wotype in unfilled))
		{
			// No goals defined for this workout type - error?
			console.log("**Warning**, no workout goals defined for workout type " + wotype);
			return;
		}
		
		var goals4type = unfilled[wotype];
		
		if(goals4type.length == 0)
		{
			// No more goals for this workout type
			// This might be because you didn't build the goals yet
			// Just put it in most recent Monday
			monday2WorkOut[mondaylist[0]].push(woitem);
			return;
		}
		
		const nextgoal = goals4type[0];
		
		// Increment the total for the goal ID
		goalId2Total[nextgoal.getId()] += woitem.getWoUnits();
		
		if(goalId2Total[nextgoal.getId()] >= nextgoal.getWeeklyGoal())
		{
			goals4type.shift();
		}
				
		// Add this to the list for the day.
		monday2WorkOut[nextgoal.getMondayCode()].push(woitem);
	});
	
	this.goalId2Total = goalId2Total;
	
	this.monday2WorkOut = monday2WorkOut;
	
}

WorkoutLogger.prototype.getWorkouts4Monday = function(mondaycode)
{	
	return  (mondaycode in this.monday2WorkOut) 
				? this.monday2WorkOut[mondaycode] : [];
}

WorkoutLogger.prototype.anyFailForBatch = function(mondaycode, wotype)
{
	return this
		.getWorkouts4Monday(mondaycode)
		.filter(wo => wo.getWoType() == wotype)
		.filter(wo => wo.getNotes().indexOf("FAIL") > -1)
		.length > 0;
}



WorkoutLogger.prototype.getSummaryData = function(mondaycode)
{
	var summap = new Map();
	
	const initfunc = function(wotype) {
		if(!(wotype in summap)) 
			{ summap[wotype] = [0, 0]; }
	};
	
	const workouts = (mondaycode in this.monday2WorkOut) 
				? this.monday2WorkOut[mondaycode] : [];	
	
	workouts.forEach(function(witem) {
		
		const wotype = witem.getWoType();
		initfunc(wotype);
			
		summap[wotype][0] = summap[wotype][0] + witem.getWoUnits()*1;			
	});
	
	W.getItemList("ex_week_goal").filter(gitem => gitem.getMondayCode() == mondaycode).forEach(function(gitem) {
		
		const wocode = gitem.getShortCode();
		initfunc(wocode);
		
		summap[wocode][1] = gitem.getWeeklyGoal();
	});
	
	return summap;
}

function rebuildFromActiveLayout(mondaycode)
{
	if(!confirm("This will delete all the previous goal items for this week, and rebuild them from the template. Okay?"))
		{ return; }

	// NO LONGER AN ISSUE with random ID allocation
	// Gotcha here: if you delete before create, the new items will get reallocated the IDs deleted previously.
	// So if the delete operations get processed after the create operations because of race condition,
	// you will end up deleting the records you just built.	
	W.getItemList("ex_week_goal").filter(exitem => exitem.getMondayCode() == mondaycode).forEach(function(item) {
		item.deleteItem();
	});


	const layout = getActiveLayoutName();

	const wotypemap = buildGenericDict(W.getItemList("exercise_plan"), item => item.getShortCode(), item => item);

	const activeplan = W.getItemList("plan_layout").filter(item => item.getIsActive() == 1);
	
	activeplan.forEach(function(planitem) {
			
		// this is a foreign key error
		massert(planitem.getWoCode() in wotypemap, `Workout code ${planitem.getWoCode()} not in the type map`);
		
		const newrec = {
			"mini_note" : `Layout : ${layout}`,
			"monday_code" : mondaycode,
			"short_code" : planitem.getWoCode(),
			"weekly_goal" : planitem.getGoalDistance()
		};
		
		const newitem = W.buildItem("ex_week_goal", newrec);
		newitem.syncItem();			
	});
	
	redisplay();	
}




