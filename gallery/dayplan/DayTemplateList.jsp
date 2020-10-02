
<%@ page import="java.util.*" %>

<%@ page import="net.danburfoot.shared.*" %>
<%@ page import="net.danburfoot.shared.DbUtil.*" %>
<%@ page import="net.danburfoot.shared.HtmlUtil.*" %>

<%@ page import="lifedesign.basic.*" %>
<%@ page import="lifedesign.classic.*" %><%@ page import="lifedesign.classic.JsCodeGenerator.*" %>

<%@include file="AuthInclude.jsp_inc" %>

<%
	ArgMap argMap = HtmlUtil.getArgMap(request);
	
	DayCode todayCode = DayCode.getToday();
		
	OptSelector endHourSel = new OptSelector(Util.range(1, 24));
	
	OptSelector timeSpentSel = new OptSelector(LifeUtil.getHourTimeMap());
	
	OptSelector dayCodeSel = new OptSelector(DayCode.getDayRange(DayCode.getToday().nDaysBefore(45), DayCode.getToday().nDaysAfter(4)));

	String pageTitle = "Day Template List";
	
	OptSelector templateSel = ClassicTech.getDayTemplateSelector(false);
	
%>

<html>
<head>
<title><%= pageTitle %></title>

<%@include file="AssetInclude.jsp_inc" %>

<%= JsCodeGenerator.getScriptInfo(request, "day_template", "template_sub") %>

<script>

function createNewTemplate()
{
	var newid = newBasicId("day_template");
	
	var templatename = prompt("Item Desc: ");
	
	if(templatename)
	{	
		var newtemplate = new DayTemplateItem(newid, templatename, "");
		
		newtemplate.registerNSync();
		
		redisplay();
	}
}

function deleteTemplateItem(killid)
{

	if(confirm("Are you sure you want to delete this template?"))
	{
		lookupItem("day_template", killid).deleteItem();
			
		redisplay();	
	}
}


function reDispActiveTable()
{
	
	var templatelist =  getItemList("day_template");
		
	var activetable = $('<table></table>').addClass('dcb-basic').attr("id", "dcb-basic").attr("width", "50%");
	
	{
		var row = $('<tr></tr>').addClass('bar');
	
		["ID", "ShortName", "..."].forEach( function (hname) {
		
			row.append($('<th></th>').text(hname));
		});
		
		activetable.append(row);	
	}
		
	for(var ti in templatelist)
	{
	
		var activitem = templatelist[ti];
	
		// console.log(oneday + " " + dci);

		var row = $('<tr></tr>').addClass('bar');
			
		//row.append($('<td></td>').text(activitem.getShortDesc()));
		row.append($('<td></td>').text(activitem.getId()));
		row.append($('<td></td>').text(activitem.getShortName()));
		
		{
			// var endhourstr = activitem.getEndHour();
			
			// var halfstr = activitem.getHalfHour() == 1 ? ":30" : ":00";
		
			// row.append($('<td></td>').attr("width", "15%").text(endhourstr + halfstr));
			
			
		}
		
		{
		
			
			var opcell = $('<td></td>').attr("width", "15%");
			
			{
				var viewurl = "DayDesignTemplate.jsp?temp_id=" + activitem.getId();
				
				var addtimeref = $('<a></a>').attr("href", viewurl).append(
										$('<img></img>').attr("src", "/life/image/inspect.png").attr("height", 18)
								);
				
				opcell.append(addtimeref);
			} 						
			
			for(var i = 0; i < 3; i++)
				{ opcell.append("&nbsp;"); }
				
				
			{
				var deletejs = "javascript:deleteTemplateItem(" + activitem.getId() + ")";
				
				var deleteref = $('<a></a>').attr("href", deletejs).append(
										$('<img></img>').attr("src", "/life/image/remove.png").attr("height", 18)
								);
				
				opcell.append(deleteref);
			} 						
			
				
						
			row.append(opcell);
		}
				
		
		
				
		// row.append($('<td></td>').attr("width", "15%").text(activitem.getAlphaDate()));
				
		
		
		// row.append($('<td></td>').attr("width", "10%").text(activitem.getRating()));
				
		activetable.append(row);
	}	
	
	
	
	
	$('#templatelist').html(activetable);	
	
	// $('#templatename').html(getSelectedTemplate().getShortName());
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

<br/>

<div id="templatelist"></div>

<br/><br/>


Create New:
<a href="javascript:createNewTemplate()">
<img src="/life/image/add.png" width="18"/></a> 


</body>
</html>
