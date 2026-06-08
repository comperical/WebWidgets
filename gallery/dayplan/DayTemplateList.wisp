
<html>
<head>
<title>Day Plan Templates</title>

<wisp/>

<script>

let EDIT_STUDY_ITEM = -1;
// EDIT_STUDY_ITEM = 27;

const FILTER_DAY_KEY = "FilterDayKey";
GENERIC_OPT_SELECT_MAP.set(FILTER_DAY_KEY, "---");

function composeSaveString(daylist)
{
	daylist.sort(U.proxySort(dow => [SHORT_DAY_WEEK_LIST.indexOf(dow)]));
	return daylist.join(",");
}

function addOnDayItem()
{
	const newday = U.getDocFormValue("on_day_sel");

	const updater = function(item) {
		var daylist = getDayList4Item(item);
		if(daylist.includes(newday)) { alert("Already have it!"); return; }
		daylist = [newday].concat(daylist);
		item.setOnDayList(composeSaveString(daylist));
	};

	U.genericItemUpdate("day_template", EDIT_STUDY_ITEM, updater);
}

function removeDay4Item(xday)
{
	const updater = function(item) {
		const prevlist = getDayList4Item(item);
		const remidx = prevlist.indexOf(xday);
		U.massert(remidx != -1, `Attempt to remove day ${xday} from list, but list is ${prevlist}`);
		prevlist.splice(remidx, 1);
		item.setOnDayList(composeSaveString(prevlist));
	};

	U.genericItemUpdate("day_template", EDIT_STUDY_ITEM, updater);
}

function getEditDayListData(daylist)
{
	var s = "";
	daylist.forEach(function(day) {
		s += `${day} <a href="javascript:removeDay4Item('${day}')"><img src="/u/shared/image/remove.png" height="16"/></a> &nbsp;&nbsp;&nbsp;`;
	});
	return s;
}

function createNewTemplate()
{
	const templatename = prompt("Item Desc: ");

	if(templatename)
	{
		const newid = W.newBasicId("day_template");
		const newrec = {
			"id" : newid,
			"short_name" : templatename,
			"full_desc" : "",
			"is_active" : 1,
			"on_day_list" : "all"
		}

		const newtemplate = W.buildItem("day_template", newrec);
		newtemplate.syncItem();
		redisplay();
	}
}

function deleteTemplateItem(killid)
{
	const kidlist = W.getItemList("template_sub").filter(sub => sub.getTempId() == killid);

	if(kidlist.length > 0)
	{
		alert("This template has child items. You must either delete all child items and then delete, or archive");
		return;
	}

	if(confirm("Are you sure you want to delete this template?"))
	{
		W.lookupItem("day_template", killid).deleteItem();
		back2Main();
	}
}

function archiveTemplate(itemid) 
{
	U.genericToggleActive("day_template", itemid);
}

function redisplay()
{
	reDispActiveTable();
}

function editStudyItem(itemid)
{
	EDIT_STUDY_ITEM = itemid;
	redisplay();
}


function back2Main()
{
	EDIT_STUDY_ITEM = -1;
	redisplay();
}

function getSelectedTemplate()
{
	return W.lookupItem("day_template", EDIT_STUDY_ITEM);
}

function createWakeUpItem()
{
	const newrec = {
		"temp_id" : EDIT_STUDY_ITEM,
		"end_hour" : 8,
		"half_hour" : 0,
		"short_desc" : "Jump Out of Bed!!"
	}

	const newitem = W.buildItem("template_sub", newrec);
	newitem.syncItem();
	redisplay();
}


function newByHourSpent()
{
	const itemlist = getPlanDayItemList();
	if(itemlist.length == 0)
	{
		alert("You must create at least one record first");
		return;
	}
	
	const plusmin = U.getDocFormValue("time_spent_min");
	const itemname = prompt("Item Desc: ");
	
	if(itemname)
	{
		const previtem = itemlist.slice(-1)[0];
		var totalmin = previtem.getEndHour() * 60 + previtem.getHalfHour() * 30;
		
		totalmin += plusmin*1;
		
		const newhour = Math.floor(totalmin/60);	
		const newhalf = (totalmin - newhour*60) > 15;
		
		// console.log("Total min " + totalmin + " newhour=" + newhour + " newhalf=" + newhalf);

		const newrec = {
			"temp_id" : EDIT_STUDY_ITEM,
			"end_hour" : newhour,
			"half_hour" : newhalf ? 1 : 0,
			"short_desc" : itemname
		}

		const newitem = W.buildItem("template_sub", newrec);
		newitem.syncItem();
		redisplay();
	}
}

function createNew()
{

	const newid = W.newBasicId("template_sub");
	
	var itemname = prompt("Item Desc: ");
	
	if(itemname)
	{
		const newrec = {
			"id" : newid,
			"temp_id" : EDIT_STUDY_ITEM,
			"end_hour" : U.getDocFormValue("end_hour"),
			"half_hour" : 0,
			"short_desc" : itemname
		}

		const newitem = W.buildItem("template_sub", newrec);
		newitem.syncItem();
		redisplay();
	}
}

function addTime2Item(itemid)
{
	const planitem = W.lookupItem("template_sub", itemid);
	
	if(planitem.getHalfHour() == 0)
	{
		planitem.setHalfHour(1);
	} else {
		planitem.setEndHour(planitem.getEndHour()+1);
		planitem.setHalfHour(0);
	}

	planitem.syncItem();
	redisplay();
}

function removeTimeFromItem(itemid)
{
	const planitem = W.lookupItem("template_sub", itemid);
	
	if(planitem.getHalfHour() == 1)
	{
		planitem.setHalfHour(0);
	} else {
		planitem.setEndHour(planitem.getEndHour()-1);
		planitem.setHalfHour(1);
	}
	
	planitem.syncItem();
	redisplay();
}

function deleteItem(killid)
{
	U.genericDeleteItem("template_sub", killid);
}

function getPlanDayItemList()
{
	var biglist = W.getItemList("template_sub").filter(item => item.getTempId() == EDIT_STUDY_ITEM);
	return biglist.sort(U.proxySort(item => [item.getEndHour()]));
}

function editTemplateName(editid)
{
	U.genericEditTextField("day_template", "short_name", editid);
}

function editItemName(editid)
{
	const theitem = W.lookupItem("template_sub", editid);
	const newname = prompt("New info for item: ", theitem.getShortDesc());

	if(newname)
	{
		theitem.setShortDesc(newname);
		theitem.syncItem();
		redisplay();
	}
}

function getPageComponent()
{
	return EDIT_STUDY_ITEM == -1 ? "main_list" : "study_item";
}

function redisplay()
{
	handleNavBar("Plan Templates");

	redisplayMainList();
	redisplayStudyItem();

	setPageComponent(getPageComponent());
}

function redisplayMainList()
{
	
	var templatelist =  W.getItemList("day_template");

	var mainstr = `
		<table class="basic-table"  width="50%">
		<tr>
		<th>Name</th>
		<th width="5%">Active?</th>
		<th>Days</th>
		<th>#Note</th>
		<th width="5%">...</th>
		</tr>
	`;

	const breaker = `&nbsp; &nbsp;`

	const filterDay = GENERIC_OPT_SELECT_MAP.get(FILTER_DAY_KEY);

	const filterDaySel = buildOptSelector()
							.configureFromList(["---"].concat(SHORT_DAY_WEEK_LIST))
							.setElementName(FILTER_DAY_KEY)
							.useGenericUpdater()
							.getHtmlString();

	const showinactive = U.getUniqElementByName("show_inactive").checked;

	templatelist.forEach(function(item) {

		if(item.getIsActive() == 0 && !showinactive)
			{ return; }

		const daylist = getDayList4Item(item);

		if(filterDay != "---" && !daylist.includes(filterDay))
			{ return; }

		const activstr = item.getIsActive() == 1 ? "Y" : "N";
		var dayshow = daylist.length == 7 ? "all" : daylist.join("/");
		if(daylist.length == 5 && !daylist.includes("Sun") && !daylist.includes("Sat"))
			{ dayshow = "workdays"; }

		const notecount = Object.keys(item.getNoteData()).length;

		const rowstr = `
			<tr>
			<td>${item.getShortName()}</td>
			<td>${activstr}</td>
			<td>${dayshow}</td>
			<td>${notecount > 0 ? notecount : ""}</td>
			<td>

			<a href="javascript:editStudyItem(${item.getId()})">
			<img src="/u/shared/image/inspect.png" height="18"/></a>

			</td>
			</tr>
		`;


		mainstr += rowstr;
	});

	mainstr += `<table>`;

	U.populateSpanData({ templatelist : mainstr, filter_day_span : filterDaySel });
}

function deleteNoteByIdx(noteidx)
{
	const updater = function(item)
	{
		item.updateNoteData(function(ndata) { delete ndata[noteidx]; });
	}

	U.genericItemUpdate("day_template", EDIT_STUDY_ITEM, updater);

}

function editNoteByIdx(noteidx)
{
	const updater = function(item)
	{
		const notedata = item.getNoteData();
		const newnote = prompt("Enter a new note:", notedata[noteidx]);

		if(newnote != null)
		{
			item.updateNoteData(function(ndata) { ndata[noteidx] = newnote; });
		}
	}

	U.genericItemUpdate("day_template", EDIT_STUDY_ITEM, updater);



}

function getStudyItemData()
{
	const item = W.lookupItem("day_template", EDIT_STUDY_ITEM);
	return item.getNoteData();
}

function addNoteCurrentTemplate()
{
	const newnote = prompt("Please enter a new note text:");
	if(newnote == null)
		{ return; }


	const updater = function(item)
	{
		// ugh, goddam it JS!!
		const myjson = item.getNoteData();
		const idlist = [... Object.keys(myjson)]
							.sort(U.proxySort(s => [-parseInt(s)]));


		const newidx = idlist.length == 0 ? 0 : parseInt(idlist[0])+1;
		item.updateNoteData(function(ndata) { ndata[newidx] = newnote; });
	}

	U.genericItemUpdate("day_template", EDIT_STUDY_ITEM, updater);
}


function getNoteTemplateTable()
{
	const studyitem = W.lookupItem("day_template", EDIT_STUDY_ITEM);


	let ntable = `

		<table class="basic-table" width="50%">
		<tr>
		<th>IDX</th>
		<th width="90%">Note</th>
		<th width="5%"></th>
		</tr>

	`;

	const notedata = studyitem.getNoteData();

	[... Object.keys(notedata)].forEach(function(noteidx) {

		const notetext = notedata[noteidx];

		const rowstr = `
			<tr>
			<td>${noteidx}</td>
			<td class="editable"
				onClick="javascript:editNoteByIdx(${noteidx})">${notetext}</td>
			<td>
			<a href="javascript:deleteNoteByIdx(${noteidx})">
			<img src="/u/shared/image/remove.png" height="18" />
			</a>
			</td>
			</tr>
		`;

		ntable += rowstr;

	});




	{
		ntable += `<tr><td colspan="3">
		<a href="javascript:addNoteCurrentTemplate()">
		<button>+note</button>
		</a>
		</td></tr>`

	}

	ntable += `</table>`;
	return ntable;


}


function redisplayStudyItem()
{
	if(EDIT_STUDY_ITEM == -1) 
		{ return; }

	var mainstr = `
		<table class="basic-table"  width="50%">
		<tr>
		<th>Desc</th>
		<th>End</th>
		<th>Length</th>
		<th>
		....
		</th>
		</tr>
	`;


	const itemlist = getPlanDayItemList();
		
	const breaker = `&nbsp; &nbsp`;

	for(var ai in itemlist) {

		const item = itemlist[ai];
		const endhourstr = item.getEndHour();
		const halfstr = item.getHalfHour() == 1 ? ":30" : ":00";		
			
		var timespent = "---";
		
		if(ai > 0)
		{
			const previtem = itemlist[ai-1];
			
			var totalmin = item.getEndHour()*60 - previtem.getEndHour()*60;
			
			totalmin += (item.getHalfHour()*30);
			totalmin -= (previtem.getHalfHour()*30);
			
			var totalhour = totalmin/60;
			timespent = totalhour.toFixed(1) + " hr";			
		}

		const rowstr = `
			<tr>
			<td class="editable"
			onClick="javascript:editItemName(${item.getId()})">${item.getShortDesc()}</td>
			<td>${endhourstr + halfstr}</td>
			<td>${timespent}</td>			
			<td>


			<a href="javascript:addTime2Item(${item.getId()})">
			<img src="/u/shared/image/upicon.png" height="18"/></a>

			${breaker}

			<a href="javascript:removeTimeFromItem(${item.getId()})">
			<img src="/u/shared/image/downicon.png" height="18"/></a>

			${breaker}

			<a href="javascript:deleteItem(${item.getId()})">
			<img src="/u/shared/image/remove.png" height="18"/></a>

			</td>
			</tr>

		`;

		mainstr += rowstr;

	}
	

	const newcontrol = getNewItemControl(itemlist.length > 0);

	mainstr += `</table>

		<br/><br/>

		${newcontrol}

		<br/><br/>

		${getNoteTemplateTable()}
	`;

	const showItem = getSelectedTemplate();
	const currentDays = getDayList4Item(showItem);
	const daylistEdit = getEditDayListData(currentDays);
	const addDays = ["---"].concat(SHORT_DAY_WEEK_LIST.filter(dow => !currentDays.includes(dow)));
	const dayaddsel = buildOptSelector()
						.configureFromList(addDays)
						.setElementName("on_day_sel")
						.setOnChange("javascript:addOnDayItem()")
						.getHtmlString();
	const showSelStr = currentDays.length == 7 ? "" : dayaddsel;

	U.populateSpanData({
		"dayplantable" : mainstr,
		"templatename" : showItem.getShortName(),
		"on_days" : daylistEdit,
		"on_day_sel_span" : showSelStr,
		"isactive" : showItem.getIsActive() == 1 ? "YES" : "NO"
	});
}

</script>

</head>

<body onLoad="javascript:redisplay()">


<center>

<div class="topnav"></div>

<br/>


<span class="page_component" id="main_list">

Show Day: <span id="filter_day_span"></span>
&nbsp;&nbsp;&nbsp;
Inactive? <input type="checkbox" name="show_inactive" onChange="javascript:redisplay()"/>
<br/>
<br/>

<div id="templatelist"></div>

<br/><br/>

<a class="css3button" onclick="javascript:createNewTemplate()">NEW</a> 

</span>

<span class="page_component" id="study_item">

<table class="basic-table" width="50%">
<tr>
<td>Back</td>
<td colspan="2"><a href="javascript:back2Main()"><img src="/u/shared/image/leftarrow.png" height="18"/></a></td>
</tr>
<tr>
<td>Name</td>
<td><span id="templatename"></span></td>
<td><a href="javascript:editTemplateName(EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"/></a></td>
</tr>
<tr>
<td>Days</td>
<td><span id="on_days"></span></td>
<td><span id="on_day_sel_span"></span></td>
</tr>
<tr>
<td>Active?</td>
<td><span id="isactive"></span></td>
<td><a href="javascript:archiveTemplate(EDIT_STUDY_ITEM)"><img src="/u/shared/image/cycle.png" height="18"/></a></td>
</tr>
<tr>
<td>Delete</td>
<td></td>
<td><a href="javascript:deleteTemplateItem(EDIT_STUDY_ITEM)"><img src="/u/shared/image/remove.png" height="18"/></a></td>
</tr>
</table>

<br/><br/>

<div id="dayplantable"></div>

</body>
</html>
