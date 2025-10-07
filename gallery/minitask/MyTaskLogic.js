

// In this widget, this list is hardcoded
const MASTER_TYPE_LIST = ["chinese", "crm", "life", "work"];


function getHeaderInfo()
{
    return [
        ["Mini Task List", "widget"],
        ["Mini Task Search", "MiniTaskSearch"]
    ];
}

// Gets the task's age. 
// For purposes of efficiency, caller should supply a reference to todaycode
function getTaskAge(thetask)
{
    // console.log("Task alpha is " + thetask.getAlphaDate());
    
    var alphadc = U.lookupDayCode(thetask.getAlphaDate());
    
    return alphadc.daysUntil(TODAY_CODE);
}




// Get effective priority of item, given its intrinsic priority and its age.
function getEffectivePriority(actitem)
{   
    var dayage = getTaskAge(actitem);
    
    var intprior = actitem.getPriority();
    
    var LAMBDA = Math.log(2)/5;
    
    return intprior * Math.exp(LAMBDA*dayage);
}


function getTaskItemList(wantcompleted)
{
    var tasklist = [];
    
    var biglist = W.getItemList("mini_task_list").filter(item => item.getIsBacklog() == 0);
        
    biglist.sort(U.proxySort(item => [item.getAlphaDate()])).reverse();
    
    for(var bi in biglist)
    {   
        var taskitem = biglist[bi];
        
        // console.log(taskitem.getAlphaDate());
        
        var taskcomplete = taskitem.getOmegaDate().length > 0;
        
        if(!wantcompleted && !taskcomplete)
        { 
            tasklist.push(taskitem);
            continue; 
        }
        
        if(wantcompleted && taskcomplete)
        {
            tasklist.push(taskitem);
        }
        
        if(wantcompleted && tasklist.length > 50)
            { break; }
    }
    
    // Sort completed tasks by finish date.
    if(wantcompleted)
    {
        // tasklist.sort(function(a, b) { return b.getOmegaDate().localeCompare(a.getOmegaDate()); });
        
        tasklist.sort(U.proxySort(item => [item.getOmegaDate()])).reverse();
    }
    

    return tasklist;
}