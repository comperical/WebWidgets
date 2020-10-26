

function getMeaningList(meanstr)
{
	return meanstr.split(";");
}

function getFirstPalaceNote(palacestr)
{
	return palacestr.split("\n")[0];	
}

REVIEW_PROBS_KNOWN = { "easy" : 0.49, "good" : 0.50, "bad" : 0.01 };

REVIEW_PROBS_MARGINAL = { "easy" : 0.1, "good" : 0.2, "bad" : 0.7 };

// As of Feb 2020, the NetScores seem to be distributed around -0.5 to 5, 
// with most being around 3. 
JITTER_SCALE = 2.0
// JITTER_SCALE = 0;

// This is the big parameter that controls the half-life of a review result.
// After N days, the impact of a review will fall in half.
HALF_LIFE_OF_RESULT = 14;

REVIEW_DECAY_PARAM = Math.log(0.5)/HALF_LIFE_OF_RESULT;

__HANZI_DATA_BY_CHAR = null;

__CONFOUNDER_INDEX = null;


function getConfounderIndex()
{
	if(__CONFOUNDER_INDEX == null)
	{
		__CONFOUNDER_INDEX = {};

		getItemList("confounder").forEach(function(conf) {

			const charlist = [conf.getLeftChar(), conf.getRghtChar()];

			charlist.forEach(function(char) {

				if(!(char in __CONFOUNDER_INDEX)) 
					{ __CONFOUNDER_INDEX[char] = []; }

				__CONFOUNDER_INDEX[char].push(conf);

			});
		});
	}

	return __CONFOUNDER_INDEX;
}

function lookupHanziDataByChar(hanzichar)
{
	if(__HANZI_DATA_BY_CHAR == null)
	{
		console.log("Rebuilding hanzi data -> char map");
		__HANZI_DATA_BY_CHAR = {}
		getItemList("hanzi_data").forEach(function(hditem) {
			__HANZI_DATA_BY_CHAR[hditem.getHanziChar()] = hditem.getId();	
		});
	}
	
	const foundid = __HANZI_DATA_BY_CHAR[hanzichar];	
	return lookupItem("hanzi_data", foundid);
}

__PALACE_ITEM_BY_CHAR = null;

function lookupPalaceItemByChar(hanzichar)
{
	if(__PALACE_ITEM_BY_CHAR == null)
	{
		console.log("Rebuilding palance data -> char map");
		__PALACE_ITEM_BY_CHAR = {}
		getItemList("palace_item").forEach(function(hditem) {
			__PALACE_ITEM_BY_CHAR[hditem.getHanziChar()] = hditem.getId();	
		});
	}
	
	const foundid = __PALACE_ITEM_BY_CHAR[hanzichar];	
	return foundid == null ? null : lookupItem("palace_item", foundid);
}

function clearHanziDataCache() {

	__PALACE_ITEM_BY_CHAR = null;
	__HANZI_DATA_BY_CHAR = null;
	__CONFOUNDER_INDEX = null;
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


function computeStatInfo()
{
	return computeStatInfoSub("palace_item", "review_log");	
}

function computeVocabStatInfo()
{
	return computeStatInfoSub("word_memory", "vocab_log");	
}

// Parse CEDict format record into lines
// Also remove CL tags
function parseCedictDef(cedict)
{
	const records = cedict.split("/").filter(r => r.trim());	
	return records.filter(r => r.length > 0 && !r.startsWith("CL"));
}

function computeStatInfoSub(itemtable, logtable)
{
	const palacelist = getItemList(itemtable);
	const reviewlist = getItemList(logtable);

	var statmap = {};
	
	palacelist.forEach(function(pitem) {
		var statpack = new Object();
		const jitter = (Math.random() - 0.5) * JITTER_SCALE;
		// const jitter = 0;

		statpack["num_review"] = 0;
		statpack["net_score"] = jitter;
		statpack["last_review"] = "2000";
		statmap[pitem.getId()] = statpack;						
	});
	
	reviewlist.forEach(function(ritem) {
	
		// This is an FKEY error			
		if(!statmap.hasOwnProperty(ritem.getItemId()))
			{ return; }
		
		const myitem = statmap[ritem.getItemId()];
		const basescore = singleReviewItemScore(ritem);
		
		// Sort by review timestamp
		myitem["last_review"] = ritem.getTimeStamp();
		myitem["num_review"] += 1;
		myitem["base_score"] += basescore;
		myitem["net_score"] += basescore;
	});

	return statmap;	
	
	
	
}

function stripDiacritics(pinyin)
{
	return pinyin.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}


// Map of days ago -> cumulative review items
function getPalaceProgress()
{
	var tracker = getTodayCode();
	var daysago = 0;
	
	var progmap = {};
	var curtotal = 0;
	
	var reviewlist = getItemList("review_log");
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

