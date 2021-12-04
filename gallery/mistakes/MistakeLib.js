const STATUS_CODE_LIST = [
    "OPEN", // needs to be addressed
    "RESOLVED", // addressed by adding a new rule/principle
    "DEFERRED"  // not addressed, but I don't want to deal with it now
];


function deleteItem(killid)
{
    const victim = lookupItem("incident", killid);

    if(confirm("Are you sure you want to delete item " + victim.getShortDesc() + " ? "))
    {
        victim.deleteItem();
        redisplay();
    }
}

function getHeaderInfo() {

    const headerinfo = [
        ["Mistake Log", "widget.jsp"],
        ["Mistake Manager", "MistakeManager.jsp"]
    ];

    return headerinfo;
}

function back2Main()
{
    EDIT_STUDY_ITEM = -1;
    redisplay();
}


function editStudyItem(itemid) 
{
    EDIT_STUDY_ITEM = itemid;
    redisplay();
}


function editShortName()
{
    genericEditTextField("incident", "short_desc", EDIT_STUDY_ITEM);
}

function getBasicMistakeDesc(mistitem)
{
    var fulldesc = mistitem.getExtraInfo();
    var desclines = fulldesc.split("\n");
    return desclines[0];
}

function saveNewDesc()
{
    const myitem = lookupItem("incident", EDIT_STUDY_ITEM);
    const newdesc = getDocFormValue("full_desc");
    myitem.setExtraInfo(newdesc);
    myitem.syncItem();
    redisplay();
}

function getTagList(itemid)
{
    const myitem = lookupItem("incident", itemid);
    return tagListFromItem(myitem);
}

function tagListFromItem(ritem) 
{
    const tagstr = ritem.getTagList().trim();
    return tagstr.length == 0 ? [] : tagstr.split(";");
}

function getTagUniverse()
{
    const tagset = new Set();

    getItemList("incident").forEach(function(ritem) {
        tagListFromItem(ritem).forEach(tag => tagset.add(tag));     
    });

    return [... tagset].sort(proxySort(s => [s.toLowerCase()]));
}

function addStudyTag()
{
    const newtag = getDocFormValue("add_tag_sel");
    var thetags = getTagList(EDIT_STUDY_ITEM);
    thetags.push(newtag);

    const myitem = lookupItem("incident", EDIT_STUDY_ITEM);
    myitem.setTagList(thetags.join(";"));
    myitem.syncItem();
    redisplay();
}

function newTagFromPrompt()
{
    const newtag = prompt("Enter new tag for this item: ");

    if(newtag == null)
        { return; }

    const thetags = getTagList(EDIT_STUDY_ITEM);
    thetags.push(newtag);

    const myitem = lookupItem("incident", EDIT_STUDY_ITEM);
    myitem.setTagList(thetags.join(";"));
    myitem.syncItem();
    redisplay();
}

function removeStudyTag(tagidx) 
{
    const oldtags = getTagList(EDIT_STUDY_ITEM);
    oldtags.splice(tagidx, 1);


    const myitem = lookupItem("incident", EDIT_STUDY_ITEM);
    myitem.setTagList(oldtags.join(";"));
    myitem.syncItem();
    redisplay();
}

function updateStatusCode()
{
    const studyitem = lookupItem("incident", EDIT_STUDY_ITEM);
    studyitem.setStatusCode(getDocFormValue("status_code_sel"));
    studyitem.syncItem();
    redisplay();
}

function updateSeverity()
{
    const studyitem = lookupItem("incident", EDIT_STUDY_ITEM);
    studyitem.setSeverity(getDocFormValue("severity_sel"));
    studyitem.syncItem();
    redisplay();
}


function updateStatusCode()
{
    const studyitem = lookupItem("incident", EDIT_STUDY_ITEM);
    studyitem.setStatusCode(getDocFormValue("status_code_sel"));
    studyitem.syncItem();
    redisplay();
}

function getEditItemInfo()
{
    massert(EDIT_STUDY_ITEM != -1);

    const taglist = getTagList(EDIT_STUDY_ITEM);
    var tagstr = "";

    for(var tagidx in taglist) {

        const tag = taglist[tagidx];

        tagstr += `
            ${tag}
            <a href="javascript:removeStudyTag('${tagidx}')">
            <img src="/life/image/remove.png" height="16" /></a>
            &nbsp; &nbsp; &nbsp;
        `;
    }

    var fulltaglist = ['---'];
    fulltaglist.push(... getTagUniverse());
    const tagsel = buildOptSelector()
                        .setKeyList(fulltaglist)
                        .setSelectOpener(`<select name="add_tag_sel" onChange="javascript:addStudyTag()">`)
                        .setSelectedKey('---');



    const studyitem = lookupItem("incident", EDIT_STUDY_ITEM);

    const statselstr = buildOptSelector()
                            .setKeyList(STATUS_CODE_LIST)
                            .setElementName("status_code_sel")
                            .setSelectedKey(studyitem.getStatusCode())
                            .setOnChange("javascript:updateStatusCode()")
                            .getSelectString();

    const severselstr = buildOptSelector()
                            .setKeyList([1,2,3,4,5,6,7,8,9,10])
                            .setSelectedKey(studyitem.getSeverity())
                            .setElementName("severity_sel")
                            .setOnChange("javascript:updateSeverity()")
                            .getSelectString();
    
    // Okay, this took me a while to get right. The issue is that 
    // the standard string.replace(...) won't do a global, and there is no replaceAll
    var desclinelist = studyitem.getExtraInfo().replace(/\n/g, "<br/>");

    return `
        <h3>Edit Item</h3>

        <br/>

        <table width="60%" class="basic-table">
        <tr>
        <td width="25%">Back</td>
        <td></td>
        <td width="30%"><a href="javascript:back2Main()"><img src="/life/image/leftarrow.png" height="18"/></a></td>
        </tr>
        <tr>
        <td>Name</td>
        <td>${studyitem.getShortDesc()}</td>
        <td><a href="javascript:editShortName()"><img src="/life/image/edit.png" height=18/></a></td>
        </tr>

        <tr>
        <td>Tags</td>
        <td>${tagstr}</td>
        <td>
        ${tagsel.getSelectString()}
        &nbsp;
        &nbsp;
        &nbsp;

        <a href="javascript:newTagFromPrompt()"><button>+new tag</button></a>
        </td>
        </tr>

        <tr>
        <td>Status</td>
        <td>${studyitem.getStatusCode()}</td>
        <td>${statselstr}</td>
        </tr>

        <tr>
        <td>Severity</td>
        <td>${studyitem.getSeverity()}</td>
        <td>${severselstr}</td>
        </tr>



        <tr>
        <td>Date</td>
        <td>${studyitem.getDayCode()}
        <td></td>
        </tr>
        </table>

        <br/>
        <br/>

        <table class="basic-table" width="30%">
        <tr>
        <td>${desclinelist}</td>
        </tr>
        </table>

        <br/>
        <br/>

        <form>
        <textarea id="full_desc" name="full_desc" rows="10" cols="50">${studyitem.getExtraInfo()}</textarea>
        </form>

        <a href="javascript:saveNewDesc()"><button>save desc</button></a>

        </span>
    `;

}





