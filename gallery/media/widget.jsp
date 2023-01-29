

<html>
<head>
<title>Media</title>

<%= DataServer.basicInclude(request) %>

<script>

EDIT_STUDY_ITEM = -1;

initGenericSelect(new Map([["category_sel", "all"]]));

function getPageComponent()
{
    return EDIT_STUDY_ITEM == -1 ? "main_display" : "edit_info";
}

function back2Main()
{
    EDIT_STUDY_ITEM = -1;
    redisplay();
}

function inspectItem(itemid)
{
    EDIT_STUDY_ITEM = itemid;
    redisplay();
}

function markItemComplete(itemid)
{
    if(!confirm("Confirm item is complete?"))
    {
        return;
    }

    const myitem = W.lookupItem("media_item", itemid);
    myitem.setIsComplete(1);
    syncSingleItem(myitem);
    redisplay();

}

function cycleItemStatus(itemid)
{
    if(!confirm("Toggle Item Active status?"))
    {
        return;
    }

    genericToggleActive("media_item", itemid);
}


function editItemName()
{
    genericEditTextField("media_item", "name", EDIT_STUDY_ITEM);
    // redisplay();
}

function editItemLink()
{
    genericEditTextField("media_item", "link", EDIT_STUDY_ITEM);
}

function editItemPriority()
{
    const myitem = W.lookupItem("media_item", EDIT_STUDY_ITEM);
    const newpri = prompt("Enter new Priority: ", myitem.getPriority());

    if(!okayInt(newpri))
    {
        alert("Please enter a valid integer");
        return;
    }

    myitem.setPriority(newpri);
    syncSingleItem(myitem);
    redisplay();
}



function editItemCategory()
{
    const newcat = getDocFormValue("item_category");
    const myitem = lookupItem("media_item", EDIT_STUDY_ITEM);
    myitem.setCategory(newcat);
    syncSingleItem(myitem);
    redisplay();
}

function getCategoryList()
{
    return ["book", "blog", "podcast", "movie", "TV show", "video", "manga", "course"];
}

function createNew()
{
    if(SELECTED_CATEGORY == "all")
    {
        alert("Please selected a specific category");
        return;
    }

    const shortname = prompt(`Enter name for new ${SELECTED_CATEGORY.toUpperCase()}: `);
    
    if(shortname)
    {        
        // created_on, active_on, completed_on, dead_line
        const newrec = {
            "name" : shortname,
            "link" : "",
            "priority" : 5,
            "category": SELECTED_CATEGORY,
            "extra_info" : "NotYetSet",
            "is_active" : 1,
            "is_complete" : 0
        };      
        
        const newitem = W.buildItem("media_item", newrec);
        newitem.syncItem();
        redisplay();
    }
}

function deleteItem(killid)
{
    if(confirm("Are you sure you want to delete this item?"))
    {
        genericDeleteItem("media_item", killid);    
    }
}

function redisplay()
{
    redisplayEdit();
    redisplayMain();
    setPageComponent(getPageComponent());
}


function redisplayEdit()
{
    if(EDIT_STUDY_ITEM == -1) {
        return;
    }

    const item = W.lookupItem("media_item", EDIT_STUDY_ITEM);


    const catsel = buildOptSelector()
                    .setKeyList(getCategoryList())
                    .setElementName("item_category")
                    .setOnChange("javascript:editItemCategory()")
                    .setSelectedKey(item.getCategory())

    const bigstr = `

        <h2>Edit Item</h2>

        <table class="basic-table"  width="50%">
        <tr>
        <td>
        Back
        </td>
        <td>
        </td>
        <td>
        <a href="javascript:back2Main()">
        <img src="/u/shared/image/leftarrow.png" height="18"/></a>
        </td>
        </tr>
        <tr>
        <td>
        Name
        </td>
        <td>
        ${item.getName()}
        </td>
        <td>
        <a href="javascript:editItemName()">
        <img src="/u/shared/image/edit.png" height="18"/></a>
        </td>        
        </tr>

        <tr>
        <td>
        Web Link
        </td>
        <td>
        ${item.getLink()}
        </td>
        <td>
        <a href="javascript:editItemLink()">
        <img src="/u/shared/image/edit.png" height="18"/></a>
        </td>        
        </tr>   

        <tr>
        <td>
        Category
        </td>
        <td colspan="2">
        ${catsel.getSelectString()}
        </td>
        </tr>   

        <tr>
        <td>
        Priority
        </td>
        <td>
        ${item.getPriority()}
        </td>
        <td>
        <a href="javascript:editItemPriority()">
        <img src="/u/shared/image/edit.png" height="18"/></a>
        </td>
        </tr>   



        </table>
    `;

    populateSpanData({
        "edit_span" : bigstr
    })
}

function updateCategory()
{
    SELECTED_CATEGORY = getDocFormValue("category_sel");
    redisplay();
}

function redisplayMain()
{


    const maintable = getTableData(0);
    const comptable = getTableData(1);

    const catlist = getCategoryList();
    catlist.push("all");
    catlist.sort(proxySort(cat => [cat.toLowerCase()]));

    const catsel = buildOptSelector()
                        .setKeyList(catlist)
                        .setElementName("category_sel")
                        .useGenericUpdater()
                        .autoPopulate();


    populateSpanData({
        "maintable" : maintable,
        "comptable" : comptable
    })

}


function getTableData(iscomplete)
{

    var mainstr = `
        <table class="basic-table" class="basic-table" width="60%">
        <tr>
        <th>Name</th>
        <th>Category</th>
        <th>Priority</th>
        <th>Active?</th>
        <th>Link</th>
        <th>...</th>
        </tr>
    `;

    var itemlist = getItemList("media_item");

    itemlist = itemlist.sort(proxySort(item => [-item.getPriority()]));

    const breaker = `&nbsp; &nbsp;`
    const selectedCat = getGenericSelectValue("category_sel")


    itemlist.forEach(function(item) {

        if(item.getIsComplete() != iscomplete)
            { return; }

        if(selectedCat != "all" && item.getCategory() != selectedCat)
            { return; }

        var linkstr = "";



        if(item.getLink().length > 0)
        {
            linkstr = `
                <a href="${item.getLink()}">
                <img src="/u/shared/image/chainlink.png" height="18"/></a>
            `
        }

        const activstr = item.getIsActive() == 1 ? "Y" : "N";

        const rowstr = `
            <tr>
            <td>${item.getName()}</td>
            <td>${item.getCategory()}</td>
            <td>${item.getPriority()}</td>
            <td>${activstr}</td>
            <td>${linkstr}</td>
            <td>

            <a href="javascript:markItemComplete(${item.getId()})">
            <img src="/u/shared/image/checkmark.png" height="18"/></a>

            ${breaker}

            <a href="javascript:cycleItemStatus(${item.getId()})">
            <img src="/u/shared/image/cycle.png" height="18"/></a>

            ${breaker}


            <a href="javascript:inspectItem(${item.getId()})">
            <img src="/u/shared/image/inspect.png" height="18"/></a>

            ${breaker}

            <a href="javascript:deleteItem(${item.getId()})">
            <img src="/u/shared/image/remove.png" height="18"/></a>



            </td>
            </tr>
        `;

        mainstr += rowstr;

    });

    mainstr += "</table>";
    return mainstr;
}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<span class="page_component" id="main_display">

<h2>Media</h2>

<span id="category_sel_span"></span>

<a href="javascript:createNew()"><button>new</button></a>

<br/>
<br/>

<div id="maintable"></div>

<h3>Completed</h3>

<div id="comptable"></div>


</span>

<span class="page_component" id="edit_info">

<div id="edit_span"></div>

</span>


<br/>



</center>
</body>
</html>
