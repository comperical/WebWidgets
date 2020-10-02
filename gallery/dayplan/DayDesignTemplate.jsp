
<%@ page import="java.util.*" %>

<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.DbUtil.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@ page import="lifedesign.basic.*" %>
<%@ page import="lifedesign.classic.*" %><%@ page import="lifedesign.classic.JsCodeGenerator.*" %>

<%@include file="AuthInclude.jsp_inc" %>

<%
	ArgMap argMap = HtmlUtil.getArgMap(request);
	
	int curTempId = argMap.getInt("temp_id", 4);
		
	OptSelector ratingSel = new OptSelector(Util.range(1, 10));
	
	DayCode todayCode = DayCode.getToday();
		
	OptSelector endHourSel = new OptSelector(Util.range(1, 24));
	
	OptSelector timeSpentSel = new OptSelector(LifeUtil.getHourTimeMap());
	
	OptSelector dayCodeSel = new OptSelector(DayCode.getDayRange(DayCode.getToday().nDaysBefore(45), DayCode.getToday().nDaysAfter(4)));
	
	String pageTitle = "Day Template Designer";	
%>

<html>
<head>
<title><%= pageTitle %></title>

<%@include file="AssetInclude.jsp_inc" %>

<%= JsCodeGenerator.getScriptInfo(request, "day_template", "template_sub") %>

<script>

function getSelectedTemplate()
{
	return DayTemplateTable._dataMap["<%= curTempId %>"];
}

function plusDefaultWakeUp()
{
	var newid = newBasicTemplateSubId();

	var newplanitem = new TemplateSubItem(newid, '<%= curTempId %>',  8, 0, "Jump Out of Bed!!");
	
	newplanitem.registerNSync();
	
	redisplay();
}


function newByHourSpent()
{
	var itemlist = getPlanDayItemList();
	
	if(itemlist.length == 0)
	{
		alert("You must create at least one record first");
		return;
	}
	
	var plusmin = getDocFormValue("time_spent_min");

	var newid = newBasicTemplateSubId();
	
	var itemname = prompt("Item Desc: ");
	
	var previtem = itemlist.slice(-1)[0];	
	
	var totalmin = previtem.getEndHour() * 60 + previtem.getHalfHour() * 30;
	
	totalmin += plusmin*1;
	
	var newhour = Math.floor(totalmin/60);	
	
	var newhalf = (totalmin - newhour*60) > 15;
	
	console.log("Total min " + totalmin + " newhour=" + newhour + " newhalf=" + newhalf);
	
	if(itemname)
	{	
		var newplanitem = new TemplateSubItem(newid, <%= curTempId %>,  newhour, newhalf ? 1 : 0, itemname);
		
		newplanitem.registerNSync();
		
		redisplay();
	}
}

function createNew()
{
	var newid = newBasicTemplateSubId();
	
	var itemname = prompt("Item Desc: ");
	
	if(itemname)
	{	
		var newplanitem = new TemplateSubItem(newid, <%= curTempId %>,  getDocFormValue("end_hour"), 0, itemname);
		
		newplanitem.registerNSync();
		
		redisplay();
	}
}

function addTime2Item(itemid)
{
	var planitem = TemplateSubTable._dataMap[itemid];
	
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
	var planitem = TemplateSubTable._dataMap[itemid];
	
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
	lookupTemplateSubItem(killid).deleteItem();
		
	redisplay();
}

function getPlanDayItemList()
{
	var itemlist = [];

	var biglist = getTemplateSubItemList();
	
	for(var bi in biglist)
	{
		var planitem = biglist[bi];
		
		if(planitem.getTempId() == <%= curTempId %>)
		{
			itemlist.push(planitem);
		}
	}
	
	itemlist.sort(function(a, b) { return a.getEndHour() - b.getEndHour(); });
	

	return itemlist;
}

function editItemName(editid)
{
	var theitem = TemplateSubTable._dataMap[editid];
	var newname = prompt("New info for item: ", theitem.getShortDesc());

	if(newname)
	{
		theitem.setShortDesc(newname);
		syncSingleItem(theitem);			
		redisplay();		
	}
}

function reDispActiveTable()
{
	
	var activelist = getPlanDayItemList();
		
	var activetable = $('<table></table>').addClass('dcb-basic').attr("id", "dcb-basic").attr("width", "50%");
	
	{
		var row = $('<tr></tr>').addClass('bar');
	
		["Desc", "EndTime", "TimeSpent", "---"].forEach( function (hname) {
		
			row.append($('<th></th>').text(hname));
		});
		
		activetable.append(row);	
	}
		
	
	
	for(var ai in activelist)
	{
	
		var activitem = activelist[ai];
	
		// console.log(oneday + " " + dci);

		var row = $('<tr></tr>').addClass('bar');
			
		row.append($('<td></td>').text(activitem.getShortDesc()));					
		
		{
			var endhourstr = activitem.getEndHour();
			
			var halfstr = activitem.getHalfHour() == 1 ? ":30" : ":00";
		
			row.append($('<td></td>').attr("width", "15%").text(endhourstr + halfstr));
			
			
		}
		
		{
			var timespent = "---";
			
			if(ai > 0)
			{
				var previtem = activelist[ai-1];
				
				var totalmin = activitem.getEndHour()*60 - previtem.getEndHour()*60;
				
				totalmin += (activitem.getHalfHour()*30);
				
				totalmin -= (previtem.getHalfHour()*30);
				
				var totalhour = totalmin/60;
				
				timespent = totalhour.toFixed(1) + " hr";
				
			}
			
			row.append($('<td></td>').attr("width", "15%").text(timespent));
		}
				
		
		
				
		// row.append($('<td></td>').attr("width", "15%").text(activitem.getAlphaDate()));
				
		
		{
		
			
			var opcell = $('<td></td>').attr("width", "20%");

			{
				var addtimejs = "javascript:editItemName(" + activitem.getId() + ")";
				
				
				var addtimeref = $('<a></a>').attr("href", addtimejs).append(
										$('<img></img>').attr("src", "/life/image/edit.png").attr("height", 18)
								);
				
				opcell.append(addtimeref);
			} 						
			
			for(var i = 0; i < 3; i++)
				{ opcell.append("&nbsp;"); }

			
			{
				var addtimejs = "javascript:addTime2Item(" + activitem.getId() + ")";
				
				
				var addtimeref = $('<a></a>').attr("href", addtimejs).append(
										$('<img></img>').attr("src", "/life/image/upicon.png").attr("height", 18)
								);
				
				opcell.append(addtimeref);
			} 						
			
			for(var i = 0; i < 3; i++)
				{ opcell.append("&nbsp;"); }



				
			{
				var remtimejs = "javascript:removeTimeFromItem(" + activitem.getId() + ")";
				
				
				var remtimeref = $('<a></a>').attr("href", remtimejs).append(
										$('<img></img>').attr("src", "/life/image/downicon.png").attr("height", 18)
								);
				
				opcell.append(remtimeref);
			} 						
			
			for(var i = 0; i < 3; i++)
				{ opcell.append("&nbsp;"); }				
				
			
			
			{
				// var deletejs = "javascript:deleteItem(" + possitem.getId() + ", '" + possitem.getShortname() + "')";
			
				var deletejs = "javascript:deleteItem(" + activitem.getId() + ")";
				
				
				var deleteref = $('<a></a>').attr("href", deletejs).append(
										$('<img></img>').attr("src", "/life/image/remove.png").attr("height", 18)
								);
				
				opcell.append(deleteref);
			} 			
			
			
						
			row.append(opcell);
		}
		
		
		
		// row.append($('<td></td>').attr("width", "10%").text(activitem.getRating()));
				
		activetable.append(row);
	}
	
	$('#dayplantable').html(activetable);	
	
	$('#templatename').html(getSelectedTemplate().getShortName());
}

function redisplay()
{
	reDispActiveTable();
}

function changeTemplate()
{
	var newtempid = getDocFormValue("newtempid");
	var subpack = {"temp_id": newtempid };

	submit2Base(subpack);
}



</script>

</head>

<body onLoad="javascript:redisplay()">


<center>

<br/>


<h3><%= pageTitle %></h3>

<a href="/life/DayTemplateList.jsp">Main Listing</a>

<br/>

<h3>TEMPLATE for <span id="templatename"></div></h3>

<br/>

<div id="dayplantable"></div>

<br/><br/>

End Time: <select name="end_hour">
<%= endHourSel.getSelectStr("16") %>
</select>

<a href="javascript:createNew()">
<img src="/life/image/add.png" width="18"/></a>

<br/><br/>

Hour Spent: <select name="time_spent_min">
<%= timeSpentSel.getSelectStr("90") %>
</select>

<a href="javascript:newByHourSpent()">
<img src="/life/image/add.png" width="18"/></a>


<br/><br/><br/>

wakeup
<a href="javascript:plusDefaultWakeUp()">
<img src="/life/image/add.png" width="18"/></a> 


</body>
</html>
