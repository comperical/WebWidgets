<%@include file="../../admin/AuthInclude.jsp_inc" %>


<html>
<head>
<title>Manhua Log</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

<script src="../links/LinkDisplay.js"></script>


<script>

function findSelectedBook()
{
    return 0;
}

function editBookName()
{
    genericEditTextField("manhua_book", "short_name", SELECTED_BOOK);
}

function editBaseLink()
{
    genericEditTextField("manhua_book", "base_link", SELECTED_BOOK);
}

function editTranslationDoc()
{
    genericEditTextField("manhua_book", "translation_doc", SELECTED_BOOK);
}

function createNewBook()
{
    const bookname = prompt("Enter name of new book:");

    if(bookname) {

        const newrec = {
            "short_name" : bookname,
            "base_link" : ""
        }

        const newitem = buildItem("manhua_book", newrec);
        newitem.registerNSync();
        redisplay();
    }

}

function deleteLogItem(itemid)
{
    lookupItem("manhua_log", itemid).deleteItem();
    redisplay();
}

function getNextChapterLink()
{
    const book = lookupItem("manhua_book", SELECTED_BOOK);
    const chaptermap = getLastChapterMap();

    const lastchapter = chaptermap[SELECTED_BOOK] || 0;
    return `${book.getBaseLink()}${lastchapter+1}`;
}


function getLastChapterMap()
{

    const loglist = getItemList("manhua_log").sort(proxySort(item => [item.getChapterId()]));

    const chapter = {};

    loglist.forEach(item => {
        chapter[item.getManhuaId()] = item.getChapterId();
    });

    return chapter;
}

function logChapter()
{
    const note = prompt("Enter note for chapter:");

    const lastchapter = getLastChapterMap();
    const newchapt = lastchapter[SELECTED_BOOK] || 0;

    if(note) {

        const newrec = {
            "chapter_desc" : note,
            "manhua_id" : SELECTED_BOOK,
            "chapter_id" : newchapt + 1,
            "day_code" : getTodayCode().getDateString()
        }

        const newitem = buildItem("manhua_log", newrec);
        newitem.registerNSync();
        redisplay();
    }
}

function getInfoTable()
{

    const book = lookupItem("manhua_book", SELECTED_BOOK);

    const nextlink = getNextChapterLink();

    const linkdisplay = getLinkDisplay(book.getTranslationDoc());


    var tablestr = `
        <table class="basic-table" width="50%">
        <tr>
        <td>Book Title</td>
        <td>${book.getShortName()}</td>
        <td>
        <a href="javascript:editBookName()"><img src="/life/image/edit.png" height="18"/></a>
        </td>
        </tr>


        <tr>
        <td>Base Link</td>
        <td>${book.getBaseLink()}</td>
        <td>
        <a href="javascript:editBaseLink()"><img src="/life/image/edit.png" height="18"/></a>
        </td>
        </tr>


        <tr>
        <td>Translation</td>
        <td><a href="${book.getTranslationDoc()}">${linkdisplay}</a></td>
        <td>
        <a href="javascript:editTranslationDoc()"><img src="/life/image/edit.png" height="18"/></a>
        </td>
        </tr>




        <tr>
        <td colspan="3"><a href="${nextlink}">Next Chapter</a></td>
        </tr>


    `;

    tablestr += "</table>";

    return tablestr;
}

function getLogTableData()
{
    var tablestr = `
        <table class="basic-table" width="50%">
        <tr>
        <th>Date</th>
        <th width="20%">Chapter</th>
        <th>Desc</th>
        <th>...</th>
        </tr>
    `;

    const loglist = getItemList("manhua_log")
                        .filter(item => item.getManhuaId() == SELECTED_BOOK)
                        .sort(proxySort(item => [item.getChapterId()]))
                        .reverse();

    loglist.forEach(item => {

        const rowstr = `
            <tr>
            <td>${item.getDayCode()}</td>
            <td>${item.getChapterId()}</td>
            <td>${item.getChapterDesc()}</td>
            <td>
            <a href="javascript:deleteLogItem(${item.getId()})"><img src="/life/image/remove.png" height="18"/></a>
            </td>
            </tr>

        `;

        tablestr += rowstr;

    })

    tablestr += "</table>";

    return tablestr;
}

function redisplay()
{

    populateSpanData({
        "log_table" : getLogTableData(),
        "info_table" : getInfoTable()
    });
}

function setupRedisplay() 
{
    SELECTED_BOOK = findSelectedBook();

    redisplay();
}

</script>

</head>

<body onLoad="javascript:setupRedisplay()">

<center>

<h2>Manhua Log</h2>

<a href="javascript:createNew()"><button>new</button></a>


<br/>
<br/>


<span id="info_table"></span>


<br/>

<a href="javascript:logChapter()"><button>log</button></a>

<br/>
<br/>

<span id="log_table"></span>






</center>
</body>
</html>
