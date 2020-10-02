
function WorkoutLogger(workouts, goals)
{
	const mondaylist = getMondayList();
	
	// Monday daycode :: list of log IDs for that week
	var monday2WorkOut = {};

	// Goal ID :: total distance logged for it.
	var goalId2Total = {};
	
	workouts = workouts.sort(proxySort(witem => [witem.getDayCode(), witem.getId()]));
	
	goals = goals.sort(proxySort(gitem => gitem.getMondayCode()));
	
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
	
	getItemList("ex_week_goal").filter(gitem => gitem.getMondayCode() == mondaycode).forEach(function(gitem) {
		
		const wocode = gitem.getShortCode();
		initfunc(wocode);
		
		summap[wocode][1] = gitem.getWeeklyGoal();
	});
	
	return summap;
}



