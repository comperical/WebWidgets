
<html>
<head>
<title>Record Tagger</title>

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

    const pageinfo = getMainPageInfo();

    populateSpanData({ "mainpage" : pageinfo});
}

function findNoCatList()
{
    return W.getItemList("finance_main").filter(item => item.getExpenseCat() == "uncategorized");
}


function createTagRecordInfo()
{
    alert(`
        This will tag the main records with the auto-inferred expense category.
        This may take a minute or two. Please open the javascript console
        and observe the records being created
    `);

    var tagged = 0;

    const orphanlist = findNoCatList();

    orphanlist.forEach(function(mainitem) {

        const taghits = findTagHitList(mainitem);

        if (taghits.length != 1)
            { return; }

        const category = taghits[0].getCategory();
        mainitem.setExpenseCat(category);
        mainitem.syncItem();

        tagged++;
    });


    alert(`Tagged ${tagged} records`);
    redisplay();
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
