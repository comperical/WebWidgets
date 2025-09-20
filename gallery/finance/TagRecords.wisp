
<html>
<head>
<title>Record Tagger</title>

<wisp/>

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
    U.genericDeleteItem("tag_rule", killid);
}


function editAndTags()
{
    U.genericEditTextField("tag_rule", "and_tags", EDIT_STUDY_ITEM);
}

function editMinDollar()
{
    U.genericEditIntField("tag_rule", "min_dollar", EDIT_STUDY_ITEM);
}

function editMaxDollar()
{
    U.genericEditIntField("tag_rule", "max_dollar", EDIT_STUDY_ITEM);
}

function updateCategory()
{
    const newcat = U.getDocFormValue("category_sel");

    const studyitem = W.lookupItem("tag_rule", EDIT_STUDY_ITEM);

    studyitem.setCategory(newcat);
    studyitem.syncItem();
    redisplay();
}


function redisplay()
{
    handleNavBar();

    const pageinfo = getMainPageInfo();

    U.populateSpanData({ "mainpage" : pageinfo});
}

function findNoCatList()
{
    return W.getItemList("finance_main").filter(item => item.getExpenseCat() == "uncategorized");
}


function confirmUpdate(tablename, idlist, __)
{
    alert(`Bulk update of ${idlist.length} records complete`);
    redisplay();
}

function createTagRecordInfo()
{
    const modlist = [];
    const orphanlist = findNoCatList();

    orphanlist.forEach(function(mainitem) {

        const taghits = findTagHitList(mainitem);

        if (taghits.length != 1)
            { return; }

        const category = taghits[0].getCategory();
        mainitem.setExpenseCat(category);
        modlist.push(mainitem.getId());
    });

    W.bulkUpdate("finance_main", modlist, {"callback" : confirmUpdate });

}

function getMainPageInfo()
{
    var pageinfo = `
        <h3>Record Tagger</h3>

        <a href="javascript:createTagRecordInfo()"><button>autotag</button></a>

        <br/>

        <br/>
        <table class="basic-table" width="80%">
        <tr>
        <th>ID</th>
        <th>Description</th>
        <th>Amount</th>
        <th>Log Source</th>
        <th>Candidate</th>
        <th>...</th>
        </tr>
    `;


    const orphanlist = findNoCatList();

    orphanlist.forEach(function(item) {

        const taghits = findTagHitList(item);

        if(taghits.length == 0)
            { return; }

        const candstr = taghits.length > 0 ? taghits.map(tag => tag.getCategory()).join(",") : "----";

        const dollar = (item.getCentAmount() / 100).toFixed(2);

        const rowstr = `

            <tr>
            <td>${item.getTransactDate()}</td>
            <td>${item.getFullDesc()}</td>
            <td>${dollar}</td>
            <td>${item.getLogSource()}</td>
            <td>${candstr}</td>
            <td></td>
            </tr>
        `

        pageinfo += rowstr;

    })


    pageinfo += `
        </table>

        <br/>

        <a href="javascript:createNew()"><button>+rule</button></a>

    `;

    return pageinfo;
}

function handleNavBar() 
{
    populateTopNavBar(getFinanceHeaderInfo(), "Tagger");
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
