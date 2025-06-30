
<html>
<head>
<title>Finance Log</title>

<wisp/>

<script>

EDIT_STUDY_ITEM = -1;


function getPageComponent()
{
	return EDIT_STUDY_ITEM == -1 ? "main_display" : "inspect_record";
}

function editStudyItem(newid)
{
	EDIT_STUDY_ITEM = newid;
	redisplay();
}

function back2Main()
{
	EDIT_STUDY_ITEM = -1;
	redisplay();
}


function getUncatRecList()
{
	return W.getItemList("finance_main")
			.filter(it => it.getExpenseCat() == "uncategorized");
}

function getHaveCatRecList()
{
	return W.getItemList("finance_main")
			.filter(it => it.getExpenseCat() != "uncategorized");
}


function getDollarFormat(centamount)
{
	var dollamount = centamount/100;
	
	if(dollamount < 0)
	{
		return (-dollamount).toFixed(2);
	}
	
	return "+++" + dollamount.toFixed(2);
}

function doCat4Id(id)
{
	var item = W.lookupItem("finance_main", id);
	var newvalue = document.getElementById("catselect" + id).value;
	item.setExpenseCat(newvalue);
	item.syncItem();
	redisplay();	
}

function editUserNoteInspect()
{
	editUserNote(EDIT_STUDY_ITEM);	
}

function editUserNote(itemid)
{
	genericEditTextField("finance_main", "the_note", itemid);
}

function composeCatOptionSelectStr(itemid)
{
	var s = `
		<select id="catselect${itemid}" onChange="javascript:doCat4Id(${itemid})">
	`;
	
	var optionlist = getOptionList().sort();
	
	for(var oi in optionlist)
	{
		const open = optionlist[oi] == "uncategorized" ? "<option selected>" : "<option>";
		
		s += open + optionlist[oi] + "</option>";
	}

	return s + "</select>";
}

function reDispCatOkTable()
{
	var tablestr = `
		<table class="basic-table"  width="90%">
		<tr>
		<th>DayCode</th>
		<th>ExpenseCat</th>
		<th>Amount</th>
		<th>CC Rec</th>
		<th>UserNote</th>
		<th>---</th>
		</tr>
	`;

	const targcat = getDocFormValueDefault("expense_type_select", "food");
	// const targcat = getDocFormValue("catselect");
	// const cutoffdate = getDocFormValue("cutoffdate");
	const cutoffdate = "2020-07-01";
	const catoklist = getHaveCatRecList();

	var catreclist = catoklist.map(nocat => lookupItem("finance_main", nocat.getId()));
		
	catreclist.sort(proxySort(item => [item.getTransactDate()])).reverse();
	
	
	catreclist.forEach(function(recitem) {
			
		if(targcat != "all" && recitem.getExpenseCat() != targcat)
			{ return; }
			
		if(cutoffdate != "---" && recitem.getTransactDate().localeCompare(cutoffdate) < 0)
			{ return; }		
			
		const dollarstr = getDollarFormat(recitem.getCentAmount());		
		

		const rowstr = `
			<tr>
			<td>${recitem.getTransactDate().substring(5)}</td>
			<td>${recitem.getExpenseCat()}</td>
			<td>${dollarstr}</td>
			<td>${recitem.getFullDesc()}</td>
			<td>${recitem.getTheNote()}</td>
			<td width="7%">
			
			<a href="javascript:editUserNote(${recitem.getId()})">
			<img src="/u/shared/image/edit.png" height="18"/></a>

			&nbsp;
			&nbsp;
						
			<a href="javascript:editStudyItem(${recitem.getId()})">
			<img src="/u/shared/image/inspect.png" height="18"/></a>
			
			</td>
			</tr>
		`;
		
		tablestr += rowstr;
		
		
	});
	
	tablestr += "</table>";
	
	populateSpanData( { "maintable" : tablestr });

	// Populate option selectors
	{
		const catwithdef = ["all"].concat(getExpenseCategoryList().sort());
		
		const catselect = buildOptSelector()
					.setKeyList(catwithdef)
					.setSelectedKey(targcat)
					.setSelectOpener(`<select name="expense_type_select" onChange="javascript:redisplay()">`);
		
		populateSpanData({ "expense_type_sel_span" : catselect.getSelectString() });
	}
	
}

function reDispNoCatTable()
{
	var tablestr = `
		<table class="basic-table"  width="85%">
		<tr>
		<th>Date</th>
		<th>Statement</th>
		<th>Amount</th>
		<th width="20%">Note</th>
		<th>---</th>
		</tr>
	
	`;
	
	var nocatlist = getUncatRecList();
	
	var nocatfinlist = nocatlist.map(nocat => lookupItem("finance_main", nocat.getId()));
		
	nocatfinlist.sort(function(s1, s2) { return -s1.getTransactDate().localeCompare(s2.getTransactDate()); });	
	
	const categorylist = getExpenseCategoryList().sort();
	
	nocatfinlist.forEach(function(onerec) {
		
		const dollarstr = getDollarFormat(onerec.getCentAmount());
		
		const catsel = buildOptSelector()
				.setKeyList(categorylist)
				.setSelectOpener(`<select id="catselect${onerec.getId()}" onChange="javascript:doCat4Id(${onerec.getId()})">`)
				.setSelectedKey(onerec.getExpenseCat());
					
		
		// const catsel = composeCatOptionSelectStr(onerec.getId());
				
		const rowstr = `
			<tr>
			<td>${onerec.getTransactDate().substring(5)}</td>
			<td>${onerec.getFullDesc()}</td>
			<td>${dollarstr}</td>
			<td>${onerec.getTheNote()}</td>	
			<td>
			
			<a href="javascript:editUserNote(${onerec.getId()})">
			<img src="/u/shared/image/edit.png" height="18"/></a>

			&nbsp; 
			&nbsp; 
			&nbsp; 
			
			${catsel.getSelectString()}
			
			</td>
			</tr>
		
		`;
			
		tablestr += rowstr;
	});
	
	tablestr += "</table>";
	
	populateSpanData({"nocattable" : tablestr});
}

function updateNoteCategory()
{
	const noterec = W.lookupItem("finance_main", EDIT_STUDY_ITEM);
	const newcat = getDocFormValue("item_expense_cat_select");
	noterec.setExpenseCat(newcat);
	noterec.syncItem();
	redisplay();
}

function reDispInspectItem()
{
	if(EDIT_STUDY_ITEM == -1)
		{ return; }
	
	const mainrec = W.lookupItem("finance_main", EDIT_STUDY_ITEM);
	
	buildOptSelector()
				.setKeyList(getExpenseCategoryList())
				.setSelectedKey(mainrec.getExpenseCat())
				.setElementName("item_expense_cat_select")
				.setOnChange("javascript:updateNoteCategory()")
				.autoPopulate();
	
	populateSpanData({
		"itemdesc" : mainrec.getFullDesc(),
		"pur_date" : mainrec.getTransactDate(),
		"amount" : getDollarFormat(mainrec.getCentAmount()),
		"user_note" : mainrec.getTheNote(),
		"category" : mainrec.getExpenseCat()
	});
}

function handleNavBar() 
{
    populateTopNavBar(getFinanceHeaderInfo(), "Finance Log");
}


function redisplay()
{
	handleNavBar();

	reDispNoCatTable();
	
	reDispCatOkTable();
	
	reDispInspectItem();
	
	setPageComponent(getPageComponent());
}


</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<div class="topnav"></div>

<br/>
<br/>

<span class="page_component" id="main_display">

<div id="nocattable"></div>

<br/><br/>

<h3>Full Record List</h3>

<form>
Expense Type:
<span id="expense_type_sel_span"></span>

<br/>

<span id="cutoffdate_sel_span"></span>

</form>

<br/><br/>

<div id="maintable"></div>

</span>

<span class="page_component" id="inspect_record">

<a href="javascript:back2Main()">main</a> 

<br/><br/>

<table width="50%" class="basic-table">
<tr>
<td width="50%">Desc</td>
<td><div id="itemdesc"></div></td>
<td></td>
</tr>
<tr>
<td width="50%">Purchased</td>
<td><span id="pur_date"></span>
<td></td>
</td>
</tr>
<tr>
<td width="50%">Amount</td>
<td><span id="amount"></span></td>
<td></td>
</tr>
<tr>
<td width="50%">Category</td>
<td><span id="category"></span></td>
<td></td>
</tr>

<tr>
<td width="50%">Note</td>
<td><span id="user_note"></span></td>
<td><a href="javascript:editUserNoteInspect()"><img src="/u/shared/image/edit.png" height=18/></a></td>
</tr>
<tr>
<td width="50%">Category</td>

<td colspan="2">
<span id="item_expense_cat_select_span"></span>
</td>
</tr>

</table>


</span>

</center>
</body>
</html>
