
<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@include file="../../life/AuthInclude.jsp_inc" %>

<%
	OptSelector boolSelector = (new OptSelector(Util.listify(true,false)));	
%>

<html>
<head>
<title>Morning Routine Phases</title>

<%@include file="../../life/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

<script>

var EDIT_STUDY_ITEM = -1;

function changeShowType()
{
	redisplay();
}


function deleteItem(killid)
{
	if(confirm("Are you sure you want to delete item " + killid + " ?"))
	{
		lookupItem("mroutine_phase", killid).deleteItem();
		redisplay();
	}
}

function cycleStatus(cycid)
{
	var item = lookupItem("mroutine_phase", cycid);
	item.setIsActive(item.getIsActive() == 1 ? 0 : 1);
	syncSingleItem(item);
	redisplay();	
}

function createNew()
{	
	var shortname = prompt("Name of new phase: ");
	
	if(shortname)
	{	
		var newid = newBasicId("mroutine_phase");
			
		var comrecord = {
			"id" : newid,
			"is_active" : 1,
			"short_name" : shortname,
			"full_desc": "NotYetSet",
			"web_link" : "http://danburfoot.net",
			"order_key" : newid
		};
		
		var newitem = buildMroutinePhaseItem(comrecord);
		newitem.registerNSync();
		redisplay();
	}	
}

function editOrderKey(itemid)
{
	const phaseitem = lookupItem("mroutine_phase", itemid);
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
	syncSingleItem(phaseitem);
	redisplay();
}



function flipActive()
{
	var showItem = getEditStudyItem();

	var curActive = showItem.getIsActive();
	
	showItem.setIsActive(curActive == 1 ? 0 : 1);
	
	syncSingleItem(showItem);		

	redisplay();
}

function saveNewDesc()
{
	var showItem = getEditStudyItem();

	var newDesc = getDocFormValue("fullitemdesc");
	
	showItem.setFullDesc(newDesc);
	
	syncSingleItem(showItem);		

	redisplay();
}

function editIssueDesc()
{
	const showItem = getEditStudyItem();
	const newissue = prompt("Enter issue: ");
	
	if(newissue)
	{
		showItem.setIssueDesc(newissue);
	
		syncSingleItem(showItem);		
		
		redisplay();	
	
	}
}

function editItemName()
{
	const showitem = getEditStudyItem()
	const newname = prompt("Enter a new short name: ", showitem.getShortName());
	
	if(newname)
	{		
		showitem.setShortName(newname);
		syncSingleItem(showitem);		
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
		syncSingleItem(showitem);		
		redisplay();		
	}
}

function getEditStudyItem()
{
	return lookupItem("mroutine_phase", EDIT_STUDY_ITEM);
}
                      
function setEditStudyItem(studyid)
{
	EDIT_STUDY_ITEM = studyid;
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
	redisplayMainTable();
	
	redisplayEditItem();
		
	setPageComponent(getPageComponent());
}

function redisplayMainTable()
{
	var mtstr = `
	<table class="dcb-basic" id="dcb-basic" width="60%">
	<tr>
	<th>OrderKey</th>
	<th>Name</th>
	<th>Active?</th>
	<th>---</th>
	</tr>
	`;

	var biglist = getItemList("mroutine_phase");
	biglist.sort(proxySort(item => [item.getOrderKey()]));

	var showInActive = getDocFormValue("show_inactive") == "true";
	
	// biglist.sort(proxySort(irec => [irec.getMainType(), irec.getShortname()]));
		
	{
		for(var bi in biglist)
		{
			var onephase = biglist[bi];
			
			if(onephase.getIsActive() == 0 && !showInActive)
				{ continue; }
						
			const opstuff = `
				<a href="javascript:setEditStudyItem(${onephase.getId()})"><img src="/life/image/inspect.png" height="18"></a>
				&nbsp;&nbsp;&nbsp;
				<a href="${onephase.getWebLink()}"><img src="/life/image/chainlink.png" height="18"></a>
				&nbsp;&nbsp;&nbsp;
				<a href="javascript:cycleStatus(${onephase.getId()})">
				<img src="/life/image/cycle.png" height="18"></a>
				&nbsp;&nbsp;&nbsp;
				<a href="javascript:deleteItem(${onephase.getId()})"><img src="/life/image/remove.png" height="18"></a>
			`;
			
			
			var datalist = [onephase.getId(), onephase.getShortName(), onephase.getOrderKey(),
					onephase.getWebLink(),
					onephase.getIsActive(), opstuff];
			
			
			const activstr = onephase.getIsActive() == 1 ? "Y" : "N";
					
			const mainrow = `
			<tr>
			<td>${onephase.getOrderKey()}
			&nbsp;&nbsp;&nbsp;
			<a href="javascript:editOrderKey(${onephase.getId()})"><img src="/life/image/edit.png" height="18"></a>
			</td>			
			<td>${onephase.getShortName()}</td>
			<td>${activstr}</td>
			<td>${opstuff}</td>
			</tr>
			`;
			
			mtstr += mainrow;
		}	
	
	}
	
	mtstr += `</table>`;
	
	document.getElementById("maintable").innerHTML = mtstr;
}

function redisplayEditItem()
{
	if(EDIT_STUDY_ITEM == -1)
		{ return; }

	var showItem = getEditStudyItem();
		
	// Okay, this took me a while to get right. The issue is that 
	// the standard string.replace(...) won't do a global, and there is no replaceAll
	const desclinelist = showItem.getFullDesc().replace(/\n/g, "<br/>");
	
	const spandata = {
		"itemname" : showItem.getShortName(),
		"web_link" : showItem.getWebLink(),
		"itemdescline" : desclinelist,
		"fullitemdesc" : showItem.getFullDesc(),
		"isactive" : showItem.getIsActive() == 1 ? "YES" : "NO"
	};
	
	populateSpanData(spandata);
}

</script>

</head>

<body onLoad="javascript:redisplay()">


<center>

<span class="page_component" id="main_component">


<h3>Morning Routine Phases</h3>



<form>
Show InActive: 
<select name="show_inactive" onChange="javascript:redisplay()">
<%= boolSelector.getSelectStr("false") %>
</select>

</form>

<a href="javascript:createNew()" class="css3button">NEW</a>


<br/><br/>


<div id="maintable"></div>

<br/>
</span>
 
<span class="page_component" id="edit_component">

<h3>Edit MRoutine Item</h3>

<br/><br/>

<table width="30%" id="dcb-basic">
<tr>
<td>Back</td>
<td></td>
<td><a href="javascript:back2Main()"><img src="/life/image/leftarrow.png" height="18"/></a></td>
</tr>
<tr>
<td width="50%">Name</td>
<td><div id="itemname"></div></td>
<td><a href="javascript:editItemName()"><img src="/life/image/edit.png" height=18/></a></td>
</tr>
<tr>
<td width="50%">Link</td>
<td><div id="web_link"></div></td>
<td><a href="javascript:editWebLink()"><img src="/life/image/edit.png" height=18/></a></td>
</tr>

<tr>
<td width="50%">Active?</td>
<td><span id="isactive"></span>

</td>
<td><a href="javascript:flipActive()"><img src="/life/image/cycle.png" height=18/></a></td>
</tr>    
</table>

<br/>
<br/>

<table id="dcb-basic" width="30%">
<tr>
<td>
<span id="itemdescline">xxx<br/>yyy</span>
</td>
</tr>
</table>

<br/>
<br/>

<form>
<textarea id="fullitemdesc" name="fullitemdesc" rows="10" cols="50"></textarea>
</form>

<a href="javascript:saveNewDesc()">save desc</a>

</span>


</center>
</body>
</html>
