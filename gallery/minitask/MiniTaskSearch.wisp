
<html>
<head>
<title>Mini Task Search</title>

<wisp/>

<script>

var TODAY_CODE = getTodayCode();

const TYPE_SELECTOR_KEY = "typeSelKeY";

const YEAR_SELECTOR_KEY = "yearSelKeY";

var SEARCH_TERM = null;

const DUMMY_SEL = "---";

GENERIC_OPT_SELECT_MAP.set(TYPE_SELECTOR_KEY, DUMMY_SEL);

GENERIC_OPT_SELECT_MAP.set(YEAR_SELECTOR_KEY, DUMMY_SEL);


function redisplay()
{
	handleTopNav();


	setUpContolArea();

	reDispActiveTable();

}

function handleTopNav()
{
    populateTopNavBar(getHeaderInfo(), "Mini Task Search");
}


function getActiveYearList()
{
	return [... Array(30).keys()].map(delta => 2010 + delta);

}

function runSearch()
{
	const newterm = prompt("Add a search term:");

	if(newterm)
	{
		SEARCH_TERM = newterm.toLowerCase();
		redisplay();
	}

}

function clearSearch()
{
	SEARCH_TERM = null;
	redisplay();
}


function setUpContolArea()
{

    const typesel = buildOptSelector()
    					.setKeyList(MASTER_TYPE_LIST)
                        .sortByDisplay()
                        .setElementName(TYPE_SELECTOR_KEY)
                        .insertStartingPair(DUMMY_SEL, DUMMY_SEL)
                        .useGenericUpdater()
                        .getSelectString();



    const yearsel = buildOptSelector()
    					.setKeyList(getActiveYearList())
                        .sortByDisplay()
                        .setElementName(YEAR_SELECTOR_KEY)
                        .insertStartingPair(DUMMY_SEL, DUMMY_SEL)
                        .useGenericUpdater()
                        .getSelectString();


    var uidata = `

    	<br/>

    	Task Type: ${typesel}

    	<br/>

    	Year: ${yearsel}

    	<br/>

    	Search: <b>${SEARCH_TERM == null ? "---" : SEARCH_TERM}</b>

    	<a href="javascript:runSearch()"><button>search</button></a>
    	<a href="javascript:clearSearch()"><button>clear</button></a>

    	<br/>
    `;

    populateSpanData({"control_area" : uidata});
}

function textSearchHit(item)
{
	if(SEARCH_TERM == null)
		{ return true; }

	return item.getShortDesc().toLowerCase().indexOf(SEARCH_TERM) > -1;
}



function getSelectedItemList()
{
	const hits = [];

	const selecttype = GENERIC_OPT_SELECT_MAP.get(TYPE_SELECTOR_KEY);
	const selectyear = GENERIC_OPT_SELECT_MAP.get(YEAR_SELECTOR_KEY);

	W.getItemList("mini_task_list").forEach(function(item) {

		if(hits.length > 60) 
			{ return; }

		if(!(selecttype == DUMMY_SEL || item.getTaskType() == selecttype))
			{ return; }

		if(!(selectyear == DUMMY_SEL || item.getAlphaDate().startsWith(selectyear)))
			{ return; }

		if(!textSearchHit(item)) 
			{ return; }


		hits.push(item);
	});

	return hits;
}



function reDispActiveTable()
{

	var activelist = getSelectedItemList();
	
	// Sort by effective priority
	activelist.sort(proxySort(actrec => [-actrec.getPriority()]));

	
	var tablestr = `
		<table class="basic-table"  width="90%">
		<tr>
		<th>Type</th>
		<th>ShortDesc</th>
		<th>Start/End</th>
		<th>Age</th>
		<th>Priority</th>
		<th>---</th>
		</tr>
	`;
	
	
	activelist.forEach(function(activitem) {
				
		// const dayage = getTaskAge(activitem);
		const dayage = 111;
		
		var rowstr = `
			<tr>
			<td width="7">${activitem.getTaskType()}</td>
			<td>${activitem.getShortDesc()}</td>			
			<td>${activitem.getAlphaDate()} / ${activitem.getOmegaDate()}</td>	
			<td>${dayage}</td>			
		`;

		// Intrinsic priority
		{
			rowstr += `
				<td>
				${activitem.getPriority()}
				</td>
			`;
		}

		
		{
			const breaker = "&nbsp; &nbsp;";
			
			rowstr += `
				<td>					
				<a href="javascript:editStudyItem(${activitem.getId()})">
				<img src="/u/shared/image/inspect.png" height="18"></a>
				
				</td>
			`;
		}
		

			
		rowstr += "</tr>";
		
		tablestr += rowstr;	
	});

	
	tablestr += "</table>";
	
	populateSpanData({
		"activetable" : tablestr
	});
	
}


</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<div class="topnav"></div>


<div id="control_area"></div>

<br/>

<div id="activetable"></div>

<br/><br/>


</body>
</html>
