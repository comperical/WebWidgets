

// Auto-generated create new function
function createNewAppt(visitid) {

    const dogid = parseInt(getDocFormValue("new_appt_dog_id"));

    const newrec = {
        'visit_id' : visitid,
        'dog_id' : dogid,
        'appt_date' : '',
        'appt_time' : '11:00',
        'appt_length' : 60,
        'notes' : ''
    };
    const newitem = W.buildItem('schedule_info', newrec);
    newitem.syncItem();
    EDIT_STUDY_ITEM = newitem.getId();
    redisplay();
}



function updateApptDate()
{

    const newdate = getDocFormValue("appt_date_select");
    const item = W.lookupItem('schedule_info', EDIT_STUDY_ITEM);
    item.setApptDate(newdate);
    item.syncItem();
    redisplay();

}


function updateApptTime()
{

    const newtime = getDocFormValue("appt_time_select");
    const item = W.lookupItem('schedule_info', EDIT_STUDY_ITEM);
    item.setApptTime(newtime);
    item.syncItem();
    redisplay();

}

function updateApptLen()
{

    const newlen = parseInt(getDocFormValue("appt_len_select"));
    const item = W.lookupItem('schedule_info', EDIT_STUDY_ITEM);
    item.setApptLength(newlen);
    item.syncItem();
    redisplay();

}



function getDayDisplayDict(visitid)
{
    const daylist = getDayList4Visit(visitid);
    return buildGenericDict(daylist, item => item, item => lookupDayCode(item).getNiceDisplay());
}

function getLengthDispMap()
{
    const dmap = {};

    dmap[30] = "1/2 hr";
    dmap[60] = "1 hr";
    dmap[90] = "1 1/2 hr"
    dmap[120] = "2 hr"

    return dmap;
}



// Auto-generated getEditPageInfo function
function getEditPageInfo() {

    const item = W.lookupItem('schedule_info', EDIT_STUDY_ITEM);
    const dogitem = W.lookupItem("dog_info", item.getDogId());


    const timeSel = buildOptSelector()
                    .setKeyList(buildTimeList())
                    .insertStartingPair("", "---")
                    .setElementName("appt_time_select")
                    .setOnChange("javascript:updateApptTime()")
                    .setSelectedKey(item.getApptTime())
                    .getSelectString();



    const dateSel = buildOptSelector()
                        .setFromMap(getDayDisplayDict(item.getVisitId()))
                        .insertStartingPair("", "---")
                        .setElementName("appt_date_select")
                        .setOnChange("javascript:updateApptDate()")
                        .setSelectedKey(item.getApptDate())
                        .getSelectString();


    const lengthSel = buildOptSelector()
                            .setFromMap(getLengthDispMap())
                            .setElementName("appt_len_select")
                            .setOnChange("javascript:updateApptLen()")
                            .setSelectedKey(item.getApptLength())
                            .getSelectString();



    var pageinfo = `
    <h4>Appointment Info</h4>
    <table class="basic-table" width="50%">
    <tr>
    <td>Back</td>
    <td></td>
    <td><a href="javascript:back2Main()"><img src="/u/shared/image/leftarrow.png" height="18"/></a></td>
    </tr>

    <tr><td>Dog</td>
    <td>${dogitem.getDogName()}</td>
    <td></td>
    </tr>


    <tr><td>Date</td>

    <td colspan="2">
    ${dateSel}
    </td>
    </tr>



    <tr><td>Time</td>
    <td colspan="2">
    ${timeSel}
    </td>
    </tr>


    <tr>
    <td>Length</td>
    <td colspan="2">
    ${lengthSel}
    </td>
    </tr>



    <tr><td>Notes</td>
    <td>${item.getNotes()}</td>
    <td><a href="javascript:genericEditTextField('schedule_info', 'notes', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td>
    </tr>
    </table>
    `;
    return pageinfo;

}