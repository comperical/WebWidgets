
<html>
<head>
<title>Finance Agg</title>

<%= DataServer.include(request) %>

<style>

.missedtarget
{
	color: red;
}

.goodtarget
{
	color: green;
}


</style>


<script>


function getLastMonthDay() 
{
	// Last day of month of last record
	const items = W.getItemList("finance_main").sort(proxySort(item => [item.getTransactDate()]));

	const lastrec = lookupDayCode(items[items.length-1].getTransactDate());
	var daypntr = lastrec;

	const day2Month = function(dc) { return dc.getDateString().substring(0,7); }


	while(day2Month(lastrec) == day2Month(daypntr))
		{ daypntr = daypntr.dayAfter(); }

	return daypntr.dayBefore().getDateString();
}

AGG_WINDOW_OMEGA = getLastMonthDay();

AGG_WINDOW_SIZE = 60;

function getAggWindowAlpha() 
{
	return lookupDayCode(AGG_WINDOW_OMEGA).nDaysBefore(AGG_WINDOW_SIZE).getDateString();
}


HIDDEN_MAP = { "taxes" : true };

PINNED_MAP = { };

function updateAggWindowSize() 
{
	const ndays = getDocFormValue("agg_window_size");
	AGG_WINDOW_SIZE = parseInt(ndays);
	redisplay();
}

function getCat2ReccMap(notemap)
{
	var reccmap = {};
	
	for(var cat in notemap)
	{
		reccmap[cat] = [];
		
		var notelist = notemap[cat];
	
		for(var ni in notelist)
		{
			var noteitem = notelist[ni];
		
			var recitem = lookupItem("finance_main", noteitem.getId());
			
			reccmap[cat].push(recitem);
		}
	}
	
	return reccmap;
}

function getDailyTargetMap()
{
	const tmap = {};

	W.getItemList("finance_plan").forEach(function(item) {
		tmap[item.getCategory()] = -(item.getMonthlyTarget() / 30) * 100;
	});

	return tmap;
}


function getCat2NoteMap(startday, endday)
{
	var catmap = {};	

	W.getItemList("finance_main").forEach(function(mainitem) {
	
		if(!(startday <= mainitem.getTransactDate() && mainitem.getTransactDate() <= endday))
			{ return; }
		
		const expcat = mainitem.getExpenseCat();
		
		if(!catmap.hasOwnProperty(expcat))
		{
			catmap[expcat] = [];	
		}
		
		catmap[expcat].push(mainitem);
	});

	return catmap;
}

// TODO: copy of code in FinanceLog.jsp
function getDollarFormat(centamount)
{
	var dollamount = centamount/100;
	
	if(dollamount < 0)
	{
		return (-dollamount).toFixed(2);
	}
	
	return "+++" + dollamount.toFixed(2);
}

function getDataFrameList()
{
	var cat2NoteMap = getCat2NoteMap(getAggWindowAlpha(), AGG_WINDOW_OMEGA);
	var cat2ReccMap = getCat2ReccMap(cat2NoteMap);

	var framelist = [];

	for(var expcat in cat2NoteMap)
	{
		if (expcat in HIDDEN_MAP) 
			{ continue; }

		var notelist = cat2NoteMap[expcat];
		var recclist = cat2ReccMap[expcat];
	
		// console.log(recclist[0]);
		
		var frameitem = {};
		
		var centsum = recclist
				.map(recc => recc.getCentAmount())
				.reduce((a, b) => a + b, 0);
				
		// var sum = [1, 2, 3].reduce((a, b) => a + b, 0);
		

		if(expcat in PINNED_MAP) 
		{
			centsum = (-PINNED_MAP[expcat] * AGG_WINDOW_SIZE)*100;
		}
		
		frameitem.expcat = expcat;
		frameitem.centsum = centsum;
		frameitem.numrec = notelist.length;
		frameitem.perday = (centsum / AGG_WINDOW_SIZE);
		frameitem.extrap2year = (frameitem.perday * 365);
		
		framelist.push(frameitem);
	}		
	
	return framelist;
}


function pinCategoryValue(category)
{
	const newpin = prompt(`Pin the daily expenses for category ${category} to : `);

	if(newpin)
	{
		if(!okayFloat(newpin))
		{
			alert("Please enter a valid number");
			return;
		}

		PINNED_MAP[category] = parseFloat(newpin);
		redisplay();
	}

}

function removePin(category) 
{
	delete PINNED_MAP[category];
	redisplay();
}

function removeHiddenMarker(category)
{
	delete HIDDEN_MAP[category];
	redisplay();	
}

function getAggWindowInfo() 
{

	var infostr = `
		<h4>${getAggWindowAlpha()} :: ${AGG_WINDOW_OMEGA}</h4>
	`;

	const ndaylist = [30, 60, 90, 120, 180, 365, 730];

	const optsel = buildOptSelector()
						.setKeyList(ndaylist)
						.setSelectedKey(AGG_WINDOW_SIZE)
						.setSelectOpener(`<select name="agg_window_size" onChange="javascript:updateAggWindowSize()">`)
						.getSelectString();

	infostr += `
		Last NDays: ${optsel}
	`;

	return infostr;
}

function handleNavBar() 
{
    populateTopNavBar(getFinanceHeaderInfo(), "Finance Agg");
}

function redisplay()
{
	handleNavBar();

	var tablestr = `
		<table class="basic-table"  width="75%">
		<tr>
		<th>Category</th>
		<th>Total</th>
		<th>#Rec</th>
		<th>Per Day Avg</th>
		<th>Target</th>
		<th>Delta</th>
		<th>Year Extrapolation</th>
		<th>Pin</th>		
		</tr>
	`;
	const targetmap = getDailyTargetMap();
	var framelist = getDataFrameList();
	
	framelist.sort((a, b) => a.centsum - b.centsum);
	
	var dailytotal = 0;
	var yearlytotal = 0;
	
	framelist.forEach(function(frameitem) {
			
		var expcat = frameitem.expcat;
		
		if(expcat == "ignore" || expcat == "uncategorized")
			{ return; }

		var targetstr = "---";
		var deltastr = "---";
		var tdclass = "goodtarget";

		if(expcat in targetmap)
		{
			const dailytarget = expcat in targetmap ? targetmap[expcat] : frameitem.perday
			const missedtarget = ((frameitem.perday - dailytarget) / 100);
			tdclass = missedtarget < 0 ? "missedtarget" : "goodtarget";
			deltastr = missedtarget.toFixed(2);
			targetstr = (-targetmap[expcat] / 100).toFixed(2);
		}


		
		const dollarstr = getDollarFormat(frameitem.centsum);
		const perdaystr = getDollarFormat(frameitem.perday);
		const extrastr = getDollarFormat(frameitem.extrap2year);

		/*
		const pinlink = expcat in PINNED_MAP
					? `<a href="javascript:removePin('${expcat}')"><img src="/u/shared/image/trashbin.png" height="16"/></a>`
					: `<a href="javascript:pinCategoryValue('${expcat}')"><img src="/u/shared/image/pin.png" height="16"/></a>`;

		*/

		const pinlink = `
			<a href="javascript:pinCategoryValue('${expcat}')"><img src="/u/shared/image/pin.png" height="16"/></a> 
			
			&nbsp;
			&nbsp;

			<a href="javascript:pinCategoryValue('${expcat}')"><img src="/u/shared/image/broomstick.png" height="16"/></a>
		`;


		const rowstr = `
			<tr>
			<td>${expcat}</td>
			<td>${dollarstr}</td>
			<td>${frameitem.numrec}</td>
			<td>${perdaystr}</td>
			<td>${targetstr}</td>			
			<td class="${tdclass}">${deltastr}</td>			
			<td>${extrastr}</td>
			<td>${pinlink}</td>			
			</tr>
		`;
				
		dailytotal += frameitem.perday;
		
		yearlytotal += frameitem.extrap2year;
		
		tablestr += rowstr;
		
	});
	
	tablestr += "</table>";
		
	populateSpanData({
		"aggtable" : tablestr,
		"dailytotal" : getDollarFormat(dailytotal),
		"yearlytotal" : getDollarFormat(yearlytotal),
		"hidden_table" : getHiddenTableString(),
		"agg_window_info" : getAggWindowInfo()
	});
}

function getHiddenTableString()
{

	var tablestr = `
		<table class="basic-table" width="30%">
		<th colspan="2">Hidden / Pinned</th>
		</tr>
	`;

	Object.keys(HIDDEN_MAP).forEach(function(hidcat) {

		tablestr += `
			<tr>
			<td>${hidcat}</td>
			<td>
			<a href="javascript:removeHiddenMarker('${hidcat}')"><img src="/u/shared/image/trashbin.png" height="18"/></a>
			</td>
			</tr>
		`
	});


	Object.keys(PINNED_MAP).forEach(function(hidcat) {

		const pinval = PINNED_MAP[hidcat];

		tablestr += `
			<tr>
			<td>${hidcat} = ${pinval}</td>
			<td>
			<a href="javascript:removePin('${hidcat}')"><img src="/u/shared/image/trashbin.png" height="18"/></a>
			</td>
			</tr>
		`
	});	

	tablestr += "</table>";

	return tablestr;

}


</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<div class="topnav"></div>

<br/>

<div id="agg_window_info"></div>


<h4>
Total Daily : <span id="dailytotal"></span>
<br/>
Total Yearly : <span id="yearlytotal"></span>
</h4>

<div id="aggtable"></div>


<br/><br/>

<div id="hidden_table"></div>



</center>
</body>
</html>
