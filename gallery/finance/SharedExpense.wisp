<html>
<head>
<title>Shared Expense</title>
<wisp/>

<script src="/u/shared/optjs/SimpleTag/v1.js"></script>


<style>
/* Intentionally repeating this, have not figured out the correct logic about sharing CSS */
.editable:hover {
    background-color: lightskyblue;
}

</style>

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
			'day_code' : U.getTodayCode().getDateString(),
			'web_link' : '',
			'notes' : notes
		};
		const newitem = W.buildItem('shared_expense', newrec);
		newitem.syncItem();
		EDIT_STUDY_ITEM = newitem.getId();
		redisplay();
	}
}

function createNewGrocery()
{

	const amount = U.promptForInt("Enter the grocery amount: ");
	if(amount)
	{
		const newrec = {
			'dollar_amount' : amount,
			'payer' : "H",
			'day_code' : U.getTodayCode().getDateString(),
			'web_link' : '',
			'tag_set' : "food",
			'notes' : "Groceries"
		};

		const newitem = W.buildItem(MAIN_TABLE, newrec);
		newitem.syncItem();
		redisplay();
	}
}


function addNovelTag()
{
    const novtag = prompt("Please enter a NOVEL tag:");

    if(novtag)
    {
        const item = W.lookupItem(MAIN_TABLE, EDIT_STUDY_ITEM);
        TAG.addNewTag2Item(item, novtag);
        item.syncItem();
        redisplay();
    }
}

function removeTagFromStudy(killtag)
{
    const item = W.lookupItem(MAIN_TABLE, EDIT_STUDY_ITEM);
    TAG.removeTagFromItem(item, killtag);
    item.syncItem();
    redisplay();
}

function addTagFromMain(itemid)
{
    const item = W.lookupItem(MAIN_TABLE, itemid);
    const seltag = U.getDocFormValue(`tagsel__${itemid}`)
    TAG.addNewTag2Item(item, seltag);
    item.syncItem();
    redisplay();
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
	const newdate = U.getDocFormValue("day_code_selector");
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
	U.populateSpanData({"page_info" : pageinfo });
}

function updateAmountDirect(itemid)
{
	const updater = function(item)
	{
		const newamt = U.promptForInt("Please enter the new amount: ", item.getDollarAmount());
		if(newamt != null)
		{
			item.setDollarAmount(newamt);
		}
	}

	U.genericItemUpdate(MAIN_TABLE, itemid, updater);

}

function updateDateDirect(itemid)
{
	const updater = function(item)
	{
		const newdate = prompt("Please enter the new date: ", item.getDayCode());
		if(newdate != null)
		{
			if(!U.haveDayCodeForString(newdate))
			{
				alert("Invalid date, please use YYYY-MM-DD format");
				return;

			}

			item.setDayCode(newdate);
		}
	}

	U.genericItemUpdate(MAIN_TABLE, itemid, updater);


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

		record['day_code'] = U.lookupDayCode(copyitem.getDayCode())
									.nDaysAfter(parseInt(copyfuture))
									.getDateString();

		W.buildItem(MAIN_TABLE, record).syncItem();
		redisplay();
	}


}

// Auto-generated getEditPageInfo function
function getEditPageInfo() {

	const item = W.lookupItem('shared_expense', EDIT_STUDY_ITEM);

    let tagcell = "";
    TAG.getItemTagSet(item).forEach(function(tag) {

        tagcell += ` ${tag} 
            <a href="javascript:removeTagFromStudy('${tag}')">
            <img src="/u/shared/image/remove.png" height="14"/></a>

            &nbsp;
            &nbsp;
            &nbsp;
        `

    });


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
	<td><a href="javascript:U.genericEditIntField('shared_expense', 'dollar_amount', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
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
	<td><a href="javascript:U.genericEditTextField('shared_expense', 'web_link', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
	</tr>



	<tr><td>Notes</td>
	<td>${item.getNotes()}</td>
	<td><a href="javascript:U.genericEditTextField('shared_expense', 'notes', EDIT_STUDY_ITEM)"><img src="/u/shared/image/edit.png" height="18"></a></td></tr>
	</tr>


	<tr><td>TagSet</td>
	<td>${tagcell}</td>
	<td>

    <a href="javascript:addNovelTag()"><img src="/u/shared/image/add.png" height="18"/></a>


	</td>
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


		&nbsp;
		&nbsp;
		&nbsp;
		&nbsp;


		<a href="javascript:createNewGrocery()"><button>+Grocery</button></a>


		<br/>
		<br/>
	`;

	pageinfo += `
		<table class="basic-table" width="90%">
		<tr>
		<th>Date</th>
		<th>Amount</th>
		<th>Payer</th>
		<th>Notes</th>
		<th colspan="2">Tags</th>
		<th>..</th></tr>
	`

	const itemlist = W.getItemList(MAIN_TABLE)
							.sort(U.proxySort(item => [item.getDayCode()])).reverse();

    const alltagset = TAG.getCompleteTagSet(itemlist);



	itemlist.forEach(function(item) {


	    const tagselector = buildOptSelector()
	                            .configureFromList([... alltagset])
	                            .sortByDisplay()
	                            .setElementName(`tagsel__${item.getId()}`)
	                            .insertStartingPair("---", "---")
	                            .setOnChange(`javascript:addTagFromMain(${item.getId()})`)
	                            .getHtmlString();

		const rowstr = `
			<tr>
			<td class="editable" onClick="javascript:updateDateDirect(${item.getId()})">
			${item.getDayCode()}</td>
			<td class="editable" onClick="javascript:updateAmountDirect(${item.getId()})">${shorten4Display(item.getDollarAmount())}</td>
			<td>${CODE_TO_NAME_MAP[item.getPayer()]}</td>
			<td>${item.getNotes()}</td>
            <td width="5%">${TAG.getTagSetDisplay(item, "&nbsp;/&nbsp;")}</td>
			<td width="5%">${tagselector}</td>
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
