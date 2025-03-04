
// Expense categories
function getExpenseCategoryList()
{
    return [
        'uncategorized',
        'taxes',
        'food',
        'transport',
        'travel',
        'gym',
        'rent',
        'booze',
        'clothing',
        'miscpersonal',
        'donation',
        'health_ins',
        'entertainment',
        'learning',
        'books',
        'chinese',
        'utility',
        'work_exp',
        'healthcare',
        'business',
        'cellphone',
        'dailyuse',
        'ignore'
    ];
}


function getFinanceHeaderInfo()
{
    return [
        ["Finance Log", "FinanceLog.wisp"],  
        ["Finance Agg", "FinanceAgg.wisp"],
        ["Finance Plan", "FinancePlanner.wisp"],
        ["Uploader", "DataUploader.wisp"],
        ["Upload Stats", "UploadStats.wisp"],
        ["Tagger", "TagRecords.wisp"],
        ["Tag Rules", "AutoTagRules.wisp"],
        ["Graph", "SpendGraph.wisp"]
    ];
}

function getSharedExpenseHeader()
{
    return [
        ["Shared Expense", "SharedExpense.wisp"],
        ["Search Shared", "SearchShared.wisp"]
    ];


}


function handleSharedNavBar(current)
{
    populateTopNavBar(getSharedExpenseHeader(), current);
}


function findTagHitList(fmainitem)
{
    return W.getItemList("tag_rule").filter(item => tagRuleApplies(item, fmainitem));
}

function tagRuleApplies(tagitem, mainitem)
{
    const normdesc = mainitem.getFullDesc().toLowerCase().split(" ").filter(tok => tok.trim().length > 0).join(" ");

    if(tagitem.getAndTags().length > 0)
    {
        return normdesc.indexOf(tagitem.getAndTags().toLowerCase()) > -1;

    }

    return false;
}

// A logging "hole" is a month where there are no records, followed by a month 
// that DOES have records. This method finds such a daycode if it exists
function findHoleMonthLastDay(logsource)
{
    const monthset = extractMonthSet(getFinanceMainRecords(logsource));
    var probe = getNDaysAgo(365);

    for(var idx = 0; idx < 365; idx++)
    {
        const nextday = probe.dayAfter();

        const thismnth = extractMonth(probe);
        const nextmnth = extractMonth(nextday);

        if(monthset.has(thismnth) && !monthset.has(nextmnth))
            { return probe; }
    }

    return null;
}

function findRecentPadDate()
{
    var probe = getTodayCode();

    for(var idx = 0; idx < 30; idx++)
    {
        if(probe.getDateString().endsWith("15"))
            { return probe; }

        probe = probe.dayBefore();
    }

    Util.massert(false);
}

function findFirstMissingDay(logsource)
{

    const monthset = extractMonthSet(getFinanceMainRecords(logsource));
    var probe = getNDaysAgo(365);

    for(var idx = 0; idx < 365; idx++)
    {
        if(!monthset.has(extractMonth(probe)))
            { return probe; }

        probe = probe.dayAfter();
    }

    massert(false, "What, you mean you have logging data for EVERY month??");
    return null;
}



function checkForLoggingHole()
{
    const bankhole = findHoleMonthLastDay('bank');
    const credhole = findHoleMonthLastDay('cred');

    if(bankhole != null)
    {
        alert(`You have a hole in your logging for BANK, last day is ${bankhole.getDateString()}`);
    }

    if(credhole != null)
    {
        alert(`You have a hole in your logging for CRED, last day is ${credhole.getDateString()}`);
    }

}


function getLogSourceList()
{
    return ["bank", "cred"];
}

function extractMonthSet(multilist)
{
    // Javascript Set preserves sort order
    // So sorting here will ensure that the months are ordered as expected
    const biglist = multilist.map(extractMonth).sort();
    return new Set(biglist);
}

function extractMonth(multitype)
{   
    const dc = extractDayCode(multitype);
    return dc.getDateString().substring(0, 7);
}

function extractDayCode(multitype) 
{
    var dc = null;

    if(multitype instanceof String) 
        { dc = lookupDayCode(multitype); }
    else if(multitype instanceof FinanceMainItem)
        { dc = lookupDayCode(multitype.getTransactDate()); }
    else if(multitype instanceof DayCode)
        { dc = multitype; }    
    else if(multitype instanceof Object)
        { dc = multitype.transact; }


    massert(dc != null, `Bad input type for extractDayCode: ${multitype}`);
    return dc;
}

function getFinanceMainRecords(logsource)
{
    massert(getLogSourceList().includes(logsource), `Invalid log source ${logsource}`);
    return W.getItemList("finance_main").filter(item => item.getLogSource() == logsource);
}

function filterByPaddingLogic(finrecords)
{
    const monthset = new Set(finrecords.map(rec => extractMonth(rec)));
    const monthlist = [... monthset].sort();

    massert(monthlist.length > 2, `Month list is only ${monthlist}, need at least 3 months for this operation to work`);
    const innermonth = monthlist.slice(1, -1);
    return finrecords.filter(rec => innermonth.includes(extractMonth(rec)));
}

function convertToCentAmount(debit, credt)
{
    const debtempty = debit.trim().length == 0;
    const credempty = credt.trim().length == 0;

    massert(credempty != debtempty,
        `Have cred=${credt} and debt=${debit}, but expected one or other to be empty`);

    const centamount = Math.round(100 * parseFloat(credempty ? debit : credt));
    return centamount * (credempty ? -1 : 1);
}

// Feb 2025: replace old hacky CSV parsing tool with Papa-based approach
function parseCreditData(csvtext)
{

    const converter = function(ppitem)
    {
        // console.log(ppitem);

        // These are nice ISO time stamps
        const transact = lookupDayCode(ppitem['Transaction Date']);

        const debitinfo = ppitem["Debit"].trim();
        const credtinfo = ppitem["Credit"].trim();

        const havedebit = debitinfo.length > 0;
        const havecredt = credtinfo.length > 0;

        massert(havedebit == !havecredt,
            `Must have debit XOR credit, debit=${debitinfo}, credit=${credtinfo}`);

        const dollaramount = parseFloat(havedebit ? debitinfo : credtinfo);
        // debits are entered as negative, credits as positive
        const centamount = (havedebit ? -1 : +1) * Math.round(100 * dollaramount);

        return {
            transact : lookupDayCode(ppitem['Transaction Date']),
            desc : ppitem['Description'],
            cap1_category : ppitem['Category'],
            centamount : centamount,
            logsource : 'cred'
        }
    }

    const ppfulldata =  Papa.parse(csvtext.trim(), { header : true } );
    return ppfulldata.data.map(converter);
}


function parseBankData(csvtext)
{
    // 8578,05/03/22,-100.00,Debit,ATM Withdrawal - CAPITAL ONE A5C8 BERKELEY  CA,8312.75

    // Changed, May 2024!!
    // New format:
    // 8578,Withdrawal from PAYPAL to DANIEL BURFOOT INST XFER,04/12/24,Debit,15.95,8284.22
    // Account Number,Transaction Description,Transaction Date,Transaction Type,Transaction Amount,Balance


    const converter = function(ppitem)
    {
        massert(parseInt(ppitem["Account Number"]) == 8578, "Bad account number");

        const bankrecord = new Object();

        bankrecord.transact = handleAnnoyingDate(ppitem["Transaction Date"]);
        bankrecord.desc = ppitem["Transaction Description"];
        bankrecord.logsource = 'bank';


        // This field only exists for credit
        bankrecord.cap1_category = "N/A";

        {
            const cordstr = ppitem["Transaction Type"];
            const sign = { "Debit" : -1, "Credit" : +1 }[cordstr];
            massert(sign != null, `Unknown credit/debit string ${cordstr}`);

            bankrecord.centamount = sign * Math.round(100 * parseFloat(ppitem["Transaction Amount"]));  
        }

        return bankrecord;
    }


    const ppfulldata =  Papa.parse(csvtext.trim(), { header : true } );
    return ppfulldata.data.map(converter);
}

function annoyingDateFormat(daycode)
{
    const tokens = daycode.getDateString().split("-");
    return `${tokens[1]}/${tokens[2]}/${tokens[0]}`;
}

function handleAnnoyingDate(mmddyy)
{
    // 05/12/22
    const tokens = mmddyy.split("/");
    const iso = `20${tokens[2]}-${tokens[0]}-${tokens[1]}`;
    return lookupDayCode(iso);
}

function testCreditParse()
{
    const probedata = `
                Transaction Date,Posted Date,Card No.,Description,Category,Debit,Credit
                2022-10-30,2022-10-01,4773,xxx,Gas/Automotive,2.00,
                2022-09-29,2022-10-01,4773,TOASTMASTERS OTHER,Other Services,90.00,
                2022-09-30,2022-10-01,4773,TST* Bennetts Sandwich S,Dining,30.36,
                2022-09-27,2022-09-30,4773,CANNOLI,Dining,16.17,
                2022-09-30,2022-09-30,4773,xxx,Entertainment,97.00,
                2022-09-28,2022-09-30,4773,STARBUCKS STORE 07459,Dining,10.58,
                2022-09-29,2022-09-29,4773,COMCAST CABLE COMM,Phone/Cable,72.99,
                2022-09-25,2022-09-27,4773,TST* xxxd,Dining,32.58,
                2022-09-24,2022-09-26,4773,5 xxxO,Dining,41.70,
                2022-09-24,2022-09-26,4773,STARBUCKS STORE 07459,Dining,5.91,
                2022-08-24,2022-09-26,4773,STARBUCKS STORE 07459,Dining,0.00,

    `;

    records = parseCreditData(probedata);

    const centsum = records.map(r => r.centamount).reduce((a,b) => a+b);
    massert(centsum == -39929, `Expected -39929 from fixture data, but got ${centsum}`);

    const monthset = extractMonthSet(records);
    const monthresult = [... monthset].sort().join(",");
    massert(monthresult == "2022-08,2022-09,2022-10", `Got month result ${monthresult}`);

    {
        const padded = filterByPaddingLogic(records);
        const padmonth = extractMonthSet(padded);
        massert(padmonth.size == 1, `Padded month is ${[... padmonth]}`);
    }

    console.log("Credit Parse worked okay");
}

function testBankParse()
{
        /*
    const probedata = `
        Account Number,Transaction Date,Transaction Amount,Transaction Type,Transaction Description,Balance
        1473,05/16/22,-2000.00,Debit,Debit Card Purchase - XXXYYYZZ DELAWARE DE,1236.71
        1473,05/12/22,2236.31,Credit,Deposit from BIGTECH CO CORPORA DIRECT DEP,3236.71
        1473,05/11/22,-2311.35,Debit,Withdrawal from CAPITAL ONE ONLINE PMT,1000.40
        1473,05/05/22,-5000.00,Debit,Debit Card Purchase - XXXYYYZZ DELAWARE DE,3311.75
        1473,05/05/22,-1.00,Debit,Debit Card Purchase - XXXYYYZZ DELAWARE DE,8311.75
        1473,05/03/22,-100.00,Debit,ATM Withdrawal - CAPITAL ONE A5C8 BERKELEY  CA,8312.75
        1473,05/02/22,-1150.00,Debit,Withdrawal from Segula Investmen WEB PMTS,8412.75
        1473,04/30/22,0.61,Credit,Monthly Interest Paid,9562.75
        1473,04/28/22,2295.90,Credit,Deposit from BIGTECH CO CORPORA DIRECT DEP,9562.14
        1473,04/25/22,-16.00,Debit,Withdrawal from PAYPAL to DANIEL BURFOOT INST XFER,7266.24
        1473,04/15/22,-5.00,Debit,Withdrawal from PAYPAL to DANIEL BURFOOT INST XFER,7282.24
        1473,04/14/22,2295.91,Credit,Deposit from BIGTECH CO CORPORA DIRECT DEP,7287.24
        1473,04/12/22,-589.00,Debit,Check #576 Cashed,4991.33
        1473,04/08/22,-37.00,Debit,Withdrawal from PAYPAL to DANIEL BURFOOT INST XFER,5580.33
        1473,04/07/22,-3739.67,Debit,Withdrawal from CAPITAL ONE ONLINE PMT,5617.33
        1473,04/04/22,-1150.00,Debit,Withdrawal from Segula Investmen WEB PMTS,9357.00
        1473,04/02/22,-13291.00,Debit,Check #527 Cashed,10507.00
        1473,03/31/22,1.78,Credit,Monthly Interest Paid,23798.00
        1473,03/31/22,2177.47,Credit,Deposit from BIGTECH CO CORPORA DIRECT DEP,23796.22
        1473,03/21/22,-832.37,Debit,Withdrawal from CAPITAL ONE ONLINE PMT,21618.75
        1473,03/17/22,2242.30,Credit,Deposit from BIGTECH CO CORPORA DIRECT DEP,22451.12
    `;

    */

    const probedata = `
Account Number,Transaction Description,Transaction Date,Transaction Type,Transaction Amount,Balance
8578,Withdrawal from PAYPAL to DANIEL BURFOOT INST XFER,04/12/24,Debit,15.95,8284.22
8578,Withdrawal from PAYPAL to DANIEL BURFOOT INST XFER,04/11/24,Debit,34.15,8300.17
8578,Check #580 Cashed,04/09/24,Debit,467.97,8334.32
8578,Withdrawal from CAPITAL ONE ONLINE PMT,04/03/24,Debit,1116.97,8802.29
8578,Monthly Interest Paid,03/31/24,Credit,1.2,9919.26
8578,Zelle money sent to HEATHER BALDYGA,03/29/24,Debit,806,9918.06
8578,Withdrawal from CAPITAL ONE ONLINE PMT,03/26/24,Debit,3220.54,10724.06
8578,Check #530 Cashed,03/22/24,Debit,220,13944.6
8578,Withdrawal from CAPITAL ONE ONLINE PMT,03/16/24,Debit,1830.57,14164.6
8578,Withdrawal from NU/UNITIL/EZPAY UTILITY,03/13/24,Debit,145.35,15995.17
8578,Zelle money sent to HEATHER BALDYGA,03/01/24,Debit,806,16140.52
8578,Monthly Interest Paid,02/29/24,Credit,1.51,16946.52
    `;


    records = parseBankData(probedata);


    const centsum = records.map(r => r.centamount).reduce((a,b) => a+b);
    massert(centsum == -866079, `Expected -1897211 from fixture data, but got ${centsum}`);

    const monthset = extractMonthSet(records);
    const monthresult = [... monthset].sort().join(",");
    massert(monthresult == "2024-02,2024-03,2024-04", `Got month result ${monthresult}`);

    {
        const padded = filterByPaddingLogic(records);
        const padmonth = extractMonthSet(padded);
        massert([... padmonth].join(",") == "2024-03");
    }


    console.log("Bank Parse worked okay");
}


