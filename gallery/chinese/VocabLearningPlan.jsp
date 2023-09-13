

<html>
<head>
<title>Vocab Learning Schedule</title>

<%= DataServer.include(request, "tables=palace_item,hanzi_data,learning_schedule,word_memory") %>

<%= DataServer.include(request, "widgetname=hanyu&tables=hsk_vocab_info") %>

<script src="../hanyu/pin_yin_converter.js"></script>

<script>

const HSK_LEVEL_KEY = "HsKLeVel";

const HAVE_CHAR_KEY = "HaVEChaR";

const WORD_PRESENT_KEY = "WordPReSEnt";

// Gotcha, if you try to hardcode this, it won't work
// var CHARACTER_SEARCH = "爱";
var CHARACTER_SEARCH = null;


const SHOW_WORD_LIMIT = 20;

GENERIC_OPT_SELECT_MAP.set(HSK_LEVEL_KEY, 5);

GENERIC_OPT_SELECT_MAP.set(HAVE_CHAR_KEY, "all");

GENERIC_OPT_SELECT_MAP.set(WORD_PRESENT_KEY, "no");


var __VOCAB_STUDY_MAP = null;

function handleNavBar() 
{
    populateTopNavBar(getPlanningHeader(), "Vocab Learning");
}

// Hanzi word -> ID
function getVocabStudyMap()
{
    if(__VOCAB_STUDY_MAP == null)
    {
        __VOCAB_STUDY_MAP = new Map();

        W.getItemList("word_memory").forEach(function(item) {
            __VOCAB_STUDY_MAP.set(item.getSimpHanzi(), item.getId());
        });
    }

    return __VOCAB_STUDY_MAP;
}

function addPalaceItem(charid)
{

    const charitem = W.lookupItem("hanzi_data", charid);

    // <td>${charitem.getHanziChar()}</td>
    // <td>${charitem.getPinYin()}</td>

    const mssg = `
        Going to add a palace item for ${charitem.getHanziChar()}

        Character will disappear from this screen, but will be present in character list

        Okay to proceed?
    `;

    if(confirm(mssg))
    {
        const newrec = {
            "hanzi_char" : charitem.getHanziChar(),
            "palace_note": "NotYetSet",
            "extra_note" : "...",
            "is_active" : 1,
            "meaning": charitem.getDefinition()
        };      
        
        clearHanziDataCache();

        const newitem = W.buildItem("palace_item", newrec);
        newitem.syncItem();
        redisplay();
    }
}

function getHaveCharList(vocabword)
{
    return [... vocabword].filter(char => lookupPalaceItemByChar(char) != null)
}

function getHaveCharCount(vocabword)
{
    return getHaveCharList(vocabword).length;
}

function clearCharacterSearch()
{
    CHARACTER_SEARCH = null;
    redisplay();
}

function runCharacterSearch()
{
    const charsearch = prompt("Enter character to search for: ");

    if(charsearch)
    {
        CHARACTER_SEARCH = charsearch;
        redisplay();
    }

}

function getVocabTargetList()
{
    const search_hit = function(item)
    {
        const p1list = [item.getSimpHanzi(), item.getEnglishNotes(), item.getPinyin()].filter(s => s.includes(CHARACTER_SEARCH));

        if(p1list.length > 0)
            { return true; }

        const convpy = PinyinConverter.convert(item.getPinyin());

        //console.log(`converted search term is ${PinyinConverter.convert(CHARACTER_SEARCH)}, word is ${convpy}`)

        return convpy.includes(CHARACTER_SEARCH) 
                || removeDiacritics(convpy).includes(CHARACTER_SEARCH)
                // || PinyinConverter.convert(CHARACTER_SEARCH).includes(convpy);
    }

    if(CHARACTER_SEARCH != null)
    {
        // This SHORT-CIRCUITS the other select options
        return W.getItemList("hsk_vocab_info").filter(search_hit);
    }


    const havechar = GENERIC_OPT_SELECT_MAP.get(HAVE_CHAR_KEY);
    const charfilter = function(vocabitem)
    {
        const charcount = getHaveCharCount(vocabitem.getSimpHanzi());
        if(havechar == "---")
            { return true; }

        if(havechar == "some")
            { return charcount > 0; }

        if(havechar == "all")
            { return charcount == vocabitem.getSimpHanzi().length; }

        if(havechar == "none")
            { return charcount == 0; }

        massert(false, "Unknown have char code " + havechar);
    }


    const wantpresent = GENERIC_OPT_SELECT_MAP.get(WORD_PRESENT_KEY);

    const prezfilter = function(vocabitem)
    {

        if(wantpresent == "---")
            { return true; }

        const present = getVocabStudyMap().has(vocabitem.getSimpHanzi());

        if(wantpresent == "yes")
            { return present; }

        if(wantpresent == "no")
            { return !present; }

        massert(false, "Unknown character present code " + wantpresent);
    }


    const targetlevel = parseInt(GENERIC_OPT_SELECT_MAP.get(HSK_LEVEL_KEY));

    return W.getItemList("hsk_vocab_info")
                        .filter(item => item.getHskLevel() == targetlevel)
                        .filter(item => item.getSimpHanzi().length > 1)
                        .filter(prezfilter)
                        .filter(charfilter);

}

function getCharSearchBlock()
{
    var block = `
        <table class="basic-table" width="30%">
        <tr>
        <td>Search</td>
    `;

    if(CHARACTER_SEARCH == null) 
    {
        block += `
            <td>
            <a href="javascript:runCharacterSearch()"><button>run</button></a>
            </td>
        `;
    } else {

        block += `
            <td>
            ${CHARACTER_SEARCH}

            &nbsp;
            &nbsp;
            &nbsp;
            &nbsp;

            <a href="javascript:clearCharacterSearch()"><button>clear</button></a>
            </td>
        `;

    }


    block += `
        </tr>
        </table>
    `

    return block;

}


function generateVocabTableInfo()
{

    const targetlist = getVocabTargetList();
    const showlist = targetlist.slice(0, SHOW_WORD_LIMIT);


    const levelsel = buildOptSelector()
                        .setKeyList([1,2,3,4,5,6])
                        .setElementName(HSK_LEVEL_KEY)
                        .useGenericUpdater()
                        .getSelectString();


    const charsel = buildOptSelector()
                        .setKeyList(["---", "none", "some", "all"])
                        .setElementName(HAVE_CHAR_KEY)
                        .useGenericUpdater()
                        .getSelectString();


    const prezsel = buildOptSelector()
                        .setKeyList(["---", "yes", "no"])
                        .setElementName(WORD_PRESENT_KEY)
                        .useGenericUpdater()
                        .getSelectString();


    var tablestr = `
        <h3>Vocab Items</h3>


        <br/>
        ${getCharSearchBlock()}
        <br/>

        <br/>
        HSK Level: ${levelsel} 

        &nbsp;
        &nbsp;
        &nbsp;
        &nbsp;

        Have Characters: ${charsel}

        &nbsp;
        &nbsp;
        &nbsp;
        &nbsp;

        Have Word: ${prezsel}        
        <br/>

        <br/>


        <table  class="basic-table" width="60%">
        <tr>
        <th>Word</th>
        <th>PinYin</th>
        <th>HSK Level</th>
        <th>Notes</th>
        <th>Have Chars</th>        
        <th>Present?</th>
        <th>Add Link</th>
        </tr>
    `;


    showlist.forEach(function(vocabitem) {


        const pinyinstr = PinyinConverter.convert(vocabitem.getPinyin());

        const present = getVocabStudyMap().has(vocabitem.getSimpHanzi()) ? "Y" : "N";

        // const addlink = opcode=allsearch&search_term=danburfoot

        const addlink = `/u/dburfoot/hanyu/WordSearch.jsp?opcode=allsearch&search_term=${vocabitem.getSimpHanzi()}`;

        const havechars = getHaveCharList(vocabitem.getSimpHanzi());


        const rowstr = `
            <tr>
            <td>${vocabitem.getSimpHanzi()}</td>
            <td>${pinyinstr}</td>
            <td>${vocabitem.getHskLevel()}</td>
            <td>${vocabitem.getEnglishNotes()}</td>
            <td>${havechars}</td>
            <td>${present}</td>
            <td>
            <a href="${addlink}"><img src="/u/shared/image/chainlink.png" height="16"/></a>
            </td>
            </tr>
        `;


        tablestr += rowstr;
    });


    tablestr += `
        <tr>
        <td colspan="7">
        Showing <b>${showlist.length}</b> out of <b>${targetlist.length}</b> words for filter
        </td>
    `;




    tablestr += "</table>";
    return tablestr;
}



function redisplay()
{
    handleNavBar();

    populateSpanData({
        "vocabtable" : generateVocabTableInfo()
    })
}



</script>




</head>

<body onLoad="javascript:redisplay()">

<center>

<div class="topnav"></div>

<br/>
<div id="vocabtable"></div>


<br/>

</center>
</body>
</html>
