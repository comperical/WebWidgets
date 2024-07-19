
<html>
<head>
<title>Morning Routine Phases</title>

<wisp tables="mroutine_phase"/>

<script src="/u/shared/optjs/ExtraInfoBox/v1.js"></script>

<script>



let EDIT_STUDY_ITEM = -1;

const SHOW_INACTIVE_KEY = "ShowInactiveKey";

GENERIC_OPT_SELECT_MAP.set(SHOW_INACTIVE_KEY, 'false');



function changeShowType()
{
	redisplay();
}


function deleteItem(killid)
{
	if(confirm("Are you sure you want to delete item " + killid + " ?"))
	{
		W.lookupItem("mroutine_phase", killid).deleteItem();
		redisplay();
	}
}

function cycleStatus(cycid)
{
	const item = W.lookupItem("mroutine_phase", cycid);
	item.setIsActive(item.getIsActive() == 1 ? 0 : 1);
	item.syncItem();
	redisplay();
}

function createNew()
{
	const shortname = prompt("Name of new phase: ");
	const neworder = 0;
	
	if(shortname)
	{
		const comrecord = {
			"is_active" : 1,
			"short_name" : shortname,
			"full_desc": "NotYetSet",
			"web_link" : "",
			"order_key" : neworder,
			"on_day_list" : "all"
		};
		
		const newitem = W.buildItem("mroutine_phase", comrecord);
		newitem.syncItem();
		redisplay();
	}
}

function editOrderKey(itemid)
{
	const phaseitem = W.lookupItem("mroutine_phase", itemid);
	const newokstr = prompt("Please enter a number to control this item's order in the checklist: ", phaseitem.getOrderKey());
	
	if(!newokstr)
	{
		return;
	}
	
	if(!okayFloat(newokstr))
	{
		alert("Please enter a valid number, decimal is okay");
		return;
	}
	
	phaseitem.setOrderKey(parseFloat(newokstr));
	phaseitem.syncItem();
	redisplay();
}



function flipActive()
{
	const showItem = getEditStudyItem();
	const curActive = showItem.getIsActive();
	showItem.setIsActive(curActive == 1 ? 0 : 1);
	showItem.syncItem();
	redisplay();
}


function getExtraInfoBox()
{
	return EXTRA.getEiBox()
					.withStandardConfig("mroutine_phase", EDIT_STUDY_ITEM, "full_desc")
					.withBoxBuilder("javascript:getExtraInfoBox()");

}

function editItemName()
{
	const showitem = getEditStudyItem()
	const newname = prompt("Enter a new short name: ", showitem.getShortName());
	
	if(newname)
	{
		showitem.setShortName(newname);
		showitem.syncItem();
		redisplay();
	}
}

function editWebLink()
{
	var showitem = getEditStudyItem()
	var newlink = prompt("Enter a new web link: ", showitem.getWebLink());
	
	if(newlink)
	{
		showitem.setWebLink(newlink);
		showitem.syncItem();
		redisplay();
	}
}

function getEditStudyItem()
{
	return W.lookupItem("mroutine_phase", EDIT_STUDY_ITEM);
}
                      
function setEditStudyItem(studyid)
{
	EDIT_STUDY_ITEM = studyid;
	redisplay();
}

function addOnDayItem()
{
	const showitem = getEditStudyItem();
	const newday = getDocFormValue("on_day_sel");

	var daylist = getDayList4Item(showitem);

	if(daylist.includes(newday))
	{
		alert("Already have it!");
		return;
	}

	daylist = [newday].concat(daylist);
	showitem.setOnDayList(composeSaveString(daylist));
	showitem.syncItem();
	redisplay();
}

function composeSaveString(daylist) 
{
	daylist.sort(proxySort(dow => [SHORT_DAY_WEEK_LIST.indexOf(dow)]));
	return daylist.join(",");
}

function removeDay4Item(xday) 
{
	const showitem = getEditStudyItem()
	const prevlist = getDayList4Item(showitem);
	const remidx = prevlist.indexOf(xday);

	massert(remidx != -1, `Attempt to remove day ${xday} from list, but list is ${prevlist}`);
	prevlist.splice(remidx, 1);

	showitem.setOnDayList(composeSaveString(prevlist));
	showitem.syncItem();
	redisplay();
}

function back2Main()
{
	setEditStudyItem(-1);
}

function getPageComponent()
{
	return EDIT_STUDY_ITEM == -1 ? "main_component" : "edit_component";	
}

function redisplay()
{
	handleNavBar();

	redisplayMainTable();
	
	redisplayEditItem();
		
	setPageComponent(getPageComponent());
}

function getDayList4Item(phaseitem)
{
	const daystr = phaseitem.getOnDayList();

	if(daystr == "" || daystr == "all")
		{ return [... SHORT_DAY_WEEK_LIST]; }

	return daystr.split(",");
}

function handleNavBar() {

	const headerinfo = [
        ["Morning Routine", "widget.wisp"],
        ["Phases", "MroutineList.wisp"]
    ];

    populateTopNavBar(headerinfo, "Phases");
}

function redisplayMainTable()
{
	var mtstr = `
	<table  class="basic-table" width="60%">
	<tr>
	<th colspan="2">OrderKey</th>
	<th>Name</th>
	<th>Days</th>	
	<th>Active?</th>
	<th>---</th>
	</tr>
	`;

	var biglist = W.getItemList("mroutine_phase");
	biglist.sort(proxySort(item => [item.getOrderKey()]));


	
	const boolSelector = buildOptSelector()
							// Big gotcha. We can use JS boolean literals here, but the genericUpdater turns them into strings
							.configureFromList([true, false])
							.setElementName(SHOW_INACTIVE_KEY)
							.useGenericUpdater()
							.getHtmlString();



	// Okay, the issue is that when the object goes through getDocFormValue(...) in genericUpdater function,
	// It gets transformed into a string
	const showInActive = GENERIC_OPT_SELECT_MAP.get(SHOW_INACTIVE_KEY) == true.toString();

	biglist.forEach(function(onephase) {

		if(onephase.getIsActive() == 0 && !showInActive)
			{ return; }
					
		const opstuff = `
			<a href="javascript:setEditStudyItem(${onephase.getId()})"><img src="/u/shared/image/inspect.png" height="18"></a>
			&nbsp;&nbsp;&nbsp;
			<a href="${onephase.getWebLink()}"><img src="/u/shared/image/chainlink.png" height="18"></a>
			&nbsp;&nbsp;&nbsp;
			<a href="javascript:cycleStatus(${onephase.getId()})">
			<img src="/u/shared/image/cycle.png" height="18"></a>
		`;


		const activstr = onephase.getIsActive() == 1 ? "Y" : "N";
				
		const daylist = getDayList4Item(onephase);
		var dayshow = daylist.length == 7 ? "all" : daylist;

		if(daylist.length == 5 && !daylist.includes("Sun") && !daylist.includes("Sat")) 
			{ dayshow = "workdays"; }

		const mainrow = `
			<tr>
			<td>${onephase.getOrderKey()}</td>
			<td width="5%">
			<a href="javascript:editOrderKey(${onephase.getId()})"><img src="/u/shared/image/edit.png" height="18"></a>
			</td>
			<td>${onephase.getShortName()}</td>
			<td>${dayshow}</td>
			<td>${activstr}</td>
			<td>${opstuff}</td>
			</tr>
		`;
		
		mtstr += mainrow;


	});
	
	mtstr += `</table>`;
	

	populateSpanData({
		"show_inactive" : boolSelector,
		"maintable" : mtstr
	});
}

function getEditDayListData(daylist) 
{
	var s = "";

	daylist.forEach(function(day) {

		const a = `
			${day} <a href="javascript:removeDay4Item('${day}')"><img src="/u/shared/image/remove.png" height="16"/></a>

			&nbsp;
			&nbsp;
			&nbsp;
		`;

		s += a;
	});

	return s;
}

function redisplayEditItem()
{
	if(EDIT_STUDY_ITEM == -1)
		{ return; }

	var showItem = getEditStudyItem();
	const currentDays = getDayList4Item(showItem);
	const daylistEdit = getEditDayListData(currentDays);

	const addDays = ["---"].concat(SHORT_DAY_WEEK_LIST.filter(dow => !currentDays.includes(dow)));

	const dayaddsel = buildOptSelector()
						.configureFromList(addDays)
						.setElementName("on_day_sel")
						.setOnChange("javascript:addOnDayItem()")
						.getHtmlString();

	const showSelStr = currentDays.length == 7 ? "" : dayaddsel;
	
	const spandata = {
		"itemname" : showItem.getShortName(),
		"web_link" : showItem.getWebLink(),
		"isactive" : showItem.getIsActive() == 1 ? "YES" : "NO",
		"on_days" : daylistEdit,
		"on_day_sel_span" : showSelStr,
		"extra_info_box" : getExtraInfoBox().getHtmlString()
	};
	
	populateSpanData(spandata);
}

</script>

</head>

<body onLoad="javascript:redisplay()">


<center>

<span class="page_component" id="main_component">

<div class="topnav"></div>

<br/>


Show InActive: <span id="show_inactive"></span>

<br/>
<br/>

<a href="javascript:createNew()" class="css3button">NEW</a>


<br/><br/>


<div id="maintable"></div>

<br/>
</span>
 
<span class="page_component" id="edit_component">

<h3>Edit MRoutine Item</h3>

<br/><br/>

<table width="60%" class="basic-table">
<tr>
<td>Back</td>
<td></td>
<td><a href="javascript:back2Main()"><img src="/u/shared/image/leftarrow.png" height="18"/></a></td>
</tr>


<tr>
<td width="20%">Name</td>
<td><div id="itemname"></div></td>
<td><a href="javascript:editItemName()"><img src="/u/shared/image/edit.png" height=18/></a></td>
</tr>
<tr>
<td>Link</td>
<td><div id="web_link"></div></td>
<td><a href="javascript:editWebLink()"><img src="/u/shared/image/edit.png" height=18/></a></td>
</tr>

<tr>
<td>Active?</td>
<td><span id="isactive"></span>

</td>
<td><a href="javascript:flipActive()"><img src="/u/shared/image/cycle.png" height=18/></a></td>
</tr>    

<tr>
<td>Days</td>
<td><span id="on_days"></span></td>
<td><span id="on_day_sel_span"></td>
</tr>    

</table>

<br/>
<br/>

<div id="extra_info_box"></div>

</span>


</center>
</body>
</html>
