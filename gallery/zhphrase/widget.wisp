

<html>
<head>
<title>Zh-Phrase Data Entry</title>

<wisp/>

<script>

var _STUDY_PHRASE = -1;


function createNew()
{
    createNewSub();
    redisplay();
}

function createNewSub()
{
    const newrec = {
        "simp_hanzi" : "...",
        "pin_yin" : "...",
        "english" : "...",
        "is_active" : 1,
        "created_on" : "...",
        "extra_info" : "..."
    };      
    
    const newitem = buildItem("short_phrase", newrec);
    newitem.syncItem();
    return newitem.getId();
}

function createAndBounce() 
{
    const newid = createNewSub();
    _STUDY_PHRASE = newid;
    redisplay();
}

function togglePhraseActive(itemid) 
{
    const item = lookupItem("short_phrase", itemid);

    if(confirm("Are you sure you want to deactivate this phrase ? ")) 
    {
        genericToggleActive("short_phrase", itemid);
        redisplay();
    }

}

function back2Main()
{
    _STUDY_PHRASE = -1;
    redisplay();
}

function studyPhrase(phraseid)
{

    _STUDY_PHRASE = phraseid;
    redisplay();
}


function redisplay()
{

    var mainstr = _STUDY_PHRASE == -1 ? composeMainList() : composeStudyView();

    populateSpanData({"main_data" : mainstr});
}

function composeStudyView()
{
    const studyitem = lookupItem("short_phrase", _STUDY_PHRASE);

    const editlink = `<img src="/u/shared/image/edit.png" height="18"/>`;

    const backlink = `<img src="/u/shared/image/leftarrow.png" height="18"/>`;

    const mainstr = `

        <h4>Edit Phrase Info</h4>

        <br/>

        <table class="basic-table" width="50%">

        <tr>
        <td>Back</td>
        <td></td>
        <td>
        <a href="javascript:back2Main()">${backlink}</a>
        </td>        
        </tr>

        <tr>
        <td>Hanzi</td>
        <td>${studyitem.getSimpHanzi()}</td>
        <td>
        <a href="javascript:genericEditTextField('short_phrase', 'simp_hanzi', ${_STUDY_PHRASE})">${editlink}</a>


        </td>        
        </tr>
        <tr>
        <td>PinYin</td>
        <td>${studyitem.getPinYin()}</td>
        <td>
        <a href="javascript:genericEditTextField('short_phrase', 'pin_yin', ${_STUDY_PHRASE})">${editlink}</a>
        </td>
        </tr>
        <tr>
        <td>English</td>
        <td>${studyitem.getEnglish()}</td>
        <td>
        <a href="javascript:genericEditTextField('short_phrase', 'english', ${_STUDY_PHRASE})">${editlink}</a>
        </td>
        </tr>
        </table>

        <br/>
        <br/>

        <a href="javascript:createAndBounce()"><button>+new</button></a>

    `;

    return mainstr;
}

function composeMainList() 
{
    var mainstr = `

        <h3>Enter Zh Phrases</h3>

        <a href="javascript:createNew()"><button>+new</button></a>
        <br/>
        <br/>

        <table class="basic-table" width="80%">
        <tr>
        <th>Hanzi</th>
        <th>PinYin</th>
        <th>English</th>
        <th width="8%">...</th>
        </tr>
    `;

    const itemlist = getItemList("short_phrase");

    itemlist.forEach(function(item) {


        if(item.getIsActive() != 1) {
            return; 
        }

        const rowstr = `
            <tr>
            <td>${item.getSimpHanzi()}</td>
            <td>${item.getPinYin()}</td>
            <td>${item.getEnglish()}</td>
            <td>

            <a href="javascript:studyPhrase(${item.getId()})">
            <img src="/u/shared/image/inspect.png" height="18"/></a>
                        
            &nbsp;
            &nbsp;
                    
            <a href="javascript:togglePhraseActive(${item.getId()})">
            <img src="/u/shared/image/cycle.png" height="18"/></a>

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


<div id="main_data"></div>


</center>
</body>
</html>
