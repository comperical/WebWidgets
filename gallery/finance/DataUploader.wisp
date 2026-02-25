

<html>
<head>
<title>Upload Finance Data</title>

<wisp/>

<script src="https://cdnjs.cloudflare.com/ajax/libs/PapaParse/5.4.1/papaparse.min.js"></script>


<script>




var FILTERED_RECORDS = [];


function niceDing() {
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    const now = ctx.currentTime;

    // --- Main tone ---
    const osc1 = ctx.createOscillator();
    const gain1 = ctx.createGain();

    osc1.type = "sine";
    osc1.frequency.setValueAtTime(660, now); // E5

    // Soft envelope (THIS removes harshness)
    gain1.gain.setValueAtTime(0.0001, now);
    gain1.gain.exponentialRampToValueAtTime(0.2, now + 0.02);   // gentle attack
    gain1.gain.exponentialRampToValueAtTime(0.0001, now + 0.4); // smooth decay

    osc1.connect(gain1);
    gain1.connect(ctx.destination);

    osc1.start(now);
    osc1.stop(now + 0.4);

    // --- Light sparkle harmonic ---
    const osc2 = ctx.createOscillator();
    const gain2 = ctx.createGain();

    osc2.type = "triangle";
    osc2.frequency.setValueAtTime(880, now); // higher overtone

    gain2.gain.setValueAtTime(0.0001, now);
    gain2.gain.exponentialRampToValueAtTime(0.08, now + 0.01);
    gain2.gain.exponentialRampToValueAtTime(0.0001, now + 0.25);

    osc2.connect(gain2);
    gain2.connect(ctx.destination);

    osc2.start(now);
    osc2.stop(now + 0.25);
}


function copyDateInfo(annoystr)
{
    navigator.clipboard.writeText(annoystr).then(() => {
        niceDing();
    });
}

function redisplay()
{
    handleNavBar();

    testBankParse();
    testCreditParse();


    checkForLoggingHole();


    var pagestr = `

        ${getIngestInfo()}

        <table class="basic-table" width="80%">
        <tr>
        <th>Transact Date</th>
        <th>Desc</th>
        <th>Category</th>
        <th>Amount</th>
        </tr>
    `


    FILTERED_RECORDS.forEach(function(finrec) {

        const rowstr = `
            <tr>
            <td>${finrec.transact.getDateString()}</td>
            <td>${finrec.desc}</td>
            <td>${finrec.cap1_category}</td>
            <td>${(finrec.centamount / 100).toFixed(2)}</td>
            </tr>

        `;

        pagestr += rowstr;

    })


    pagestr += `
        </table>
    `;


    U.populateSpanData({
        "mainpage" : pagestr,
        "missing_info" : getMissingInfo()
    });
}

function getMissingInfo()
{

    var infostr = `
        <table class="basic-table" width="50%">
        <tr>
        <th>LogSource</th>
        <th>1st Missing</th>
        <th>Alpha</th>
        <th>Omega</th>
        </tr>
    `

    const padomega = findRecentPadDate();
    const noupload_cutoff = padomega.nDaysBefore(30);


    const tdblock = function(dcode)
    {
        const annoystr = annoyingDateFormat(dcode);
        return `
            <td class="editable" onClick="javascript:copyDateInfo('${annoystr}')">${annoystr}</td>
        `;
    }


    getLogSourceList().forEach(function(logsource) {

        const missing = findFirstMissingDay(logsource);
        const padalpha = missing.nDaysBefore(15);

        var infocell = `
            <td colspan="2">Up To Date</td>
        `;




        if(padalpha.isBefore(noupload_cutoff))
        {
            const annoyalpha = annoyingDateFormat(padalpha);
            const annoyomega = annoyingDateFormat(padomega);

            infocell = `
                ${tdblock(padalpha)}
                ${tdblock(padomega)}
            `;

        } 

        const rowstr = `
            <tr>
            <td><b>${logsource}</b></td>
            <td>${missing.getDateString()}</td>
            ${infocell}
            </tr>
        `;

        infostr += rowstr;
    });

    infostr += `
            <tr>
            <td colspan="4">(click cell to copy date)</td>
            </tr>
    </table>

    `;

    return infostr;

}

function confirmUpdate(tablename, idlist, __)
{
    alert(`Bulk update of ${idlist.length} records complete`);
    redisplay();
}

function ingestFilteredRecords()
{

    alert(`
        This will bulk-create ${FILTERED_RECORDS.length} records. 
        Please do not close window until confirmation is complete
    `);

    const modlist = []

    while(FILTERED_RECORDS.length > 0)
    {
        const rec = FILTERED_RECORDS.pop();

        const item = {
            "full_desc" : rec.desc,
            "cent_amount" : rec.centamount,
            "log_source" : rec.logsource,
            "transact_date" : rec.transact.getDateString(),
            "expense_cat" : "uncategorized",
            "the_note" : ""
        }

        const fmitem = W.buildItem("finance_main", item);
        modlist.push(fmitem.getId());
    }

    W.bulkUpdate("finance_main", modlist, {"callback" : confirmUpdate });

}

function getIngestInfo()
{

    if(FILTERED_RECORDS.length == 0)
        { return ""; }

    const logsource = FILTERED_RECORDS[0].logsource;
    const monthset = extractMonthSet(FILTERED_RECORDS);

    return `
        <br/>
        <table class="basic-table" width="50%">
        <tr>
        <td>Ingest ${FILTERED_RECORDS.length} records of type <b>${logsource}</b></td>
        <td>
        <a href="javascript:ingestFilteredRecords()"><button>ingest</button></a>
        </td>
        </tr>
        <tr>
        <td colspan="2">
        Months: <b>${[... monthset].join(",")}</b>
        </td>
        </tr>
        </table>
        <br/>
    `;
}

function readFileText(elementname, callback)
{
    const formEl = U.getUniqElementByName(elementname);

    var reader = new FileReader();
    const filename = formEl.files[0].name;
    reader.readAsText(formEl.files[0]);


    reader.onload = function () {
        const text = reader.result;
        console.log(`Read ${text.length} characters from file ${filename}`);
        callback(reader.result);
    };

    reader.onerror = function (error) {
        alert(error);
    };
}



function computeBadMonthList(records, logsource)
{
    const current = extractMonthSet(getFinanceMainRecords(logsource));
    const newmonth = extractMonthSet(records);

    return [... newmonth].filter(mnth => current.has(mnth));
}


function uploadAndParse(readtext)
{
    const logsource = lookupLogSource();
    const parsefunc = logsource == "bank" ? parseBankData : parseCreditData;

    const withpadding = parsefunc(readtext);
    const filteredrec = filterByPaddingLogic(withpadding);

    const overlap = computeBadMonthList(filteredrec, logsource);
    if(overlap.length > 0)
    {
        alert(`You tried to upload data with months that are already in DB : 
            ${[... overlap]}
            Please download a file with different month ranges
        `);
        return;
    }

    FILTERED_RECORDS = filteredrec;
    redisplay();
}

function lookupLogSource()
{
    const fileform = U.getUniqElementByName("my_file");
    const filename = fileform.files[0].name;

    return filename.indexOf("DailyUsage") > -1 ? "bank" : "cred";
}

function handleNavBar() 
{
    populateTopNavBar(getFinanceHeaderInfo(), "Uploader");
}

function fileLoad()
{
    readFileText("my_file", uploadAndParse);
}

function showSelectionType()
{
    alert("File name is " + lookupLogSource());

}

</script>

</head>

<body onLoad="javascript:redisplay()">


<center>

<div class="topnav"></div>


<h2>Finance Uploader</h2>




<div id="mainpage"></div>

<br/>
<br/>

<form name="loadform">
<input type="file" name="my_file" onChange="javascript:fileLoad()"/>
</form>
<br/>
<br/>


<span id="missing_info"></span>


<br/>



</center>
</body>
</html>
