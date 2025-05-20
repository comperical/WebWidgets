<html>
<head>

<wisp/>

<script>

var EDIT_STUDY_ITEM = -1;

const MAIN_TABLE = "shared_expense";

const CODE_TO_NAME_MAP = {
	"D" : "Dan",
	"H" : "Heather"
}

function deleteItem(itemid) {
	const item = W.lookupItem('shared_expense', itemid)
	item.deleteItem();
	redisplay();
}

function createNewDan() {
	createNewSub("D");
}


function createNewHeather() {

	createNewSub("H");
}


// Auto-generated create new function
function createNewSub(payer) {


	const notes = prompt("Enter a note for this expense: ");
	if(notes)
	{
		const newrec = {
			'dollar_amount' : 0,
			'payer' : payer,
			'day_code' : getTodayCode().getDateString(),
			'web_link' : '',
			'notes' : notes
		};
		const newitem = W.buildItem('shared_expense', newrec);
		newitem.syncItem();
		EDIT_STUDY_ITEM = newitem.getId();
		redisplay();
	}
}


function createNewHonda()
{
	if(confirm("Create a Honda CRV payment?"))
	{
		const newrec = {
			'dollar_amount' : 551,
			'payer' : 'D',
			'day_code' : getTodayCode().getDateString(),
			'web_link' : '',
			'notes' : 'honda CRV payment'
		};
		const newitem = W.buildItem('shared_expense', newrec);
		newitem.syncItem();
		EDIT_STUDY_ITEM = newitem.getId();
		redisplay();
	}
}


function createNewFlexCar()
{
	if(confirm("Create a new FlexCar record?"))
	{
		const newrec = {
			'dollar_amount' : 558,
			'payer' : 'D',
			'day_code' : getTodayCode().getDateString(),
			'web_link' : '',
			'notes' : 'flexcar'
		};
		const newitem = W.buildItem('shared_expense', newrec);
		newitem.syncItem();
		EDIT_STUDY_ITEM = newitem.getId();
		redisplay();
	}
}


function isPayerDan(payer)
{
	massert(["D", "H"].indexOf(payer) > -1, "Invalid payer name " + payer);
	return payer == "D";
}

function togglePayer()
{
	togglePayerSub(EDIT_STUDY_ITEM);
}

function togglePayerSub(itemid)
{
	const item = W.lookupItem("shared_expense", itemid);
	const isdan = isPayerDan(item.getPayer());
	item.setPayer(isdan ? "H" : "D");
	item.syncItem();
	redisplay();

}

function getSummaryTable()
{

	const totalpay = new Map();
	totalpay.set("D", 0);
	totalpay.set("H", 0);

	W.getItemList("shared_expense").forEach(function(item) {
		const prev = totalpay.get(item.getPayer());
		totalpay.set(item.getPayer(), prev + (1 * item.getDollarAmount()));
	});


	const danover = (totalpay.get("D") - totalpay.get("H"));
	const overdisp = (danover > 0 ? danover : -danover) / 2;

	var sentence = (danover == 0 ? "Equal!" : 
						(danover > 0 ? "Heather pays Dan" : "Dan pays Heather"));



	var tableinfo = `

		<table class="basic-table" width="40%">

		<tr>
		<th colspan="2">Summary</th>
		</tr>

		<tr>
		<td width="60%">Dan Paid:</td>
		<td>${totalpay.get("D")}</td>
		</tr>

		<tr>
		<td>Heather Paid:</td>
		<td>${totalpay.get("H")}</td>
		</tr>


		<tr>
		<td>${sentence}</td>
		<td>${overdisp.toFixed(1)}</td>
		</tr>

		</table>
	`;

	return tableinfo;
}


// Auto-generated redisplay function
function editStudyItem(itemid) {
	EDIT_STUDY_ITEM = itemid;
	redisplay();
}

function back2Main() {
	EDIT_STUDY_ITEM = -1;
	redisplay();
}

function updateItemDate()
{
	const newdate = getDocFormValue("day_code_selector");
	const item = W.lookupItem("shared_expense", EDIT_STUDY_ITEM);
	item.setDayCode(newdate);
	item.syncItem();
	redisplay();
}

function shorten4Display(ob) {
	const s = '' + ob;
	if(s.length < 40) { return s; }
	return s.substring(0, 37) + '...';
}

// Auto-generated redisplay function
function redisplay() {

	handleSharedNavBar("Shared Expense");

	const pageinfo = EDIT_STUDY_ITEM == -1 ? getMainPageInfo() : getEditPageInfo();
	populateSpanData({"page_info" : pageinfo });
}

function copyItemUp(itemid)
{
	const copyitem = W.lookupItem(MAIN_TABLE, itemid);

	const copyfuture = prompt("Please enter the number of DAYS to copy to the future");

	if(copyfuture)
	{
		if(!okayInt(copyfuture))
		{
			alert("Please enter a valid number");
			return;
		}

		const record = Object.fromEntries(
							W.getFieldList(MAIN_TABLE)
								.filter(fname => fname != "id")
								.map(fname => [fname, copyitem.getField(fname)]));

		record['day_code'] = lookupDayCode(copyitem.getDayCode())
									.nDaysAfter(parseInt(copyfuture))
									.getDateString();

		W.buildItem(MAIN_TABLE, record).syncItem();
		redisplay();
	}


}

// Auto-generated getEditPageInfo function
function getEditPageInfo() {

	const item = W.lookupItem('shared_expense', EDIT_STUDY_ITEM);
	var pageinfo = `
	<h4>Edit Item</h4>
	<table class="basic-table" width="50%">
	<tr>
	<td>Back</td>
	<td></td>
	<td><a href="javascript:back2Main()"><img src="/u/shared/image/leftarrow.png" height="18"/></a></td>
	</tr>


	<tr><td>Amount</td>
	<td>${item.getDollarAmount()}</td>
	<td><a href="javascript:genericEditIntField('shared_expense', 'dollar_amount', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
	</tr>
	<tr><td>Payer</td>
	<td>${CODE_TO_NAME_MAP[item.getPayer()]}</td>
	<td><a href="javascript:togglePayer()"><img src="/u/shared/image/cycle.png" height="18"></a></td></tr>
	</tr>


	<tr><td>DayCode</td>
	<td>${item.getDayCode()}</td>
	<td><input name="day_code_selector" type="date" value="${item.getDayCode()}" onChange="javascript:updateItemDate()"></td>
	</tr>
	<tr><td>WebLink</td>
	<td>${item.getWebLink()}</td>
	<td><a href="javascript:genericEditTextField('shared_expense', 'web_link', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
	</tr>
	<tr><td>Notes</td>
	<td>${item.getNotes()}</td>
	<td><a href="javascript:genericEditTextField('shared_expense', 'notes', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
	</tr>
	</table>
	`;
	return pageinfo;

}


// Auto-generated getMainPageInfo function
function getMainPageInfo() {


	var pageinfo = `

		<br/>
		<br/>


		${getSummaryTable()}

		<br/>

		<a href="javascript:createNewDan()"><button>+Dan</button></a>

		&nbsp;
		&nbsp;
		&nbsp;
		&nbsp;

		<a href="javascript:createNewHeather()"><button>+Heather</button></a>


		<br/>
		<br/>
	`;

	pageinfo += `
		<table class="basic-table" width="80%">
		<tr>
		<th>Date</th>
		<th>Amount</th>
		<th>Payer</th>
		<th>Notes</th>
		<th>..</th></tr>
	`

	const itemlist = W.getItemList('shared_expense').sort(proxySort(item => [item.getDayCode()])).reverse();

	itemlist.forEach(function(item) {
		const rowstr = `
			<tr>
			<td>${shorten4Display(item.getDayCode())}</td>
			<td>${shorten4Display(item.getDollarAmount())}</td>
			<td>${CODE_TO_NAME_MAP[item.getPayer()]}</td>
			<td>${item.getNotes()}</td>
			<td>

			<a href="javascript:copyItemUp(${item.getId()})"><img src="/u/shared/image/upicon.png" height="16"/></a>

			&nbsp;&nbsp;&nbsp;
			<a href="javascript:editStudyItem(${item.getId()})"><img src="/u/shared/image/inspect.png" height="16"/></a>
			&nbsp;&nbsp;&nbsp;
			<a href="javascript:deleteItem(${item.getId()})"><img src="/u/shared/image/remove.png" height="16"/></a>
			</td>
			</tr>
		`;
		pageinfo += rowstr;
	});

	pageinfo += `</table>`;
	return pageinfo;
}

</script>
<body onLoad="javascript:redisplay()">
<center>
<div class="topnav"></div>



<div id="page_info"></div>

</center>
</body>
</html>
