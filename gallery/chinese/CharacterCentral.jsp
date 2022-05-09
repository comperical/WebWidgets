

<html>
<head>
<title>Character Central</title>

<script src="ChineseTech.js?bust_cache=13"></script>
<script src="../hanyu/pin_yin_converter.js"></script>

<%= DataServer.basicIncludeOnly(request, "confounder", "palace_item", "hanzi_data", "review_log", "word_memory") %>

<%= DataServer.includeIfAvailable(request, "cedict", "hanzi_example") %>

<script>

EDIT_STUDY_ITEM = -1;

CHARACTER_VOCAB_MAP = buildChar2VocabMap(W.getItemList("word_memory"));

HSK_LEVEL_SELECT = "---";

HAVE_PALACE_SELECT = "---";

function createPalaceItem(hdid) 
{

	const createfrom = lookupItem("hanzi_data", hdid);
	console.log(createfrom);
	
	const newrec = {
		"hanzi_char" : createfrom.getHanziChar(),
		"palace_note": "EnterNoteHere",
		"extra_note" : "...",
		"is_active" : 1,
		"meaning": createfrom.getDefinition()
	};		
	
	clearHanziDataCache();

	const newitem = W.buildItem("palace_item", newrec);
	newitem.syncItem();
	redisplay();
}

function updateFromSelect()
{
	HSK_LEVEL_SELECT = getDocFormValue("hsk_level_sel");
	HAVE_PALACE_SELECT = getDocFormValue("have_palace_sel");
	redisplay();
}


function filterDisplayList(hdlist)
{
	const results = [];
	
	const hsklevel = HSK_LEVEL_SELECT;
	const havepalace = HAVE_PALACE_SELECT;

	const searchdef = getDocFormValue("search4_define");
	const searchpin = getDocFormValue("search4_pinyin");
	
	hdlist.forEach(function(hditem) {
					
		if(hsklevel != "---" && hditem.getHskLevel() != parseInt(hsklevel))
			{ return; }
		
		if(havepalace != "---") 
		{
			const palaceitem = lookupPalaceItemByChar(hditem.getHanziChar());
			
			if(havepalace == "true" && palaceitem == null)
				{ return; }
			
			if(havepalace == "false" && palaceitem != null)
				{ return; }
		}
		
		if(searchdef.length > 0 && hditem.getDefinition().indexOf(searchdef) == -1)
			{ return; }
		
		if(searchpin.length > 0) 
		{
			const nodiac = stripDiacritics(hditem.getPinYin());
			
			if(nodiac != searchpin)
				{ return; }
		}
			
		results.push(hditem);		
			
	});
	
	return results;
	
}

function back2Main()
{
	EDIT_STUDY_ITEM = -1;
	redisplay();
}

function editStudyItem(itemid)
{
	EDIT_STUDY_ITEM = itemid;
	redisplay();
}

function bounce2NewId()
{
	const newid = prompt("Please enter a new ID:");

	if(newid)
	{

		if(!okayInt(newid))
		{
			alert("please enter a valid Integer");
			return;
		}

		EDIT_STUDY_ITEM = parseInt(newid);
		redisplay();
	}
}

function getPageComponent()
{
	return EDIT_STUDY_ITEM == -1 ? "main_list" : "edit_item";
}

function setDefaultRedisplay()
{
	const params = getUrlParamHash();
	if("item_id" in params) {
		EDIT_STUDY_ITEM = parseInt(params["item_id"]);
	}

	redisplay();
}

function redisplay()
{
	redisplayEditItem();
	redisplayMainList();

	setPageComponent(getPageComponent());
}

function redisplayEditItem()
{
	if(EDIT_STUDY_ITEM == -1)
		{ return; }

	const showitem = W.lookupItem("palace_item", EDIT_STUDY_ITEM);

	const characteritem = lookupHanziDataByChar(showitem.getHanziChar());
	const pinyin = characteritem ? characteritem.getPinYin() : "---";	


	var tablestr = `
		<table width="50%" class="basic-table">
		<tr>
		<td width="25%">Back</td>
		<td></td>
		<td width="10%"><a href="javascript:back2Main()"><img src="/u/shared/image/leftarrow.png" height="18"/></a></td>
		</tr>
		<tr>
		<td>ID</td>
		<td>${EDIT_STUDY_ITEM}</td>
		<td><a href="javascript:bounce2NewId()"><img src="/u/shared/image/rghtarrow.png" height=18/></a></td>
		</tr>
		<tr>
		<td>Character</td>
		<td>${showitem.getHanziChar()}</td>
		<td><a href="javascript:editCharacter()"><img src="/u/shared/image/edit.png" height=18/></a></td>
		</tr>
		<tr>
		<td>Meaning</td>
		<td>${showitem.getMeaning()}</td>
		<td><a href="javascript:editItemMeaning()"><img src="/u/shared/image/edit.png" height=18/></a></td>
		</tr>
		<tr>
		<td>PinYin</td>
		<td>${pinyin}</td>
		<td></td>
		</tr>
		<tr>
		<td>Extra Note</td>
		<td>${showitem.getExtraNote()}</td>
		<td><a href="javascript:editItemExtraNote()"><img src="/u/shared/image/edit.png" height=18/></a></td>
		</tr>
	`;


	{
		const confidx = getConfounderIndex();
		if(showitem.getHanziChar() in confidx) 
		{
			const conflist = confidx[showitem.getHanziChar()];
			conflist.forEach(function(confitem) {

				tablestr += `
					<tr>
					<td>Confounder</td>
					<td colspan="2">
					${confitem.getLeftChar()} / ${confitem.getRghtChar()}  :
					${confitem.getExtraInfo()}
					</td>
					</tr>
				`;
			});
		}
	}

	const vocabex = CHARACTER_VOCAB_MAP[showitem.getHanziChar()] || [];

	for(var idx = 0; idx < vocabex.length; idx++) {

		const vocab = vocabex[idx];
		const promptstr = (idx == 0 ? "Vocab" : "");
		const pinyinstr = PinyinConverter.convert(vocab.getPinYin());

		tablestr += `
			<tr>
			<td>${promptstr}</td>
			<td colspan="2">
			${vocab.getSimpHanzi()} (${pinyinstr}): ${vocab.getEnglish()}
			</td>
			</tr>
		`;
	}

	tablestr += "</table>";

	populateSpanData({
		"main_edit_table" : tablestr,
		"hanzi_char_big" : showitem.getHanziChar()
	});

	const palacetext = showitem.getPalaceNote();
	const palacehtml = palacetext.replace(/\n/g, "<br/>");

	populateSpanData({
		"palace_note1" : palacehtml
	});
	
	getUniqElementByName("palace_note2").value = palacetext;
}

function redisplayMainList()
{
	var hanzilist = W.getItemList("hanzi_data");

	var maintable = `
		<table  class="basic-table" width="80%">
		<tr>
		<th>Character</th>
		<th>PinYin</th>
		<th>Radical</th>
		<th>Definition</th>
		<th>HSK</th>
		<th>Frequency</th>
		<th>Palace?</th>
		<th>...</th>
		</tr>
	`;

	hanzilist = filterDisplayList(hanzilist);
	
	hanzilist = hanzilist.slice(0, 400);
	
	statinfo = fullBuildBayesStatMap("palace_item", "review_log");	
	
	hanzilist.forEach(function(hditem) {

		const palaceitem = lookupPalaceItemByChar(hditem.getHanziChar());
		// const palacestr = palaceitem == null ? "---" :  statinfo[palaceitem.getId()].num_review;
		const numvocab = (CHARACTER_VOCAB_MAP[hditem.getHanziChar()] || []).length;
		const palacestr = numvocab;

		var opstr = `
			<a href="javascript:createPalaceItem(${hditem.getId()})">
			<img src="/u/shared/image/add.png" height="18"/></a>
		`;

		if(palaceitem != null) {
			opstr = `
				<a href="javascript:editStudyItem(${palaceitem.getId()})">
				<img src="/u/shared/image/inspect.png" height="18"/></a>
			`;
		}


		const rowstr = `
			<tr>
			<td>${hditem.getHanziChar()}</td>
			<td>${hditem.getPinYin()}</td>
			<td>${hditem.getRadical()}</td>
			<td>${hditem.getDefinition()}</td>
			<td>${hditem.getHskLevel()}</td>
			<td>${hditem.getFreqRank()}</td>
			<td>${palacestr}</td>
			<td width="8%">
			${opstr}
			</td>
			</tr>
		`;

		maintable += rowstr;
	});

	maintable += `</table>`;

	populateSpanData({
		"maintable" : maintable,
		"itemcount" : hanzilist.length
	});

	buildOptSelector()
		.setKeyList(["---", "true", "false"])
		.setElementName("have_palace_sel")
		.setSelectedKey(HAVE_PALACE_SELECT)
		.setOnChange("javascript:updateFromSelect()")		
		.autoPopulate();

	buildOptSelector()
		.setKeyList(["---", "1", "2", "3", "4", "5", "6"])
		.setElementName("hsk_level_sel")
		.setSelectedKey(HSK_LEVEL_SELECT)
		.setOnChange("javascript:updateFromSelect()")
		.autoPopulate();		
}

function savePalaceNote()
{
	const showitem = lookupItem("palace_item", EDIT_STUDY_ITEM);
	const newnote = getDocFormValue("palace_note2");
	showitem.setPalaceNote(newnote);
	syncSingleItem(showitem);
	toggleHidden4Class('edit_info');
	redisplay();
}

function editCharacter()
{
	const showitem = lookupItem("palace_item", EDIT_STUDY_ITEM);
	const newchar = prompt("Enter a new Hanzi character: ", showitem.getHanziChar());
	
	if(newchar)
	{
		showitem.setHanziChar(newchar);
		syncSingleItem(showitem);		
		redisplay();
	}
}

function editItemExtraNote()
{
	genericEditTextField("palace_item", "extra_note", EDIT_STUDY_ITEM);
}

function editItemMeaning()
{
	genericEditTextField("palace_item", "meaning", EDIT_STUDY_ITEM);
}

function getShouldConvertList()
{
	const examples = W.getItemList("hanzi_example");
	const vocablist = W.getItemList("word_memory");

	const haveset = new Set(vocablist.map(item => item.getSimpHanzi()));

	return examples.filter(item => !(haveset.has(item.getSimpHanzi())));
}


function convertExample2Vocab()
{
	massert(false, "Retaining for doc purposes only, do not use");

	const convertList = getShouldConvertList();
	console.log("Should convert list is " + convertList.length);
	const maxConvert = 1000;
	var numconvert = 0;

	for(var idx = 0; idx < maxConvert && idx < convertList.length; idx++) {

		const exitem = convertList[idx];

		const newrec = {
			"simp_hanzi" : exitem.getSimpHanzi(),
			"trad_hanzi" : exitem.getTradHanzi(),
			"english" : exitem.getEnglish(),
			"pin_yin" : exitem.getPinYin(),
			"basic_py" : "...",
			"is_active" : 1,
			"extra_notes" : "Converted from example id " + exitem.getId()
		};

		const newvoc = buildItem("word_memory", newrec);
		newvoc.syncItem();

		numconvert += 1;
	}

	console.log("Converted  " + numconvert + " items");




}



</script>




</head>

<body onLoad="javascript:setDefaultRedisplay()">

<center>

<span class="page_component" id="main_list">

<h2>Character Central</h2>

<br/>

#HSK Level : <span id="hsk_level_sel_span"></span>

Have Palace : <span id="have_palace_sel_span"></span>

<br/>

Definition: <input type="text" name="search4_define" onChange="javascript:redisplay()" />

PinYin: <input type="text" name="search4_pinyin" onChange="javascript:redisplay()" />


<br/><br/>

Showing <span id="itemcount"></span> items

<div id="maintable"></div>


<br/>

</span>

<span class="page_component" id="edit_item">

<h3>Edit Palace Info</h3>

<br/>

<div id="main_edit_table"></div>

<br/>

<font size="60"><span id="hanzi_char_big"></span></font>


<br/>
<br/>


<span class="edit_info">

<table class="basic-table" width="50%" border="0">
<tr>
<td><span id="palace_note1"></span></td>

<td width="10%">
<a href="javascript:toggleHidden4Class('edit_info')"><img src="/u/shared/image/edit.png" height="18"></a>
</td>
</tr>
</table>
<br/>
</span>


<span class="edit_info" hidden>

<form>
<textarea id="palace_note2" name="palace_note2" cols="80" rows="10">


</textarea>
</form>

<a class="css3button" onclick="javascript:savePalaceNote()">save</a>

&nbsp;
&nbsp;
&nbsp;


<a class="css3button" onclick="javascript:toggleHidden4Class('edit_info')">cancel</a>

</span>





</center>
</body>
</html>
