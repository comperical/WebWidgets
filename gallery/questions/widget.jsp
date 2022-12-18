
<html>
<head>
<title>&#x2754 &#x2753</title>

<%= DataServer.basicInclude(request) %>

<script>

SEARCH_INPUT = "";

_EDIT_STUDY_ITEM = -1;

_EDIT_TEXT_MODE = false;

function createNew()
{	
	var qtext = prompt("Enter the text of the question: ");
	
	createNewSub(qtext);
}

function createNewSub(qtext)
{	
	if(!qtext.endsWith("?"))
	{
		alert("By convention, questions must end with a question mark");
		return;
	}

	if(qtext)
	{	
		const todaycode = getTodayCode().getDateString();
		
		// created_on, active_on, completed_on, dead_line
		var comrecord = {
			"question_text" : qtext,
			"full_notes" : "TBD",
			"created_on" : todaycode,
			"is_active" : 1,
			"web_link" : "",
			"has_answer" : 0
		};
		
		const newitem = W.buildItem("question_log", comrecord);
		newitem.syncItem();
		redisplay();
	}
}

function deleteItem(killid)
{
	var myitem = W.lookupItem("question_log", killid);
	
	if(confirm("Are you sure you want to delete question: " + myitem.getQuestionText()))
	{
		myitem.deleteItem();
		redisplay();
	}
}

function markAnswered(editid)
{
	var myitem = W.lookupItem("question_log", editid);
	myitem.setHasAnswer(1);
	syncSingleItem(myitem);
	redisplay();
}

function redisplay()
{
	var htmldata = "";
	
	if(_EDIT_STUDY_ITEM != -1)
	{
		htmldata = getEditItemData();
	} else {
		var htmldata = "<h3>Questions</h3>";
		htmldata += getSearchSection();
		htmldata += getQuestionTable(false);
	}
		
	const maindiv = document.getElementById("mainpage");	
	maindiv.innerHTML = htmldata;
}

function back2Main()
{
	_EDIT_STUDY_ITEM = -1;
	_EDIT_TEXT_MODE = false;
	redisplay();
}

function editStudyItem(editid)
{
	_EDIT_STUDY_ITEM = editid;
	_EDIT_TEXT_MODE = false;
	redisplay();
}

function getSearchSection()
{
	if(SEARCH_INPUT.length == 0)
	{
		return `
			<br/>
			<a class="css3button" onclick="javascript:enterSearchTerm()">search</a>
			
			&nbsp;
			&nbsp;
			&nbsp;
			
			<a class="css3button" onclick="javascript:createNew()">new</a>
			<br/><br/>
		`;
	}
	
	return  getSearchTermTable() + getResultSection();
}

function scoreQuestion(qitem)
{
	var score = 0;
	
	const searchterms = SEARCH_INPUT.split(" ");
	
	searchterms.forEach(function(sterm) {
				
		if(qitem.getFullNotes().toLowerCase().indexOf(sterm.toLowerCase()) > -1)
			{ score += 10; }
		
		if(qitem.getQuestionText().toLowerCase().indexOf(sterm.toLowerCase()) > -1)
			{ score += 10; }	
	});
	
	if(qitem.getHasAnswer() == 1)
		{ score += 3; }	
	
	return score;	
}

// Ordered list of score :: ID
function getScore2IdList()
{
	var score2id = [];
	
	W.getItemList("question_log").forEach(function(item) {
		const score = [scoreQuestion(item), item.getId()];
		score2id.push(score);
	});
	
	score2id.sort(proxySort(a => [-a[0]]));
	
	return score2id;
}

function enterSearchTerm()
{
	const oldinput = SEARCH_INPUT;
	const newinput = prompt("Enter a new search: ", oldinput);
	
	if(newinput)
	{
		if(newinput.length > 15 && newinput.endsWith("?"))
		{
			const mssg = `
It looks like you wanted to create a new question
(you clicked Search)
Do you want to do that instead?
Question is:
${newinput}
`
			if(confirm(mssg))
			{
				createNewSub(newinput);
				return;
			}
		}


		SEARCH_INPUT = newinput;
		redisplay();
	}
}

function clearSearch()
{
	SEARCH_INPUT = "";
	redisplay();
}

function getResultSection()
{	
	var s = "";
	
	s += `
		<table class="basic-table" width="75%">
		<tr class="bar">
		<th>Score</th>
		<th>Question</th>
		<th>Answer 1st Line</th>
		<th>----</th>
		</tr>
	`;	
	
	const score2id = getScore2IdList();
			
	score2id.forEach(function(spair) {
			
		if(spair[0] < 5)
			{ return; }
			
		const qitem = lookupItem("question_log", spair[1]);
		
		var weblinkstr = `<img src="/u/shared/image/purewhite.png" height="18"/>`;
		
		if(qitem.getWebLink().length > 1)
		{
			weblinkstr = `
				<a href="${qitem.getWebLink()}"><img src="/u/shared/image/chainlink.png" height="18"/></a>
			`;
		}
		
		const opcol = `
			${weblinkstr}
			&nbsp;&nbsp;
			<a href="javascript:editStudyItem(${qitem.getId()})"><img src='/u/shared/image/inspect.png' height='18'/></a>
			&nbsp;&nbsp;
			<a href="javascript:markAnswer(${qitem.getId()})"><img src='/u/shared/image/checkmark.png' height='18'/></a>
			&nbsp;&nbsp;
			<a href="javascript:deleteItem(${qitem.getId()})"><img src='/u/shared/image/remove.png' height='18'/></a>
		`;
				
		const answer1 = qitem.getFullNotes().split("\n")[0];
		
		const row = `
			<tr class="bar">
			<td width="5%">${spair[0]}</td>
			<td>${qitem.getQuestionText()}</td>
			<td>${answer1}</td>
			<td width="18%">${opcol}</td>
			</tr>
		`;
				
		s += row;
	});
	
	s += "</table>";
	
	return s;
}

function getSearchTermTable()
{	
	var s = `
		<table  class="basic-table" width="40%">
	`;
	
	
	const searchrow = `
		<tr>
		<td>search term: <b>${SEARCH_INPUT}</b></td>
		</tr>
	`;
	
	s += searchrow;
	s += "</table><br/>";
	
	s += `
		<a class="css3button" onclick="javascript:clearSearch()">clear</a>
	
		&nbsp;
		&nbsp;
		&nbsp;
		&nbsp;
		
		<a class="css3button" onclick="javascript:enterSearchTerm()">re-search</a>
	
		<br/><br/>
	`;
	
	return s;
}



function getQuestionTable(hasanswer)
{
	var s = `
		<h3>Open</h3>
	`
	s += getQuestionTableSub(0);
	
	if(SEARCH_INPUT.length == 0)
	{
		s += `
			<br/>
			<br/>
			<h3>Recently Answered</h3>
		`;
		
		s += getQuestionTableSub(1);
	}
	
	
	return s;
}

function getQuestionTableSub(hasanswer)
{
	var s = `
		<table  class="basic-table" width="75%">
	`;
		
	{
		const header = `
		<tr>
		<th>Question</th>
		<th>Answer 1st Line</th>
		<th>----</th>
		</tr>
		`;
		
		s += header;
	}	
	
	// console.log("Running with hasanswer = " + hasanswer);
	
	const openlist = W.getItemList("question_log").filter(fitem => fitem.getHasAnswer() == hasanswer);
	const datecutoff = getTodayCode().nDaysBefore(60);
		
	openlist.forEach(function(openitem) {		
					
		if(hasanswer == 1 && openitem.getCreatedOn() < datecutoff.getDateString())
			{ return; }
			
		const breaker = "&nbsp;&nbsp;";
		
		var weblinkstr = `<img src="/u/shared/image/purewhite.png" height="18"/>`;
		
		if(openitem.getWebLink().length > 1)
		{
			weblinkstr = `
				<a href="${openitem.getWebLink()}"><img src="/u/shared/image/chainlink.png" height="18"/></a>
			`;
		}
		
		
		const opcol = `
		${weblinkstr}
		${breaker}
		<a href="javascript:editStudyItem(${openitem.getId()})"><img src='/u/shared/image/inspect.png' height='18'/></a>
		${breaker}
		<a href="javascript:markAnswered(${openitem.getId()})"><img src='/u/shared/image/checkmark.png' height='18'/></a>
		${breaker}
		<a href="javascript:deleteItem(${openitem.getId()})"><img src='/u/shared/image/remove.png' height='18'/></a>
		`;			
		
		const answer1 = openitem.getFullNotes().split("\n")[0];
		
		const trstr = `
		<tr class="bar">
		<td>${openitem.getQuestionText()}</td>
		<td>${answer1}</td>
		<td width="18%">${opcol}</td>
		</tr>
		`;
		
		s += trstr;
	});
		
	s += "</table>";
	
	return s;	
}


// EDIT ITEM SECTION {{{

function getStudyItem()
{
	return lookupItem("question_log", _EDIT_STUDY_ITEM);
}

function getEditItemData()
{	
	var studyitem = lookupItem("question_log", _EDIT_STUDY_ITEM);
		
	const extralineinfo = studyitem.getFullNotes().replace(/\n/g, "<br/>");
	
	var mainblock = `

		<h3>Question Item Detail</h3>
		
		<br/>
		
		<table class="basic-table" width="50%">
		<tr>
		<td>Back</td>
		<td><a name="back_url" href="javascript:back2Main()"><img src="/u/shared/image/leftarrow.png" height="18"/></a></td>
		</tr>
		<tr>
		<td>ID</td>
		<td>${studyitem.getId()}</td>
		</tr>
		<tr>
		<td>Question</td>
		<td><b>${studyitem.getQuestionText()}</span></b>
		
		&nbsp;
		&nbsp;
		&nbsp;
		
		<a href="javascript:editQuestionText()"><img src="/u/shared/image/edit.png" height="18"></a>
		
		</td>
		</tr>
		
		<tr>
		<td>Web Link</td>
		<td>${studyitem.getWebLink()}
		
		&nbsp;
		&nbsp;
		&nbsp;
		
		<a href="javascript:editWebLink()"><img src="/u/shared/image/edit.png" height="18"></a>
		</td>
		</tr>
		
		<tr>
		<td>Has Answer</td>
		<td>${studyitem.getHasAnswer() == 1 ? "YES" : "NO"}
		
		&nbsp;
		&nbsp;
		&nbsp;
		
		<a href="javascript:cycleField('has_answer')"><img src="/u/shared/image/cycle.png" height="18"></a>
		</td>
		</tr>
		
		<tr>
		<td>Status</td>
		<td>${studyitem.getIsActive() == 1 ? "ACTIVE" : "INACTIVE"}
		
		&nbsp;
		&nbsp;
		&nbsp;
		
		<a href="javascript:cycleField('is_active')"><img src="/u/shared/image/cycle.png" height="18"></a>
		</td>
		</tr>
		
		<tr>
		<td>Created</td>
		<td>${studyitem.getCreatedOn()}</td>
		</tr>	
		</table>
		
		<br/>
		
		<table class="basic-table" width="50%" border="0">
		<tr>
		<td>${extralineinfo}</td>
		
		<td width="10%">
		<a href="javascript:editExtraInfo()"><img src="/u/shared/image/edit.png" height="18"></a>
		</td>
		</tr>
		</table>		
	`;
	
	if(_EDIT_TEXT_MODE)
	{
		mainblock += `
	
			<br/>
			<br/>
			<form>
			<textarea id="set_extra_info" cols="80" rows="10">${studyitem.getFullNotes()}</textarea>
			</form>
			
			<a class="css3button" onclick="javascript:saveExtraInfo()">save</a>
		`;
	}
	
	
	return mainblock;

}

function editQuestionText()
{
	var studyitem = getStudyItem();
	
	var newdesc = prompt("Enter the question text: ", studyitem.getQuestionText());
	
	if(newdesc)
	{
		studyitem.setQuestionText(newdesc);
		syncSingleItem(studyitem);
		redisplay();			
	}
}

function cycleField(fname)
{
	const studyitem = getStudyItem();
	const previous = studyitem[fname]
	studyitem[fname] = previous == 1 ? 0 : 1;
	syncSingleItem(studyitem);
	redisplay();
}


function editWebLink()
{
	var studyitem = getStudyItem();
	
	var newlink = prompt("Enter the web link: ", studyitem.getWebLink());
	
	if(newlink)
	{
		studyitem.setWebLink(newlink);
		syncSingleItem(studyitem);
		redisplay();			
	}
}


function editExtraInfo()
{
	_EDIT_TEXT_MODE = true;
	redisplay();
}

// This is the old name of the function
function saveExtraInfo()
{
	var studyitem = getStudyItem();
	studyitem.setFullNotes(document.getElementById("set_extra_info").value);
	syncSingleItem(studyitem);	
	_EDIT_TEXT_MODE = false;
	redisplay();	
}

// }}}


</script>

</head>

<body onLoad="javascript:redisplay()">


<center>

<div id="mainpage"></div>

</center>
</body>
</html>
