


// Copied from D57TM 
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

function getHourTimeMap()
{
    const hourmap = {
        30 : "30 min",
        60 : "60 min",
        90 : "90 min"
    }

    for(var exhour = 2; exhour < 10; exhour++) {

        [true, false].forEach(function(ishalf) {

            const halfstr = ishalf ? ".5" : "";
            const label = `${exhour}${halfstr} hr`;
            const mincount = exhour * 60 + (ishalf ? 30 : 0);
            hourmap[mincount] = label;
        });
    }

    return hourmap;
}

// This is a copy of a function in my personal shared JS code
function getDateDisplayMap()
{

    var dayptr = U.getTodayCode().dayAfter().dayAfter();
    const displaymap = {};

    for(var idx = 0; idx < 14; idx++)
    {
        displaymap[dayptr.getDateString()] = dayptr.getNiceDisplay();
        dayptr = dayptr.dayBefore();
    }

    return displaymap;
}



// Show either a drop down showing New-by-Hour-Spent or a Wakeup button
// haveany = boolean indicating whether there are any records
function getNewItemControl(haveany)
{
    if(!haveany)
    {
        return `<a href="javascript:createWakeUpItem()"><button>wakeup</button</a>`;
    }

    const timeminsel = buildOptSelector()
                            .configureFromHash(getHourTimeMap())
                            .insertStartingPair(-1, "----")
                            .setOnChange("javascript:newByHourSpent()")
                            .setElementName("time_spent_min")
                            .getHtmlString();

    return `Hour Spent ${timeminsel}`;

}

function handleNavBar(curpage) {

    const headerinfo = [
        ["Day Plan", "widget"],
        ["Plan Templates", "DayTemplateList"]
    ];

    populateTopNavBar(headerinfo, curpage);
}


