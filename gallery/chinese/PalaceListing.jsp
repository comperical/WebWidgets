
<html>
<head>
<title>Memory Palace Listing</title>

<script src="ChineseTech.js"></script>

<%= DataServer.basicIncludeOnly(request, "palace_item") %>

<script>

function createNew()
{	
	var newid = newBasicId("palace_item");
	
	// created_on, active_on, completed_on, dead_line
	var newrec = {
		"id" : newid,
		"hanzi_char" : "x",
		"palace_note": "EnterNoteHere",
		"extra_note" : "...",
		"meaning": "EnterMeaningHere"
	};		
	
	const newitem = buildPalaceItemItem(newrec);
	newitem.syncItem();
	redisplay();
	
	const newurl = "PalaceItemEdit.jsp?item_id=" + newid;
	window.location.href=newurl;
}

function deleteItem(killid)
{
	if(confirm("Warning: it's usually better to deactivate or edit!! \n\nAre you sure you want to delete this character item?"))
	{
		lookupItem("palace_item", killid).deleteItem();
		
		redisplay();
	}
}

function redisplay()
{
	var itemlist = getItemList("palace_item");
	itemlist.sort(proxySort(a => [a.getId()])).reverse();
	
	// var lastlogmap = getLastLogMap();
					
	var tablestr = `
		<table  class="basic-table" width="70%">
		<tr>
		<th>ID</th>
		<th>Character</th>
		<th>Meaning</th>
		<th>Note</th>
		</tr>
	`;

	itemlist.forEach(function(item) {

		const palnote = getFirstPalaceNote(item.getPalaceNote());

		const rowstr = `
			<tr>
			<td>${item.getId()}</td>
			<td>${item.getHanziChar()}</td>
			<td>${item.getMeaning()}</td>
			<td>${palnote}</td>
			</tr>
		`;
	
		tablestr += rowstr;
	});
	
	tablestr += "</table>";

	populateSpanData({
		"maintable" : tablestr
	});
}



</script>




</head>

<body onLoad="javascript:redisplay()">

<center>

<h2>Memory Palace</h2>

<a class="css3button" onclick="javascript:createNew()">NEW</a>

<br/>
<br/>

<div id="maintable"></div>


<br/>



</center>
</body>
</html>
