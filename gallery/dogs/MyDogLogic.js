

const MOVE_MODE = "move";

const INSPECT_MODE = "inspect";

const DELETE_MODE = "delete";

const LENGTHEN_MODE = "lengthen";

const SHORTEN_MODE = "shorten";


function getSimpleHeader()
{
    return `
        <center>
        <a href="index.wisp"><button>Home</button></a>

        &nbsp;
        &nbsp;
        &nbsp;

        <a href="DogInfo.wisp"><button>Dogs</button></a>

        &nbsp;
        &nbsp;
        &nbsp;

        <a href="AppointmentList.wisp"><button>Appt List</button></a>


        &nbsp;
        &nbsp;
        &nbsp;

        <a href="CalendarView.wisp"><button>Calendar</button></a>

    `;
}


function buildTimeList()
{
    const items = [];
    for(var houridx = 8; houridx < 20; houridx++)
    {
        items.push(`${houridx}:00`)
        items.push(`${houridx}:30`)
    }

    return items;
}


HOUR_TIME_LIST = buildTimeList();

// copied in a lot of places
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

function getApptColor(dogid)
{
    const coloridx = Math.abs(dogid) % 8;

    const colors = {
        0 : "pink",
        1 : "yellow",
        2 : "aquamarine",
        3 : "beige",
        4 : "cornflowerblue",
        5 : "cyan",
        6 : "darksalmon",
        7 : "deepskyblue"
    }

    return colors[coloridx];
}


function apptIncludesHour(apptitem, hourtime)
{
    const startidx = HOUR_TIME_LIST.indexOf(apptitem.getApptTime());
    const targetidx = HOUR_TIME_LIST.indexOf(hourtime);

    massert(targetidx != -1, `Bad input hour-time ${hourtime}`);
    if(startidx == -1)
        { return false; }


    const halfblock = apptitem.getApptLength() / 30;
    const idxdiff = targetidx - startidx;
    return 0 <= idxdiff && idxdiff < halfblock;
}


function findApptForDayTime(daycode, hourtime)
{
    const hits = W.getItemList("schedule_info")
                        .filter(item => item.getApptDate() == daycode)
                        .filter(item => apptIncludesHour(item, hourtime));

    if(hits.length > 1)
    {
        console.log(`**Warning**, there are multiple appointments for ${daycode}::${hourtime}`);
    }

    return hits.length == 0 ? null : hits[0];
}


function getDayList4Visit(visitid)
{
    const visititem = W.lookupItem("visit_info", visitid);
    var alpha = lookupDayCode(visititem.getStartDay());


    const daylist = [];
    for(var idx = 0; idx < visititem.getNumDay(); idx++)
    {
        daylist.push(alpha.getDateString());
        alpha = alpha.dayAfter();
    }

    return daylist;
}



function getDogInfoMap()
{
    const valfunc = function(dogitem) {
        return `${dogitem.getDogName()} -- ${dogitem.getDogBreed()}`
    }

    return buildGenericDict(W.getItemList("dog_info"), item => item.getId(), valfunc);


}