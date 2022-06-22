
<html>
<head>
<title>Stuff Manager</title>

<%= DataServer.basicInclude(request) %>

<script>

var EDIT_STUDY_ITEM = -1;

var SHOW_CONTAINER_ID = -1;

function createNew()
{
    const itemname = prompt("Enter name of item: ");

    if(itemname) 
    {
        const newrec = {
            "container_id" : -1,
            "is_container" : 0,
            "short_name" : itemname,
            "notes" : ""
        }

        const newitem = W.buildItem("stuff_item", newrec);
        newitem.syncItem();
        redisplay();
    }
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

function editItemName()
{
    genericEditTextField("stuff_item", "short_name", EDIT_STUDY_ITEM);

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

function updateContainer()
{
    const containid = getDocFormValue("container_sel");
    const item = W.lookupItem("stuff_item", EDIT_STUDY_ITEM);
    item.setContainerId(containid);
    item.syncItem();
    redisplay();
}

function updateShowContainer()
{
    SHOW_CONTAINER_ID = getDocFormValue("show_container_sel");
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
        <td>${cnamemap[item.getContainerId()]}</td>
        <td>${contsel}</td>
        </tr>
        <tr>
        <td><b>Is Container?</b></td>
        <td>${iscont}</td>
        <td><a href="javascript:toggleContainer()"><img src="/u/shared/image/cycle.png" height="18"/></a></td>
        </tr>
        </table>
    `;

    return pageinfo;
}

function getMainListing()
{

    const cnamemap = getContainerNameMap();

    const showContainer = buildOptSelector()
                        .setFromMap(cnamemap)
                        .setSelectedKey(SHOW_CONTAINER_ID)
                        .setElementName("show_container_sel")
                        .setOnChange("javascript:updateShowContainer()")
                        .getSelectString();


    var pageinfo = `

        <h3>Stuff Manager</h3>

        <br/>

        <a href="javascript:createNew()"><button>+item</button></a>

        <br/>
        <br/>

        Container: ${showContainer}
        <br/>
        <br/>

        <table class="basic-table" width="50%">
        <tr>
        <th>ID</th>
        <th>Name</th>
        <th>Container</th>
        <th>...</th>
        </tr>
    `;


    W.getItemList("stuff_item").forEach(function(item) {

        if(SHOW_CONTAINER_ID != -1 && item.getContainerId() != SHOW_CONTAINER_ID) 
            { return; }


        const rowstr = `
            <tr>
            <td>${item.getId()}</td>
            <td>${item.getShortName()}</td>
            <td>${cnamemap[item.getContainerId()]}</td>
            <td>

            <a href="javascript:editStudyItem(${item.getId()})"><img src="/u/shared/image/inspect.png" height="18"/></a>

            &nbsp;
            &nbsp;
            &nbsp;

            <a href="javascript:deleteItem(${item.getId()})"><img src="/u/shared/image/remove.png" height="18"/></a>


            </td>
            </tr>
        `;

        pageinfo += rowstr;
    })

    pageinfo += "</table>";

    return pageinfo;


}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<span id="main_page"></span>

</center>
</body>
</html>
