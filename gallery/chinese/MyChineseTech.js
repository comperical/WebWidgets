

function getMeaningList(meanstr)
{
	return meanstr.split(";");
}

function getFirstPalaceNote(palacestr)
{
	return palacestr.split("\n")[0];	
}

/// These are no longer used
REVIEW_PROBS_KNOWN = { "easy" : 0.49, "good" : 0.50, "bad" : 0.01 };

REVIEW_PROBS_MARGINAL = { "easy" : 0.1, "good" : 0.2, "bad" : 0.7 };

PRIOR_PROB_GOOD = 0.1;

// This is the big parameter that controls the half-life of a review result.
// After N days, the impact of a review will fall in half.
HALF_LIFE_OF_RESULT = 45;

REVIEW_DECAY_PARAM = Math.log(0.5)/HALF_LIFE_OF_RESULT;



// As of Feb 2020, the NetScores seem to be distributed around -0.5 to 5, 
// with most being around 3. 
// JITTER_SCALE = 2.0
// JITTER_SCALE = 0.0;

PROB_JITTER_SCALE = 0.00;
// PROB_JITTER_SCALE = 0.05;

__HANZI_DATA_BY_CHAR = null;

__CONFOUNDER_INDEX = null;

__PHONETIC_LINK_IDX = null;


// Simp Hanzi Word to vocab item
__WORD2_VOCAB_ITEM = null;

function getConfounderIndex()
{
	if(__CONFOUNDER_INDEX == null)
	{
        __CONFOUNDER_INDEX = getCharIndexSub("confounder");
	}

	return __CONFOUNDER_INDEX;
}

function getPhoneticLinkIndex()
{
    if(__PHONETIC_LINK_IDX == null)
    {
        __PHONETIC_LINK_IDX = getCharIndexSub("phonetic_link");
    }

    return __PHONETIC_LINK_IDX;
}

function getCharIndexSub(chartable)
{
    const charidx = {}

    W.getItemList(chartable).forEach(function(conf) {

        const charlist = [conf.getLeftChar(), conf.getRghtChar()];

        charlist.forEach(function(char) {

            if(!(char in charidx)) 
                { charidx[char] = []; }

            charidx[char].push(conf);

        });
    });

    return charidx;
}



function lookupHanziDataByChar(hanzichar)
{
	if(__HANZI_DATA_BY_CHAR == null)
	{
		console.log("Rebuilding hanzi data -> char map");
		__HANZI_DATA_BY_CHAR = {}
		W.getItemList("hanzi_data").forEach(function(hditem) {
			__HANZI_DATA_BY_CHAR[hditem.getHanziChar()] = hditem.getId();	
		});
	}
	
	const foundid = __HANZI_DATA_BY_CHAR[hanzichar];	
	return W.lookupItem("hanzi_data", foundid);
}

__PALACE_ITEM_BY_CHAR = null;

function lookupPalaceItemByChar(hanzichar)
{
	if(__PALACE_ITEM_BY_CHAR == null)
	{
		console.log("Rebuilding palace data -> char map");
		__PALACE_ITEM_BY_CHAR = {}
		W.getItemList("palace_item").forEach(function(hditem) {
			__PALACE_ITEM_BY_CHAR[hditem.getHanziChar()] = hditem.getId();	
		});
	}
	
	const foundid = __PALACE_ITEM_BY_CHAR[hanzichar];	
	return foundid == null ? null : W.lookupItem("palace_item", foundid);
}

function lookupVocabItemFromWord(hanziword)
{
    if(__WORD2_VOCAB_ITEM == null)
    {
        console.log("Rebuilding palace data -> char map");
        __WORD2_VOCAB_ITEM = {}
        W.getItemList("word_memory").forEach(function(item) {
            __WORD2_VOCAB_ITEM[item.getSimpHanzi()] = item.getId();  
        });
    }
    
    const foundid = __WORD2_VOCAB_ITEM[hanziword];   
    return foundid == null ? null : W.lookupItem("word_memory", foundid);
}


function clearHanziDataCache() 
{
	__PALACE_ITEM_BY_CHAR = null;
	__HANZI_DATA_BY_CHAR = null;
	__CONFOUNDER_INDEX = null;
}


// Remove the stupid CL:... info from the CEDICT strings
function removeClCruft(engstr)
{
	const items = engstr.split("/").filter(t => !t.startsWith("CL"));
	return items.join("/");
}


function singleReviewItemScore(reviewitem)
{
	const rescode = reviewitem.getResultCode();
	
	massert(rescode in REVIEW_PROBS_KNOWN);

	const baseratio = REVIEW_PROBS_KNOWN[rescode] / REVIEW_PROBS_MARGINAL[rescode];
	
	// Look up the daycode of the item.
	const daytimestr = reviewitem.getTimeStamp().substring(0, 10);
	const itemdate = lookupDayCode(daytimestr);
	massert(itemdate != undefined, "Failed to find day time string " + daytimestr);	

	// Number of days since review:
	const ageindays = itemdate.daysUntil(getTodayCode());
	const decayfactor = Math.exp(ageindays * REVIEW_DECAY_PARAM);
	
	// This term goes from baseratio at T=0 to 1 at T->infinity
	const fullterm = (1 + (baseratio - 1) * decayfactor);
	
	// So this term goes from +/- significant number at T=0 to 0 at T->infinity
	return Math.log(fullterm);
}

// Parse CEDict format record into lines
// Also remove CL tags
function parseCedictDef(cedict)
{
	const records = cedict.split("/").filter(r => r.trim());	
	return records.filter(r => r.length > 0 && !r.startsWith("CL"));
}


function bayesianUpdate(ritem)
{
    const rescode = ritem.getResultCode();
    massert(["easy", "good", "bad"].includes(rescode), "Bad review code: " +rescode);

    const badresult = (rescode == "bad"); // treat good and easy in the same way
    
    // Look up the daycode of the item.
    // Calculate number of days since review.    
    const daytimestr = ritem.getTimeStamp().substring(0, 10);
    const itemdate = lookupDayCode(daytimestr);
    massert(itemdate != undefined, "Failed to find day time string " + daytimestr); 
    var ageindays = itemdate.daysUntil(getTodayCode());
    ageindays = ageindays == 0 ? 1 : ageindays; // 0 result here will give P=1 below
    
    // This is the probability that the current status agrees with the result.
    const probagree = 0.5 * (1 + Math.exp(ageindays * REVIEW_DECAY_PARAM));

    const probgood = badresult ? 1 - probagree : probagree;
    return [probgood, 1-probgood];
}


function fullBuildBayesStatMap(itemtable, logtable)
{
    const palacelist = W.getItemList(itemtable).filter(item => item.getIsActive() == 1);
    const reviewlist = W.getItemList(logtable).sort(proxySort(item => [item.getTimeStamp()]));


    const statmap = new Map();
    
    palacelist.forEach(function(pitem) {
        var statpack = new Object();
        statpack["num_review"] = 0;
        statpack["log_prob_good"] = Math.log(PRIOR_PROB_GOOD);
        statpack["log_prob_badd"] = Math.log(1 - PRIOR_PROB_GOOD);
        statpack["last_review"] = "2000";
        statmap.set(pitem.getId(), statpack);                   
    });
    
    reviewlist.forEach(function(ritem) {
        updateStatFromReview(statmap, ritem);
    });

    palacelist.forEach(function(pitem) {
        reComputeFinalProb(statmap, pitem.getId());
    });    

    return statmap;
}

function updateStatFromReview(statMap, reviewItem) {

    // This is an FKEY error            
    if(!statMap.has(reviewItem.getItemId()))
        { return; }
    
    const goodbadd = bayesianUpdate(reviewItem);    
    const myitem = statMap.get(reviewItem.getItemId());
    // console.log("Update Good/Badd is " + goodbadd);
    
    // Sort by review timestamp
    myitem["last_review"] = reviewItem.getTimeStamp();
    myitem["num_review"] += 1;

    myitem["log_prob_good"] += Math.log(goodbadd[0]);
    myitem["log_prob_badd"] += Math.log(goodbadd[1]);
}

function reComputeFinalProb(statMap, palaceId) {

    const statpack = statMap.get(palaceId);

    // These are unnormalized.
    var probgood = Math.exp(statpack["log_prob_good"]);
    var probbadd = Math.exp(statpack["log_prob_badd"]);

    massert(0 < probgood && probgood < 1, "Bad value for good prob: " + probgood);
    massert(0 < probbadd && probbadd < 1, "Bad value for badd prob: " + probbadd);
    //  && 0 < probbadd && probbadd < 1);
    const partfunc = probgood + probbadd;

    probgood /= partfunc;
    probbadd /= partfunc;

    statpack["prob_good"] = probgood;
    statpack["prob_badd"] = probbadd;

    statpack["base_score"] = probgood;
    statpack["net_score"] = probgood + (Math.random() - 0.5) * PROB_JITTER_SCALE;
}




function stripDiacritics(pinyin)
{
	return pinyin.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}


// Map of days ago -> cumulative review items
function getPalaceProgress(tablename)
{
	var tracker = getTodayCode();
	var daysago = 0;
	
	var progmap = {};
	var curtotal = 0;
	
	var reviewlist = W.getItemList(tablename);
	reviewlist.sort(proxySort(r => [r.getTimeStamp()])).reverse();

	reviewlist.forEach(function(ritem) {
		
		// Should really just filter...
		if(daysago > 90)
			{ return; }
			
		const subday = ritem.getTimeStamp().substring(0, "2020-01-01".length);		
		// console.log(subday);
		curtotal += 1;
			
		while(tracker.getDateString() != subday) {
			// Mark this result.
			progmap[daysago] = curtotal;
			
			tracker = tracker.dayBefore();
			daysago += 1;
		}
		
	});
	
	// Not clear if this is required
	progmap[daysago] = curtotal;
	return progmap;
}

function findExample(hanzichar) 
{
	if(!haveTable("hanzi_example"))
		{ return null; }

	var foundex = null;

	if(haveTable("hanzi_example"))
	{
		getItemList("hanzi_example").forEach(function(hitem) {
			if(hitem.getSimpHanzi().indexOf(hanzichar) != -1)
				{ foundex = hitem; }
		});
	}

	return foundex;
}

function buildChar2VocabMap(vocablist)
{
	const mymap = {};

	vocablist.forEach(function(item) {

		const simple = item.getSimpHanzi();
		for(var i = 0; i < simple.length; i++) {

			const hchar = simple[i];
			if(!(hchar in mymap))
				{ mymap[hchar] = [];}

			mymap[hchar].push(item);
		}
	});

	return mymap;
}


function redisplaySearchInfo()
{
    var searchstr = `

        <br/>
        <br/>

        <a href="javascript:updateSearchInput()"><button>search</button></a>

        &nbsp;
        &nbsp;
        &nbsp;

        <a href="javascript:clearSearchInput()"><button>clear</button></a>


    `;


    if (SEARCH_INPUT.length > 0)
    {

        const hitlist = findSearchHitList();

        searchstr += `

            <br/>
            <br/>

            <table class="basic-table" width="50%">
            <tr>
            <th>Character</th>            
                        <th>PinYin</th>            
            <th>Meaning</th>
            <th>+L</th>
            <th>+R</th>
            </tr>
        `;

        hitlist.forEach(function(item) {

            const hanitem = lookupHanziDataByChar(item.getHanziChar());

            const rowstr = `
                <tr>
                <td>${item.getHanziChar()}</td>                
                <td>${hanitem.getPinYin()}</td>
                <td>${item.getMeaning()}</td>
                <td>
                <a href="javascript:markCharacter(${item.getId()}, true)"><img src="/u/shared/image/checkmark.png" height="18"</a>
                </td>
                <td>
                <a href="javascript:markCharacter(${item.getId()}, false)"><img src="/u/shared/image/checkmark.png" height="18"</a>
                </td>
                </tr>
            `;

            searchstr += rowstr;
        });

        searchstr += `
            </table>
        `;
    }


    populateSpanData({"search_info" : searchstr});
}

function findSearchHitList()
{
    if (SEARCH_INPUT.length == 0)
        { return []; }


    function searchHit(item) {
        const meanhit = item.getMeaning().toLowerCase().indexOf(SEARCH_INPUT.toLowerCase()) > -1;
        const charhit = item.getHanziChar().indexOf(SEARCH_INPUT) > -1;

        const hanzi = lookupHanziDataByChar(item.getHanziChar());
        const basichit = stripDiacritics(hanzi.getPinYin()).indexOf(SEARCH_INPUT) > -1;
        const cmplxhit = hanzi.getPinYin().indexOf(SEARCH_INPUT) > -1;

        return meanhit || charhit || basichit || cmplxhit;
    }

    //getItemList("palace_item").

    return W.getItemList("palace_item").filter(searchHit);
}

function markCharacterSub(palaceid, isleft, linktable)
{
    const palitem = W.lookupItem("palace_item", palaceid);
    const confitem = W.lookupItem(linktable, EDIT_STUDY_ITEM);


    if(isleft)
        { confitem.setLeftChar(palitem.getHanziChar()); }
    else
        { confitem.setRghtChar(palitem.getHanziChar()); }

    confitem.syncItem();
    redisplay();
}





