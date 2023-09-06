<html>
<head>
<title>Mandarin Corner</title>

<%= DataServer.include(request) %>

<script src="../links/LinkDisplay.js"></script>


<script>

EDIT_STUDY_ITEM = -1;

function editStudyItem(studyid)
{
    EDIT_STUDY_ITEM = studyid;
    redisplay();
}

function back2Main()
{
    EDIT_STUDY_ITEM = -1;
    redisplay();
}

function editItemName()
{
    genericEditTextField("mandarin_corner", "short_name", EDIT_STUDY_ITEM);
}

function checkParse()
{

    const myurl = "https://www.youtube.com/watch?v=4bMVoXWd6JY&t=45s";
    console.log(parseUrlInfo(myurl));

}

function deActivateItem(itemid)
{
    setItemStatus(itemid, 0)
}

function activateItem(itemid)
{
    setItemStatus(itemid, 1);

}

function completeItem(itemid)
{
    setItemStatus(itemid, 2);
}

function setItemStatus(itemid, statcode)
{
    const myitem = W.lookupItem("mandarin_corner", itemid);
    myitem.setStatusCode(statcode);
    myitem.syncItem();
    redisplay();
}



function parseUrlInfo(theurl)
{
    const querystr = theurl.substring(theurl.indexOf("?")+1);
    console.log(querystr);


    var phash = {};
    
    var match,
        pl     = /\+/g,  // Regex for replacing addition symbol with a space
        search = /([^&=]+)=?([^&]*)/g,
        decode = function (s) { return decodeURIComponent(s.replace(pl, " ")); },
        query = querystr;

    while (match = search.exec(query))
    {
        phash[decode(match[1])] = decode(match[2]);
    }
    
    return phash;
}

function buildFullYtLink(basecode)
{
    return `https://www.youtube.com/watch?v=${basecode}`;
}


function editYouTubeLink()
{
    const userinput = prompt("Please copy and paste YT URL here: ");

    if (userinput) 
    {
        const params = parseUrlInfo(userinput);
        massert("v" in params, "Could not find a v= element in the url " + userinput);

        const myitem = W.lookupItem("mandarin_corner", EDIT_STUDY_ITEM);
        myitem.setYoutubeLink(params["v"]);
        myitem.syncItem();
        redisplay();
    }
}

function editTranslationDoc()
{
    genericEditTextField("manhua_book", "translation_doc", SELECTED_BOOK);
}

function createNew()
{
    const video = prompt("Enter name of video:");

    if(video) {

        const newrec = {
            "short_name" : video,
            "youtube_link" : "",
            "status_code" : 0,
            "word_list" : ""
        }

        const newitem = W.buildItem("mandarin_corner", newrec);
        newitem.syncItem();
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
        newitem.syncItem();
        redisplay();
    }
}



function getEditItemInfo()
{
    const myitem = W.lookupItem("mandarin_corner", EDIT_STUDY_ITEM);

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
        ${myitem.getShortName()}
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
        ${myitem.getYoutubeLink()}
        </td>
        <td>
        <a href="javascript:editYouTubeLink()">
        <img src="/u/shared/image/edit.png" height="18"/></a>
        </td>        
        </tr>   

        <tr>
        <td>
        Category
        </td>
        <td colspan="2">
        </td>
        </tr>   

        <tr>
        <td>
        Priority
        </td>
        <td>
        </td>
        <td>
        <a href="javascript:editItemPriority()">
        <img src="/u/shared/image/edit.png" height="18"/></a>
        </td>
        </tr>   



        </table>
    `;

    return bigstr;
}

function getSubTable(statusCode)
{
    var tablestr = `
        <table class="basic-table" width="60%">
        <tr>
        <th>Video</th>
        <th>Words</th>
        <th width="30%">...</th>
        </tr>
    `;

    const itemlist = W.getItemList("mandarin_corner");

    itemlist.forEach(function(item) {

        if (item.getStatusCode() != statusCode) 
            { return; }

        var rowstr = `
            <tr>
            <td>${item.getShortName()}</td>
            <td></td>
            <td>
        `

        if (item.getYoutubeLink().length > 0)
        {
            const ytlink = buildFullYtLink(item.getYoutubeLink());

            rowstr += `<a href="${ytlink}"><img src="/u/shared/image/chainlink.png" height="18"></a>`;
        } else {

            rowstr += `<img src="/u/shared/image/purewhite.png" height="18">`;
        }

        rowstr += `
                &nbsp;
                &nbsp;
                &nbsp;
        `;

        rowstr += `

            <a href="javascript:editStudyItem(${item.getId()})"><img src="/u/shared/image/inspect.png" height="18"></a>

            &nbsp;
            &nbsp;
            &nbsp;            
        `;


        if (statusCode == 1)
        {
            rowstr += `

                <a href="javascript:deActivateItem(${item.getId()})"><img src="/u/shared/image/downicon.png" height="18"></a>

                &nbsp;
                &nbsp;
                &nbsp;

                <a href="javascript:completeItem(${item.getId()})"><img src="/u/shared/image/checkmark.png" height="18"></a>

                &nbsp;
                &nbsp;
                &nbsp;                
            `;
        } else {

            rowstr += `

                <a href="javascript:activateItem(${item.getId()})"><img src="/u/shared/image/upicon.png" height="18"></a>

                &nbsp;
                &nbsp;
                &nbsp;
            `;
        }




        rowstr += `
            </td>
            </tr>
        `;

        tablestr += rowstr;

    });

    tablestr += "</table>";
    return tablestr;
}

function getMainPageInfo()
{
    var pagestr = `
        <h2>Mandarin Corner</h2>

        <br/>
        <br/>

        <a href="https://www.youtube.com/c/MandarinCorner2/videos"><button>CHANNEL</button></a>

        <h3>Active</h3>
    `;

    // active, not complete
    pagestr += getSubTable(1);

    pagestr += `
        <br/>
        <a href="javascript:createNew()"><button>new</button></a>
        <br/>
    `

    pagestr += `
        <br/>

        <h3>Waiting</h3>
    `;

    pagestr += getSubTable(0);


    pagestr += `
        <br/>

        <h3>Complete</h3>
    `;

    pagestr += getSubTable(2);

    return pagestr;
}

function redisplay()
{

    const pagestr = EDIT_STUDY_ITEM == -1 ? getMainPageInfo() : getEditItemInfo();

    populateSpanData({
        "main_page" : pagestr
    })
    /*
    populateSpanData({
        "log_table" : getLogTableData(),
        "info_table" : getInfoTable()
    });
    */
}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<span id="main_page"></span>


</center>
</body>
</html>
