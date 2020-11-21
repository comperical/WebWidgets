
<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@include file="../../life/AuthInclude.jsp_inc" %>

<%
	
	OptSelector hskSelector = new OptSelector(Util.range(1, 6)).addKey("---");
	
	OptSelector palaceSelector = new OptSelector(Util.listify(true, false)).addKey("---");
	
%>


<html>
<head>
<title>Character Central</title>

<%@include file="../../life/AssetInclude.jsp_inc" %>

<script src="ChineseTech.js"></script>

<%= DataServer.basicIncludeOnly(request, "confounder", "palace_item", "hanzi_data", "review_log") %>

<script>

EDIT_STUDY_ITEM = -1;



function createPalaceItem(hdid) 
{

	const createfrom = lookupItem("hanzi_data", hdid);
	console.log(createfrom);

	const newid = newBasicId("palace_item");
	
	const newrec = {
		"id" : newid,
		"hanzi_char" : createfrom.getHanziChar(),
		"palace_note": "EnterNoteHere",
		"extra_note" : "...",
		"meaning": createfrom.getDefinition()
	};		
	
	clearHanziDataCache();

	const newitem = buildItem("palace_item", newrec);
	newitem.registerNSync();
	redisplay();
}


function filterDisplayList(hdlist)
{
	const results = [];
	
	const hsklevel = getDocFormValue("hsk_level");
	const havepalace = getDocFormValue("have_palace");
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


	const showitem = lookupItem("palace_item", EDIT_STUDY_ITEM);
	var confounderstr = "...";
	{
		const confidx = getConfounderIndex();
		if(showitem.getHanziChar() in confidx) 
		{
			// TODO: should eventually show ALL of these, there might be many.
			const confitem = confidx[showitem.getHanziChar()][0];
			confounderstr = `
				${confitem.getLeftChar()} / ${confitem.getRghtChar()}  :
				${confitem.getExtraInfo()}
			`;
		}
	}



	populateSpanData({
		"hanzi_char" : showitem.getHanziChar(),
		"meaning" : showitem.getMeaning(),
		"extra_note" : showitem.getExtraNote(),
		"confounder_info" : confounderstr,
		"hanzi_char_big" : showitem.getHanziChar()
	})




	const palacetext = showitem.getPalaceNote();
	const palacehtml = palacetext.replace(/\n/g, "<br/>");
	
	const characteritem = lookupHanziDataByChar(showitem.getHanziChar());
	// console.log(characteritem);
	
	const pinyin = characteritem ? characteritem.getPinYin() : "---";

	populateSpanData({
		"palace_note1" : palacehtml,
		"pinyin" : pinyin
	});
	
	getUniqElementByName("palace_note2").value = palacetext;
}

function redisplayMainList()
{
	var hanzilist = getItemList("hanzi_data");

	var maintable = `
		<table class="dcb-basic" id="dcb-basic" width="80%">
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
	
	statinfo = computeStatInfo();
	
	hanzilist.forEach(function(hditem) {

		const palaceitem = lookupPalaceItemByChar(hditem.getHanziChar());
		const palacestr = palaceitem == null ? "---" :  statinfo[palaceitem.getId()].num_review;

		var opstr = `
			<a href="javascript:createPalaceItem(${hditem.getId()})">
			<img src="/life/image/add.png" height="18"/></a>
		`;

		if(palaceitem != null) {
			opstr = `
				<a href="javascript:editStudyItem(${palaceitem.getId()})">
				<img src="/life/image/inspect.png" height="18"/></a>
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




</script>




</head>

<body onLoad="javascript:setDefaultRedisplay()">

<center>

<span class="page_component" id="main_list">

<h2>Character Central</h2>

<br/>

#HSK Level : 
<select name="hsk_level" onChange="javascript:redisplay()">
<%= hskSelector.getSelectStr("---") %>
</select>

Have Palace : 
<select name="have_palace" onChange="javascript:redisplay()">
<%= palaceSelector.getSelectStr("---") %>
</select>

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

<table width="50%" id="dcb-basic">
<tr>
<td width="25%">Back</td>
<td></td>
<td width="30%"><a href="javascript:back2Main()"><img src="/life/image/leftarrow.png" height="18"/></a></td>
</tr>
<tr>
<td>Character</td>
<td><div id="hanzi_char"></div></td>
<td><a href="javascript:editCharacter()"><img src="/life/image/edit.png" height=18/></a></td>
</tr>
<tr>
<td>Meaning</td>
<td><div id="meaning"></div></td>
<td><a href="javascript:editItemMeaning()"><img src="/life/image/edit.png" height=18/></a></td>
</tr>
<tr>
<td>PinYin</td>
<td><div id="pinyin"></div></td>
<td></td>
</tr>
<tr>
<td>Extra Note</td>
<td><div id="extra_note"></div></td>
<td><a href="javascript:editItemExtraNote()"><img src="/life/image/edit.png" height=18/></a></td>
</tr>
<tr>
<td>Confounder</td>
<td colspan="2"><div id="confounder_info"></div></td>
</tr>
</table>

<br/>

<font size="60"><span id="hanzi_char_big"></span></font>


<br/>
<br/>


<span class="edit_info">

<table id="dcb-basic" width="50%" border="0">
<tr>
<td><span id="palace_note1"></span></td>

<td width="10%">
<a href="javascript:toggleHidden4Class('edit_info')"><img src="/life/image/edit.png" height="18"></a>
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

<%= HtmlUtil.nbsp(4) %>


<a class="css3button" onclick="javascript:toggleHidden4Class('edit_info')">cancel</a>

</span>





</center>
</body>
</html>
