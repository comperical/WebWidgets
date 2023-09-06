
<html>
<head>
<title>Auto Tag Rules</title>

<%= DataServer.include(request) %>

<script>

var EDIT_STUDY_ITEM = -1;

function createNew()
{

    const item = {
        "or_tags" : "",
        "and_tags" : "",
        "min_dollar" : -1,
        "max_dollar" : -1,
        "category" : "booze" // let's be real
    }

    const dbitem = W.buildItem("tag_rule", item);
    dbitem.syncItem();
    redisplay();

}

function studyItem(itemid)
{
    EDIT_STUDY_ITEM = itemid;
    redisplay();
}

function back2Main()
{
    EDIT_STUDY_ITEM = -1;
    redisplay();
}

function deleteItem(killid)
{
    genericDeleteItem("tag_rule", killid);
}


function editAndTags()
{
    genericEditTextField("tag_rule", "and_tags", EDIT_STUDY_ITEM);
}

function editMinDollar()
{
    genericEditIntField("tag_rule", "min_dollar", EDIT_STUDY_ITEM);
}

function editMaxDollar()
{
    genericEditIntField("tag_rule", "max_dollar", EDIT_STUDY_ITEM);
}

function updateCategory()
{
    const newcat = getDocFormValue("category_sel");

    const studyitem = W.lookupItem("tag_rule", EDIT_STUDY_ITEM);

    studyitem.setCategory(newcat);
    studyitem.syncItem();
    redisplay();
}


function redisplay()
{
    handleNavBar();

    const pageinfo = EDIT_STUDY_ITEM == -1 ? getMainPageInfo() : getEditPageInfo();

    populateSpanData({ "mainpage" : pageinfo});
}

function getEditPageInfo()
{
    const studyitem = W.lookupItem("tag_rule", EDIT_STUDY_ITEM);

    const optsel = buildOptSelector()
                        .setKeyList(getExpenseCategoryList())
                        .setSelectedKey(studyitem.getCategory())
                        .setOnChange("javascript:updateCategory()")
                        .setElementName("category_sel")
                        .getSelectString();

    var pageinfo = `


        <table class="basic-table" width="50%">

        <tr>
        <td></td>
        <td></td>
        <td>
        <a href="javascript:back2Main()"><img src="/u/shared/image/leftarrow.png" height="18"/></a>
        </td>

        </tr>


        <tr>
        <td>Category</td>
        <td colspan="2">
        ${optsel}
        </td>
        </tr>


        <tr>
        <td>And-Tags</td>
        <td>${studyitem.getAndTags()}</td>
        <td>
        <a href="javascript:editAndTags()"><img src="/u/shared/image/edit.png" height="18"/></a>

        </td>

        </tr>

        <tr>
        <td>Min Dollar</td>
        <td>${studyitem.getMinDollar()}</td>
        <td>
        <a href="javascript:editMinDollar()"><img src="/u/shared/image/edit.png" height="18"/></a>

        </td>

        </tr>

        <tr>
        <td>Max Dollar</td>
        <td>${studyitem.getMaxDollar()}</td>
        <td>
        <a href="javascript:editMaxDollar()"><img src="/u/shared/image/edit.png" height="18"/></a>

        </td>

        </tr>
        </table>
    `

    return pageinfo;

}


function getMainPageInfo()
{
    var pageinfo = `
        <h3>Auto Tag Rules</h3>


        <br/>
        <table class="basic-table" width="60%">
        <tr>
        <th>Category</th>
        <th>Tag String</th>
        <th>Min/Max Dollar</th>
        <th>...</th>
        </tr>
    `;

    W.getItemList("tag_rule").forEach(function(item) {

        const rowinfo = `
            <tr>
            <td>${item.getCategory()}</td>
            <td>${item.getAndTags()}</td>
            <td>${item.getMinDollar()} / ${item.getMaxDollar()}</td>
            <td>

            <a href="javascript:studyItem(${item.getId()})"><img src="/u/shared/image/inspect.png" height="18"/></a>

            &nbsp;
            &nbsp;
            &nbsp;

            <a href="javascript:deleteItem(${item.getId()})"><img src="/u/shared/image/remove.png" height="18"/></a>


            </td>
            </tr>
        `

        pageinfo += rowinfo;
    });


    pageinfo += `
        </table>

        <br/>

        <a href="javascript:createNew()"><button>+rule</button></a>

    `;

    return pageinfo;
}

function handleNavBar() 
{
    populateTopNavBar(getFinanceHeaderInfo(), "Tag Rules");
}


</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<div class="topnav"></div>

<br/>

<div id="mainpage"></div>

<br/>



</center>
</body>
</html>
