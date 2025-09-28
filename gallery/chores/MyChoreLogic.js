

function getLastChoreCompletion(choreid)
{
    return W.lookupItem("chore_def", choreid).getLastCompletion();
}


function getChoreAge(chore)
{
    return chore.daysSinceLastComp();
}

// The number of days the chore is overdue
// Negative means => it's not overdue
function getChoreOverDue(chore)
{
    return chore.daysOverDue();
}


function getPromotedOpenList()
{
    return W.getItemList("chore_def")
                .filter(chore => chore.getIsActive() == 1)
                .filter(chore => chore.isPromoted())
                .filter(chore => chore.isOverDue());
}


function handleNavBar() {

    const selected = SHOW_BASIC_LOG ? "Chore Log" : "Chore List";

    const headerinfo = [
        ["Chore Log", "javascript:goToLog()"],
        ["Chore List", "javascript:goToDefinition()"]
    ];

    populateTopNavBar(headerinfo, selected);
}



ChoreDefItem.prototype.isOverDue = function()
{
    return this.daysOverDue() > 0;
}

ChoreDefItem.prototype.daysOverDue = function()
{
    return this.daysSinceLastComp() - this.getDayFreq();
}

ChoreDefItem.prototype.isPromoted = function()
{
    if(this.getPromotedOn() == "")
        { return false; }

    const lastcomplete = this.getLastCompletion();

    return lastcomplete == null ? true : this.getPromotedOn() > lastcomplete;
}

ChoreDefItem.prototype.daysSinceLastComp = function()
{
    const lastcomp = this.getLastCompletion();

    // It's never been completed
    if(lastcomp == null)
        { return 100000000; }

    const todaydc = U.getTodayCode();
    
    // Last date on which it was completed
    const lastcompdc = U.lookupDayCode(lastcomp);
    
    return lastcompdc.daysUntil(todaydc);
}


ChoreDefItem.prototype.getLastCompletion = function()
{
    const hits = W.lookupFromOdIndex("chore_comp", { chore_id : this.getId() })
                        .map(item => item.getDayCode())
                        .sort().reverse();

    return hits.length > 0 ? hits[0] : null;
}


