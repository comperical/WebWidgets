<html>
<head>

<title>Search Shared</title>

<wisp/>

<script src="/u/shared/optjs/SimpleTag/v1.js"></script>

<script>

var EDIT_STUDY_ITEM = -1;


const TAG_SEARCH_KEY = "TagSearchKey";

const YEAR_SEL_KEY = "YearSelKey";

const CODE_TO_NAME_MAP = {
    "D" : "Dan",
    "H" : "Heather"
}

GENERIC_OPT_SELECT_MAP.set(TAG_SEARCH_KEY, "---");

GENERIC_OPT_SELECT_MAP.set(YEAR_SEL_KEY, "---");

var SEARCH_TERM = null;

function deleteItem(itemid) {
    const item = W.lookupItem('shared_expense', itemid)
    item.deleteItem();
    redisplay();
}

function isPayerDan(payer)
{
    massert(["D", "H"].indexOf(payer) > -1, "Invalid payer name " + payer);
    return payer == "D";
}

function togglePayer()
{
    togglePayerSub(EDIT_STUDY_ITEM);
}

function togglePayerSub(itemid)
{
    const item = W.lookupItem("shared_expense", itemid);
    const isdan = isPayerDan(item.getPayer());
    item.setPayer(isdan ? "H" : "D");
    item.syncItem();
    redisplay();

}

function getSearchItemList()
{

    const tagtarget = GENERIC_OPT_SELECT_MAP.get(TAG_SEARCH_KEY);
    const yeartarget = GENERIC_OPT_SELECT_MAP.get(YEAR_SEL_KEY);


    const hit = function(item)
    {
        if(SEARCH_TERM != null)
        {
            const notes = item.getNotes().toLowerCase();
            if(!notes.includes(SEARCH_TERM.toLowerCase()))
                { return false; }
        }

        if(tagtarget != "---")
        {
            const itemset = TAG.getItemTagSet(item);
            if(!itemset.has(tagtarget))
                { return false; }
        }

        if(yeartarget != "---")
        {
            if(!item.getDayCode().startsWith(yeartarget))
                { return false; }

        }

        return true;
    }


    return W.getItemList("shared_expense").filter(hit);
}

function getSummaryTable()
{

    const totalpay = new Map();
    totalpay.set("D", 0);
    totalpay.set("H", 0);

    const itemlist = getSearchItemList();

    itemlist.forEach(function(item) {
        const prev = totalpay.get(item.getPayer());
        totalpay.set(item.getPayer(), prev + (1 * item.getDollarAmount()));
    });

    var tableinfo = `

        <table class="basic-table" width="40%">

        <tr>
        <th colspan="2">Summary</th>
        </tr>

        <tr>
        <td width="60%">Dan Paid:</td>
        <td>${totalpay.get("D")}</td>
        </tr>

        <tr>
        <td>Heather Paid:</td>
        <td>${totalpay.get("H")}</td>
        </tr>

        </table>
    `;

    return tableinfo;
}

function clearSearch()
{
    SEARCH_TERM = null;
    redisplay();
}

function runSearch()
{
    SEARCH_TERM = prompt("Please enter a search term:");
    redisplay();
}

function getSearchTable()
{

    const alltagset = TAG.getCompleteTagSet(W.getItemList("shared_expense"));
    const tagselector = buildOptSelector()
                            .configureFromList([... alltagset])
                            .sortByDisplay()
                            .setElementName(TAG_SEARCH_KEY)
                            .insertStartingPair("---", "---")
                            .useGenericUpdater()
                            .getHtmlString();


    const yearlist = [... Array(4).keys()].map(idx => 2025-idx+3);
    const yearselector = buildOptSelector()
                            .configureFromList(yearlist)
                            .setElementName(YEAR_SEL_KEY)
                            .insertStartingPair("---", "---")
                            .useGenericUpdater()
                            .getHtmlString();



    var pageinfo = `
        <table class="basic-table" width="30%">


        <tr>
        <td>Tag</td>
        <td>${tagselector}</td>
        </tr>


        <tr>
        <td>Year</td>
        <td>${yearselector}</td>
        </tr>

    `;

    if(SEARCH_TERM != null) {
        pageinfo += `
            <tr>
            <td>${SEARCH_TERM}</td>
            <td><a href="javascript:clearSearch()"><button>clear</button></a></td>
            </tr>
        `;
    } else {

        pageinfo += `
            <tr>
            <td colspan="2">
            <a href="javascript:runSearch()"><button>search</button></a>
            </td>
            </tr>
        `;


    }

    pageinfo += `
        </table>
    `

    return pageinfo;

}


// Auto-generated redisplay function
function editStudyItem(itemid) {
    EDIT_STUDY_ITEM = itemid;
    redisplay();
}

function back2Main() {
    EDIT_STUDY_ITEM = -1;
    redisplay();
}

function updateItemDate()
{
    const newdate = U.getDocFormValue("day_code_selector");
    const item = W.lookupItem("shared_expense", EDIT_STUDY_ITEM);
    item.setDayCode(newdate);
    item.syncItem();
    redisplay();
}

function shorten4Display(ob) {
    const s = '' + ob;
    if(s.length < 40) { return s; }
    return s.substring(0, 37) + '...';
}

// Auto-generated redisplay function
function redisplay() {

    handleSharedNavBar("Search Shared");

    const pageinfo = EDIT_STUDY_ITEM == -1 ? getMainPageInfo() : getEditPageInfo();
    U.populateSpanData({"page_info" : pageinfo });
}


// Auto-generated getMainPageInfo function
function getMainPageInfo() {


    var pageinfo = `

        <br/>
        <br/>


        ${getSummaryTable()}

        <br/>
        ${getSearchTable()}

        <br/>
    `;

    pageinfo += `
        <table class="basic-table" width="80%">
        <tr>
        <th>Date</th>
        <th>Amount</th>
        <th>payer</th>
        <th>notes</th>
        <th>tags</th>
        <th>..</th></tr>
    `

    const itemlist = getSearchItemList().sort(U.proxySort(item => [item.getDayCode()])).reverse();

    itemlist.forEach(function(item) {
        const rowstr = `
            <tr>
            <td>${shorten4Display(item.getDayCode())}</td>
            <td>${shorten4Display(item.getDollarAmount())}</td>
            <td>${CODE_TO_NAME_MAP[item.getPayer()]}</td>
            <td>${shorten4Display(item.getNotes())}</td>
            <td width="5%">${TAG.getTagSetDisplay(item, "&nbsp;/&nbsp;")}</td>
            <td>
            <a href="javascript:deleteItem(${item.getId()})"><img src="/u/shared/image/remove.png" height="16"/></a>
            </td>
            </tr>
        `;
        pageinfo += rowstr;
    });

    pageinfo += `</table>`;
    return pageinfo;
}

</script>
<body onLoad="javascript:redisplay()">
<center>
<div class="topnav"></div>



<div id="page_info"></div>

</center>
</body>
</html>
