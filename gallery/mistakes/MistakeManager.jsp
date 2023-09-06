
<html>
<head>
<title>Mistakes</title>

<%= DataServer.include(request) %>

<script src="MistakeLib.js"></script>

<script>

var EDIT_STUDY_ITEM = -1;


const DUMMY_TAG = "---";

var SELECTED_FILTER_TAG = DUMMY_TAG;

var SEARCH_STRING = "";

var SELECTED_STATUS_CODE = DUMMY_TAG;

function handleNavBar() 
{
    populateTopNavBar(getHeaderInfo(), "Mistake Manager");
}

function redisplay()
{
    handleNavBar();

    const pageinfo = EDIT_STUDY_ITEM == -1 ? getMainTableInfo() : getEditItemInfo();

    populateSpanData({"mainpage" : pageinfo});
}

function okaySearchAccept(item)
{
    if (SEARCH_STRING.length == 0)
        { return true; }

    function lcsearch(mystr) {
        return mystr.toLowerCase().includes(SEARCH_STRING.toLowerCase());
    }

    return lcsearch(item.getShortDesc()) || lcsearch(item.getExtraInfo());
}

function filterTagUpdate()
{
    SELECTED_FILTER_TAG = getDocFormValue("filter_tag_sel");
    redisplay();
}

function statusCodeUpdate()
{
    SELECTED_STATUS_CODE = getDocFormValue("status_code_sel");
    redisplay();
}

function runStringSearch()
{
    const searchstr = prompt("Enter a search string:");

    if(searchstr)
    {
        SEARCH_STRING = searchstr;
        redisplay();
    }
}

function clearSearch()
{
    SEARCH_STRING = "";
    redisplay();
}


function getMainTableInfo()
{

    const mistlist = getItemList("incident");
    mistlist.sort(proxySort(a => [a.getDayCode()])).reverse();

    const tagoptlist = [DUMMY_TAG].concat(getTagUniverse())
    
    const tagselstr = buildOptSelector()
                            .setKeyList(tagoptlist)
                            .setElementName("filter_tag_sel")
                            .setSelectedKey(SELECTED_FILTER_TAG)
                            .setOnChange("javascript:filterTagUpdate()")
                            .getSelectString();


    const statselstr = buildOptSelector()
                            .setKeyList([DUMMY_TAG].concat(STATUS_CODE_LIST))
                            .setElementName("status_code_sel")
                            .setSelectedKey(SELECTED_STATUS_CODE)
                            .setOnChange("javascript:statusCodeUpdate()")
                            .getSelectString();


    const searchstr = SEARCH_STRING.length == 0 ? "" : `Search: <b>${SEARCH_STRING.toLowerCase()}</b><br/>`;                           

    var tablestr = `

        Tag: ${tagselstr}

        <br/>

        Status: ${statselstr}


        <br/>
        ${searchstr}

        <a href="javascript:runStringSearch()"><button>search</button></a>

        &nbsp;

        <a href="javascript:clearSearch()"><button>clear</button></a>

        <br/>
        <br/>

    `;



    tablestr += `
        <table class="basic-table"  width="80%">
        <tr>
        <th width="7%">Date</th>
        <th>Name</th>
        <th>Status</th>
        <th>Sev'ty</th>
        <th>Tags</th>        
        <th>Desc</th>
        <th>Op</th>
        </tr>
    `;





    mistlist.forEach(function(item) {
                
        const taglist = tagListFromItem(item);
        const tagstr = taglist.join(", ");

        if (SELECTED_FILTER_TAG != DUMMY_TAG && !taglist.includes(SELECTED_FILTER_TAG)) 
            { return; }

        // Filter out non-selected status items
        if (SELECTED_STATUS_CODE != DUMMY_TAG && item.getStatusCode() != SELECTED_STATUS_CODE)
            { return; }

        if (!okaySearchAccept(item)) 
            { return; }

        const rowstr = `
            <tr>
            <td>${item.getDayCode().substring(5)}</td>  
            <td>${item.getShortDesc()}</td>
            <td>${item.getStatusCode()}</td>
            <td>${item.getSeverity()}</td>
            <td>${taglist}</td>            
            <td width="40%">${getBasicMistakeDesc(item)}</td>
            <td width="10%">
                <a href="javascript:editStudyItem(${item.getId()})">
                <img src="/u/shared/image/inspect.png" height=18"/></a>
                
                &nbsp; &nbsp; &nbsp;
                
                <a href="javascript:deleteItem(${item.getId()}, '${item.getShortDesc()}')">
                <img src="/u/shared/image/remove.png" height="18"/></a>
            </td>
            </tr>
        `

        tablestr += rowstr;
    });

    tablestr += "</table>";

    const searchinfo = SEARCH_STRING.length == 0 ? "" : `
        Search: <b>${SEARCH_STRING.toLowerCase()}</b>
    `;

    return tablestr;
}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<span class="page_component" id="maintable_cmp">

<div class="topnav"></div>

<br/>
<br/>

<div id="mainpage"></div>

</center>
</body>
</html>
