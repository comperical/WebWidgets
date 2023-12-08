


<html>
<head>
<title>Visit Calendar</title>

<!-- standard wisp include tag -->
<wisp/>

<script>

var EDIT_STUDY_ITEM = -1;


// This is what we do in response to a click
var OPERATION_MODE = MOVE_MODE;

var PREP_MOVE_APPT_ID = -1;

var SELECTED_VISIT_ID = -1;

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
    const pageinfo = EDIT_STUDY_ITEM == -1 ? getMainPageInfo() : getEditPageInfo();
    populateSpanData({"page_info" : pageinfo });
}

function replaceAppointment(daycode, hourtime)
{
    if(PREP_MOVE_APPT_ID == -1)
    {
        // Glitch?
        return; 
    }

    const apptitem = W.lookupItem("schedule_info", PREP_MOVE_APPT_ID);
    apptitem.setApptDate(daycode);
    apptitem.setApptTime(hourtime);
    apptitem.syncItem();
    PREP_MOVE_APPT_ID = -1;
    redisplay();
}

function handleClickOp(apptid, daycode, hourtime)
{
    const apptitem = W.lookupItem("schedule_info", apptid);

    if(OPERATION_MODE == MOVE_MODE)
    {
        if(PREP_MOVE_APPT_ID != -1)
        {
            replaceAppointment(daycode, hourtime);
            return;
        }

        PREP_MOVE_APPT_ID = apptid;
        redisplay();
    }

    if(OPERATION_MODE == INSPECT_MODE)
    {
        EDIT_STUDY_ITEM = apptid;
        redisplay();
        return;
    }

    if(OPERATION_MODE == DELETE_MODE)
    {
        if(confirm(`Are you sure you want to delete this appointment?`))
        {
            apptitem.deleteItem();
            redisplay();
        }
    }

    if(OPERATION_MODE == LENGTHEN_MODE || OPERATION_MODE == SHORTEN_MODE)
    {
        const delta = OPERATION_MODE == LENGTHEN_MODE ? +30 : -30;
        const newlen = apptitem.getApptLength() + delta;

        if(newlen <= 0)
        {
            alert("This would make the appointment length 0, please just delete instead");
            return;
        }

        apptitem.setApptLength(newlen);
        apptitem.syncItem();
        redisplay();
    }


}


function showAppointmentInfo(itemid)
{
    EDIT_STUDY_ITEM = itemid;
    redisplay();
}

function updateClickMode()
{
    OPERATION_MODE = getDocFormValue("operation_mode");
    PREP_MOVE_APPT_ID = -1;
    redisplay();
}


// Auto-generated getMainPageInfo function
function getMainPageInfo() {


    const modesel = buildOptSelector()
                        .setKeyList([MOVE_MODE, INSPECT_MODE, DELETE_MODE, LENGTHEN_MODE, SHORTEN_MODE])
                        .setElementName("operation_mode")
                        .setSelectedKey(OPERATION_MODE)
                        .setOnChange("javascript:updateClickMode()")
                        .getSelectString();

    var pageinfo = `

        ${getSimpleHeader()}

        <br/>

        <h3>Calendar View</h3>

        <br/>
        Click To ${modesel} Appt
        <br/>
        <br/>


        <table class="basic-table" width="80%">
        <tr>
        <th>Time</th>
    `;

    getDayList4Visit(SELECTED_VISIT_ID).forEach(function(datestr) {

        const daycode = lookupDayCode(datestr);
        pageinfo += `<th>${daycode.getNiceDisplay()}`

    });


    pageinfo += `
        </tr>
    `;


    buildTimeList().forEach(function(hourtime) {


        pageinfo += `
            <tr>
            <td>${hourtime}</td>
        `

        getDayList4Visit(SELECTED_VISIT_ID).forEach(function(daycode) {

            const apptitem = findApptForDayTime(daycode, hourtime);

            if(apptitem == null)
            { 
                const isinner = (OPERATION_MODE == MOVE_MODE) && (PREP_MOVE_APPT_ID != -1);
                const onclick = isinner ? ` onClick="javascript:replaceAppointment('${daycode}', '${hourtime}')" ` : "";

                pageinfo += `<td ${onclick}></td>`; 
                return;
            }

            const dogitem = W.lookupItem("dog_info", apptitem.getDogId());

            const dogcolor = getApptColor(dogitem.getId());

            pageinfo += `<td style="background-color: ${dogcolor};" 
                onClick="javascript:handleClickOp(${apptitem.getId()}, '${daycode}', '${hourtime}')">
                ${dogitem.getDogName()}
            </td>
            `;


        });


        pageinfo += `
            </tr>
        `
    })


    pageinfo += `</table>`;

    const doginfo = getDogInfoMap();

    dogSel = buildOptSelector()
                .setFromMap(doginfo)
                .insertStartingPair("-1", "----")
                .setElementName("new_appt_dog_id")
                .setOnChange(`javascript:createNewAppt(${SELECTED_VISIT_ID})`)
                .getSelectString();


    pageinfo += `
        <br/>
        New Appt With: ${dogSel}
        <br/>
    `

    return pageinfo;
}

function setStartRedisplay()
{
    const params = getUrlParamHash();

    if("startvisit" in params)
    {
        SELECTED_VISIT_ID = parseInt(params["startvisit"]);

    } else {
        // Find the visit with the start that is closest to today

        const cutoff = getTodayCode().nDaysBefore(3);

        const visits = W.getItemList("visit_info")
                                .filter(item => lookupDayCode(item.getStartDay()).isAfter(cutoff))
                                .sort(proxySort(item => [item.getStartDay()]))



        if(visits.length == 0)
        {
            alert("You have no upcoming visits. Please create a visit in the Visit Info view");
            window.location.href = "VisitInfo.wisp";
            return;
        }

        SELECTED_VISIT_ID = visits[0].getId();
    }

    redisplay();
}


</script>
<body onLoad="javascript:setStartRedisplay()">
<center>
<div id="page_info"></div>

</center>
</body>
</html>


