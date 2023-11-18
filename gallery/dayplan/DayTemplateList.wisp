
<html>
<head>
<title>Day Plan Templates</title>

<wisp/>

<script>

EDIT_STUDY_ITEM = -1;

function createNewTemplate()
{
	const templatename = prompt("Item Desc: ");
	
	if(templatename)
	{
		const newid = newBasicId("day_template");
		const newrec = {
			"id" : newid,
			"short_name" : templatename,
			"full_desc" : "",
			"is_active" : 1
		}

		const newtemplate = buildItem("day_template", newrec);
		newtemplate.syncItem();
		redisplay();
	}
}

function deleteTemplateItem(killid)
{
	const kidlist = getItemList("template_sub").filter(sub => sub.getTempId() == killid);

	if(kidlist.length > 0)
	{
		alert("This template has child items. You must either delete all child items and then delete, or archive");
		return;
	}

	if(confirm("Are you sure you want to delete this template?"))
	{
		lookupItem("day_template", killid).deleteItem();			
		redisplay();	
	}
}

function archiveTemplate(itemid) 
{
	genericToggleActive("day_template", itemid);
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
	return lookupItem("day_template", EDIT_STUDY_ITEM);
}

function plusDefaultWakeUp()
{
	const newid = newBasicId("template_sub");
	const newrec = {
		"id" : newid,
		"temp_id" : EDIT_STUDY_ITEM,
		"end_hour" : 8,
		"half_hour" : 0,
		"short_desc" : "Jump Out of Bed!!"
	}

	const newitem = buildItem("template_sub", newrec);
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
	
	const plusmin = getDocFormValue("time_spent_min");
	const itemname = prompt("Item Desc: ");
	
	if(itemname)
	{	
		const newid = newBasicId("template_sub");	
		const previtem = itemlist.slice(-1)[0];			
		var totalmin = previtem.getEndHour() * 60 + previtem.getHalfHour() * 30;
		
		totalmin += plusmin*1;
		
		const newhour = Math.floor(totalmin/60);	
		const newhalf = (totalmin - newhour*60) > 15;
		
		// console.log("Total min " + totalmin + " newhour=" + newhour + " newhalf=" + newhalf);

		const newrec = {
			"id" : newid,
			"temp_id" : EDIT_STUDY_ITEM,
			"end_hour" : newhour,
			"half_hour" : newhalf ? 1 : 0,
			"short_desc" : itemname
		}

		const newitem = buildItem("template_sub", newrec);
		newitem.syncItem();
		redisplay();
	}
}

function createNew()
{

	const newid = newBasicId("template_sub");
	
	var itemname = prompt("Item Desc: ");
	
	if(itemname)
	{	
		const newrec = {
			"id" : newid,
			"temp_id" : EDIT_STUDY_ITEM,
			"end_hour" : getDocFormValue("end_hour"),
			"half_hour" : 0,
			"short_desc" : itemname
		}

		const newitem = buildItem("template_sub", newrec);
		newitem.syncItem();
		redisplay();
	}
}

function addTime2Item(itemid)
{
	const planitem = lookupItem("template_sub", itemid);
	
	if(planitem.getHalfHour() == 0)
	{
		planitem.setHalfHour(1);
	} else {
		planitem.setEndHour(planitem.getEndHour()+1);
		planitem.setHalfHour(0);
	}
	
	syncSingleItem(planitem);			
	redisplay();	
}

function removeTimeFromItem(itemid)
{
	const planitem = lookupItem("template_sub", itemid);
	
	if(planitem.getHalfHour() == 1)
	{
		planitem.setHalfHour(0);
	} else {
		planitem.setEndHour(planitem.getEndHour()-1);
		planitem.setHalfHour(1);
	}
	
	syncSingleItem(planitem);			
	redisplay();	
}

function deleteItem(killid)
{
	genericDeleteItem("template_sub", killid);
}

function getPlanDayItemList()
{
	var biglist = getItemList("template_sub").filter(item => item.getTempId() == EDIT_STUDY_ITEM);
	return biglist.sort(proxySort(item => [item.getEndHour()]));
}

function editTemplateName(editid)
{
	genericEditTextField("day_template", "short_name", editid);
}

function editItemName(editid)
{
	const theitem = lookupItem("template_sub", editid);
	const newname = prompt("New info for item: ", theitem.getShortDesc());

	if(newname)
	{
		theitem.setShortDesc(newname);
		syncSingleItem(theitem);			
		redisplay();		
	}
}

function getPageComponent()
{
	return EDIT_STUDY_ITEM == -1 ? "main_list" : "study_item";
}

function redisplay()
{
	redisplayMainList();
	redisplayStudyItem();

	setPageComponent(getPageComponent());
}

function redisplayMainList()
{
	
	var templatelist =  getItemList("day_template");

	var mainstr = `
		<table class="basic-table"  width="50%">
		<tr>
		<th>Name</th>
		<th width="5%">Active?</th>		
		<th width="30%">...</th>
		</tr>
	`;

	const breaker = `&nbsp; &nbsp;`
		
	const showinactive = getUniqElementByName("show_inactive").checked;

	templatelist.forEach(function(item) {

		if(item.getIsActive() == 0 && !showinactive)
			{ return; }

		const activstr = item.getIsActive() == 1 ? "Y" : "N";

		const rowstr = `
			<tr>
			<td>${item.getShortName()}</td>
			<td>${activstr}</td>			
			<td>

			<a href="javascript:editTemplateName(${item.getId()})">
			<img src="/u/shared/image/edit.png" height="18"/></a>

			${breaker}

			<a href="javascript:editStudyItem(${item.getId()})">
			<img src="/u/shared/image/inspect.png" height="18"/></a>

			${breaker}

			<a href="javascript:archiveTemplate(${item.getId()})">
			<img src="/u/shared/image/cycle.png" height="18"/></a>

			${breaker}

			<a href="javascript:deleteTemplateItem(${item.getId()})">
			<img src="/u/shared/image/remove.png" height="18"/></a>

			</td>
			</tr>
		`;


		mainstr += rowstr;
	});

	mainstr += `<table>`;

	populateSpanData({
		"templatelist" : mainstr
	});	
}	
	

function getHourTimeMap()
{
	var hourmap = {};

	hourmap[30] = "30 min";
	hourmap[60] = "60 min";
	hourmap[90] = "90 min";

	
	for(var exhour = 2; exhour < 10; exhour++)
	{
		[true, false].forEach(function(ishalf) {

			// Don't need to be precise for > 5 hours
			if(exhour > 4 && ishalf == true)
				{ return; }

			const halfstr = ishalf ? ".5" : "";
			const label = `${exhour}${halfstr} hr`;
			const mincount = exhour * 60 + (ishalf ? 30 : 0);
			hourmap[mincount] = label;
		});
	}

	return hourmap;
}


function redisplayStudyItem()
{
	if(EDIT_STUDY_ITEM == -1) 
		{ return; }

	var mainstr = `
		<table class="basic-table"  width="50%">
		<tr>
		<th>Desc</th>
		<th>..</th>
		<th>EndTime</th>
		<th>TimeSpent</th>
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
			<td>${item.getShortDesc()}</td>
			<td>

			<a href="javascript:editItemName(${item.getId()})">
			<img src="/u/shared/image/edit.png" height="18"/></a>
			
			</td>
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
	

	mainstr += `</table>`

	const endhourlist = [... Array(25).keys()];

	const endsel = buildOptSelector()
					.setKeyList(endhourlist)
					.setElementName("end_hour")
					.setSelectedKey(8)
					.autoPopulate();

	const timesel = buildOptSelector()
						.setFromMap(getHourTimeMap())
						.setElementName("time_spent_min")
						.setSelectedKey(60)
						.autoPopulate();

	populateSpanData({
		"dayplantable" : mainstr,
		"templatename" : getSelectedTemplate().getShortName()
	});




}

</script>

</head>

<body onLoad="javascript:redisplay()">


<center>

<br/>


<span class="page_component" id="main_list">

<h3>Day Plan Templates</h3>


Inactive? <input type="checkbox" name="show_inactive" onChange="javascript:redisplay()"/>
<br/>
<br/>

<div id="templatelist"></div>

<br/><br/>

<a class="css3button" onclick="javascript:createNewTemplate()">NEW</a> 

</span>

<span class="page_component" id="study_item">

<h3><span id="templatename"></div></h3>


<a href="javascript:back2Main()">
<img src="/u/shared/image/leftarrow.png" height="18"/></a>

<br/><br/>


<div id="dayplantable"></div>

<br/><br/>

End Time: 
<span id="end_hour_span"></span>

<a href="javascript:createNew()">
<img src="/u/shared/image/add.png" width="18"/></a>

<br/><br/>

Hour Spent: 
<span id="time_spent_min_span"></span>

<a href="javascript:newByHourSpent()">
<img src="/u/shared/image/add.png" width="18"/></a>


<br/><br/><br/>

wakeup
<a href="javascript:plusDefaultWakeUp()">
<img src="/u/shared/image/add.png" width="18"/></a> 

</span>

</body>
</html>
