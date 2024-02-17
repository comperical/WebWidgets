

function getLastChoreCompletion(choreid)
{
    const hits = W.lookupFromIndex("chore_comp", {"chore_id" : choreid})
                        .map(item => item.getDayCode())
                        .sort().reverse();


    return hits.length > 0 ? hits[0] : null;
}


function getChoreAge(choreitem)
{

    const lastcomp = getLastChoreCompletion(choreitem.getId());

    // It's never been completed
    if(lastcomp == null)
        { return 100000000; }

    const todaydc = getTodayCode();
    
    // Last date on which it was completed
    const lastcompdc = lookupDayCode(lastcomp);
    
    return lastcompdc.daysUntil(todaydc);
}


function isPromoValid(chore, lastcomplete)
{
    if(chore.getPromotedOn() == "")
        { return false; }

    return lastcomplete == null ? true : chore.getPromotedOn() > lastcomplete;
}


function handleNavBar() {

    const selected = SHOW_BASIC_LOG ? "Chore Log" : "Chore List";

    const headerinfo = [
        ["Chore Log", "javascript:goToLog()"],
        ["Chore List", "javascript:goToDefinition()"]
    ];

    populateTopNavBar(headerinfo, selected);
}