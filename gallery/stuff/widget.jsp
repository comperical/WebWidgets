
<html>
<head>
<title>Stuff Manager</title>

<%= DataServer.basicInclude(request) %>

<script>

var EDIT_STUDY_ITEM = -1;

var SHOW_CONTAINER_ID = -1;

var SHOW_LOCATION_ID = -1;

var EDIT_NOTES_FIELD = false;

var SHOW_CONTAINED_ITEM = false;

var SEARCH_TERM = null;

function createNew()
{
    const itemname = prompt("Enter name of item: ");

    if(itemname) 
    {
        const newrec = {
            "container_id" : SHOW_CONTAINER_ID,
            "location_id" : -1,
            "is_container" : 0,
            "short_name" : itemname,
            "notes" : ""
        }

        const newitem = W.buildItem("stuff_item", newrec);
        newitem.syncItem();
        EDIT_STUDY_ITEM = newitem.getId();
        redisplay();
    }
}

function updateDepthSelect()
{
    SHOW_DEPTH_SELECT = parseInt(getDocFormValue("depth_select"));
    redisplay();
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

function deleteItem(itemid)
{
    const kids = W.getItemList("stuff_item").filter(item => item.getContainerId() == itemid);
    if(kids.length > 0)
    {
        alert("You cannot remove this container because it has kid objects. Please move the kid objects and then try again");
        return;
    }

    if(confirm("Are you sure you want to delete this item?"))
    {
        genericDeleteItem("stuff_item", itemid);    
    }
}

function getContainerNameMap()
{

    const namemap = {};

    namemap[-1] = "---";

    W.getItemList("stuff_item").forEach(function(item) {

        if(item.getIsContainer() == 0) 
            { return; }

        namemap[item.getId()] = item.getShortName();
    });

    return namemap;

}

// Need to have a generic JS function to do this
function getLocationNameMap()
{
    const namemap = {};

    namemap[-1] = "---";

    W.getItemList("stuff_loc").forEach(function(item) {
        namemap[item.getId()] = item.getLocName();
    });

    return namemap;
}


function getDepthMap()
{
    const dmap = new Map();

    W.getItemList("stuff_item").forEach(function(item) {
        computeAndUpdateDepth(dmap, item.getId());
    });

    return dmap;
}

function computeAndUpdateDepth(dmap, itemid)
{
    if(dmap.has(itemid))
        { return dmap.get(itemid); }

    const item = W.lookupItem("stuff_item", itemid);
    const contid = item.getContainerId();

    var depth = 0;
    if(contid != -1 && W.haveItem("stuff_item", contid))
    {
        const pardepth = computeAndUpdateDepth(dmap, contid);
        depth = pardepth + 1;
    }

    dmap.set(itemid, depth);
    return depth;
}

function editItemName()
{
    genericEditTextField("stuff_item", "short_name", EDIT_STUDY_ITEM);

}

function editNoteField()
{
    EDIT_NOTES_FIELD = true;
    redisplay();
}

function saveNoteInfo()
{
    const notes = getDocFormValue("note_info");
    const item = W.lookupItem("stuff_item", EDIT_STUDY_ITEM);
    item.setNotes(notes);
    item.syncItem();
    EDIT_NOTES_FIELD = false;
    redisplay();
}



function createLocation()
{
    const locname = prompt("Enter name of location: ");

    const rec = {
        "loc_name" : locname
    }

    const newitem = W.buildItem("stuff_loc", rec);
    newitem.syncItem();
    redisplay();
}

function toggleShowContained()
{
    SHOW_CONTAINED_ITEM = !SHOW_CONTAINED_ITEM;
    redisplay();

}

function toggleContainer()
{
    // TODO: check if there are any items that have this as a container
    const item = W.lookupItem("stuff_item", EDIT_STUDY_ITEM);
    const newisc = item.getIsContainer() == 1 ? 0 : 1;
    item.setIsContainer(newisc);
    item.syncItem();
    redisplay();
}

function runSearch()
{
    SEARCH_TERM = prompt("Search for ", SEARCH_TERM);
    if(SEARCH_TERM) 
        { SEARCH_TERM = SEARCH_TERM.toLowerCase(); }
    redisplay();
}

function clearSearch()
{
    SEARCH_TERM = null;
    redisplay();
}

function updateContainer()
{
    const containid = parseInt(getDocFormValue("container_sel"));
    updateContainAndLoc(containid, -1);
}

function updateLocation()
{
    const locid = parseInt(getDocFormValue("location_sel"));
    updateContainAndLoc(-1, locid);
}

function updateContainAndLoc(contid, locid)
{
    massert(contid == -1 || locid == -1, "An item cannot have both a container and a location");

    const item = W.lookupItem("stuff_item", EDIT_STUDY_ITEM);
    item.setContainerId(contid);
    item.setLocationId(locid);
    item.syncItem();
    redisplay();
}


function updateShowContainer()
{
    SHOW_LOCATION_ID = -1;
    SHOW_CONTAINER_ID = parseInt(getDocFormValue("show_container_sel"));
    redisplay();
}

function updateShowLocation()
{
    SHOW_LOCATION_ID = parseInt(getDocFormValue("show_location_sel"));
    SHOW_CONTAINER_ID = -1;
    redisplay();
}


function redisplay()
{
    const pagestr = EDIT_STUDY_ITEM == -1 ? getMainListing() : getEditListing();

    populateSpanData({"main_page" : pagestr});
}

function getEditListing()
{

    const item = W.lookupItem("stuff_item", EDIT_STUDY_ITEM);

    const iscont = item.getIsContainer() == 1 ? "YES" : "NO";

    const cnamemap = getContainerNameMap();

    const contsel = buildOptSelector()
                        .setFromMap(cnamemap)
                        .setSelectedKey(item.getContainerId())
                        .setElementName("container_sel")
                        .setOnChange("javascript:updateContainer()")
                        .getSelectString();


    const locnamemap = getLocationNameMap();

    const locatesel = buildOptSelector()
                        .setFromMap(locnamemap)
                        .setSelectedKey(item.getLocationId())
                        .setElementName("location_sel")
                        .setOnChange("javascript:updateLocation()")
                        .getSelectString();                        


    var containerlink = "---";
    if (item.getContainerId() != -1) 
    {
        const contname = cnamemap[item.getContainerId()];
        containerlink = `<a href="javascript:editStudyItem(${item.getContainerId()})">${contname}</a>`;
    }

    var pageinfo = `

        <h3>Edit Info</h3>

        <table class="basic-table" width="50%">
        <tr>
        <td><b>Back</b></td>
        <td></td>
        <td><a href="javascript:back2Main()"><img src="/u/shared/image/leftarrow.png" height="18"/></a></td>
        </tr>
        <tr>
        <td><b>Name</b></td>
        <td>${item.getShortName()}</td>
        <td><a href="javascript:editItemName()"><img src="/u/shared/image/edit.png" height="18"/></a></td>
        </tr>
        <tr>
        <td><b>Container</b></td>
        <td>${containerlink}</td>
        <td>${contsel}</td>
        </tr>

        <tr>
        <td><b>Location</b></td>
        <td>${locnamemap[item.getLocationId()]}</td>
        <td>${locatesel}</td>
        </tr>

        <tr>
        <td><b>Is Container?</b></td>
        <td>${iscont}</td>
        <td><a href="javascript:toggleContainer()"><img src="/u/shared/image/cycle.png" height="18"/></a></td>
        </tr>
        </table>

        <br/>
        <br/>
    `;

    if(EDIT_NOTES_FIELD) 
    {
        pageinfo += `
            <textarea name="note_info" rows="4" cols="80">${item.getNotes()}</textarea>

            <br/>
            <br/>

            <a href="javascript:saveNoteInfo()"><button>save</button></a>
        `;

    } else {

        var noteinfo = item.getNotes().replace(/\n/g, "HTML BREAK");


        pageinfo += `
            <table class="basic-table" width="50%">
            <tr>
            <td>${noteinfo}</td>
            <td width="20%">
            <a href="javascript:editNoteField()"><img src="/u/shared/image/edit.png" height="18"/></a>
            </td>
            </tr>
            </table>
        `;
    }


    if(item.getIsContainer() == 1)
    {
        pageinfo += `



        `;

        const kidlist = W.getItemList("stuff_item").filter(kid => kid.getContainerId() == item.getId());

        if(kidlist.length > 0)
        {
            var subtab = `

                <br/>
                <br/>

                <table width="50%" class="basic-table">
                <tr>
                <th>Contained Item</th>
                <th></th>
                </tr>
            `;

            kidlist.forEach(function(kid) {
                const kidrow = `
                    <tr>
                    <td>${kid.getShortName()}</td>
                    <td width="20%">
                    <a href="javascript:editStudyItem(${kid.getId()})">
                    <img src="/u/shared/image/inspect.png" height="18"/></a>

                    &nbsp;
                    &nbsp;
                    &nbsp;

                    <a href="javascript:deleteItem(${kid.getId()}">
                    <img src="/u/shared/image/remove.png" height="18"/></a>


                    </td>
                    </tr>
                `;

                subtab += kidrow;
            });

            subtab += `
                </table>
                <br/>
                <a href="javascript:createNew()"><button>+item</button></a>
            `;

            pageinfo += subtab;
        }

    }


    return pageinfo;
}

function getLocationId(item)
{
    if(item.getLocationId() != -1)
        { return item.getLocationId(); }

    if(item.getContainerId() != -1)
    {
        const cont = W.lookupItem("stuff_item", item.getContainerId());
        return getLocationId(cont);
    }

    return -1;
}

function getSortTuple(item)
{
    const locid = getLocationId(item);
    const locname = locid == -1 ? "aaaa" : W.lookupItem("stuff_loc", locid).getLocName();

    const contid = item.getContainerId();
    const contname = contid == -1 ? item.getShortName() : W.lookupItem("stuff_item", contid).getShortName();

    const sort3 = contid == -1 ? "aaaaaa" : item.getShortName();

    return [locname, contname, sort3];
}

function getMainListing()
{
    const depthmap = getDepthMap();
    const cnamemap = getContainerNameMap();
    const locnamemap = getLocationNameMap();

    const showContainer = buildOptSelector()
                        .setFromMap(cnamemap)
                        .sortByDisplay()
                        .setSelectedKey(SHOW_CONTAINER_ID)
                        .setElementName("show_container_sel")
                        .setOnChange("javascript:updateShowContainer()")
                        .getSelectString();

    const showLocation = buildOptSelector()
                        .setFromMap(locnamemap)
                        .sortByDisplay()
                        .setSelectedKey(SHOW_LOCATION_ID)
                        .setElementName("show_location_sel")
                        .setOnChange("javascript:updateShowLocation()")
                        .getSelectString();




    const showContainedButton = `
    <a href="javascript:toggleShowContained()"><button>${SHOW_CONTAINED_ITEM ? "hide sub" : "show sub"}</button></a>
    `;

    var pageinfo = `

        <h3>Stuff Manager</h3>

    `;


    if(SEARCH_TERM == null) {

        pageinfo += `

            Location: ${showLocation}

            &nbsp;
            &nbsp;
            &nbsp;
            &nbsp;

            Container: ${showContainer}

            &nbsp;
            &nbsp;
            &nbsp;

            ${showContainedButton}

            &nbsp;
            &nbsp;
            &nbsp;

            <a href="javascript:runSearch()"><button>search</button></a>        

            <br/>
            <br/>
        `;

    } else {

        pageinfo += `

            <table class="basic-table" width="30%">
            <tr>
            <td>Search Term</td>
            <td><b>${SEARCH_TERM}</b></td>
            </tr>
            </table>

            <br/>

            <a href="javascript:runSearch()"><button>re-search</button></a>        

            &nbsp;
            &nbsp;
            &nbsp;
            &nbsp;

            <a href="javascript:clearSearch()"><button>clear</button></a>        

            <br/>
            <br/>

        `;
    }

    const hitlist = SEARCH_TERM == null ? getMainDisplayList() : getSearchHitList();
    pageinfo += getListingTable(hitlist, depthmap, cnamemap, locnamemap);


    pageinfo += `
        <br/>
        <a href="javascript:createNew()"><button>+item</button></a>
    `;

    return pageinfo;
}

function getSearchHitList()
{
    massert(SEARCH_TERM != null && SEARCH_TERM.toLowerCase() == SEARCH_TERM);

    function ishit(item) {
        return item.getShortName().toLowerCase().includes(SEARCH_TERM) || item.getNotes().toLowerCase().includes(SEARCH_TERM);
    }

    return W.getItemList("stuff_item").filter(ishit);
}

function getMainDisplayList()
{
    const hitlist = [];
    const itemlist = W.getItemList("stuff_item").sort(proxySort(getSortTuple));
    itemlist.forEach(function(item) {

        if(SHOW_CONTAINER_ID != -1 && item.getContainerId() != SHOW_CONTAINER_ID) 
            { return; }

        if(!SHOW_CONTAINED_ITEM && item.getContainerId() != -1)
            { return; }

        const locateid = getLocationId(item);
        if(SHOW_LOCATION_ID != -1 && locateid != SHOW_LOCATION_ID)
            { return; }


        hitlist.push(item);

    });

    return hitlist;


}


function getListingTable(stufflist, depthmap, cnamemap, locnamemap)
{

    var tablestr = `
        <table class="basic-table" width="70%">
        <tr>
        <th>Name</th>
        <th>Location</th>
        <th>Container</th>
        <th>Depth</th>
        <th>...</th>
        </tr>
    `;

    stufflist.forEach(function(item) {

        const itemdepth = depthmap.get(item.getId());
        const locateid = getLocationId(item);
        var locname = locateid == -1 ? "---" : W.lookupItem("stuff_loc", locateid).getLocName();

        const rowstr = `
            <tr>
            <td>${item.getShortName()}</td>
            <td>${locname}</td>
            <td>${cnamemap[item.getContainerId()]}</td>
            <td>${itemdepth}</td>            
            <td>

            <a href="javascript:editStudyItem(${item.getId()})"><img src="/u/shared/image/inspect.png" height="18"/></a>

            &nbsp;
            &nbsp;
            &nbsp;

            <a href="javascript:deleteItem(${item.getId()})"><img src="/u/shared/image/remove.png" height="18"/></a>


            </td>
            </tr>
        `;

        tablestr += rowstr;
    });

    tablestr += `
        </table>
    `;

    return tablestr;
}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<span id="main_page"></span>

</center>
</body>
</html>
