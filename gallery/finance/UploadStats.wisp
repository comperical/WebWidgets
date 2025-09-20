

<html>
<head>
<title>Upload Stats</title>


<wisp/>

<script>

var FILTERED_RECORDS = [];

function redisplay()
{
    handleNavBar();

    U.populateSpanData({"mainpage" : getMainPageInfo()})

}

function getDataPackage()
{
    return getDataPackageSub("finance_main");
}

function getDataPackageSub(tablename)
{
    const datapack = new Map();

    W.getItemList(tablename).forEach(function(item) {

        const month = item.getTransactDate().substring(0, 7);
        const rtype = item.getLogSource();

        const pairkey = `${month}__${rtype}`
        if(!datapack.has(pairkey))
            { datapack.set(pairkey, []); }

        datapack.get(pairkey).push(item);
    });

    return datapack;

}

function deleteFromPairKey(tablename, pairkey)
{
    const datapack = getDataPackageSub(tablename);

    if(!datapack.has(pairkey))
        { return; }

    const remove = datapack.get(pairkey);

    remove.forEach(item => item.deleteItem());
    redisplay();
}


function deleteMonthPair(pairkey)
{
    const tokens = pairkey.split("__");

    const message = `
    This will delete all ${tokens[1]} records for month ${tokens[0]}

    It may take a few minutes to run.

    Okay to delete?

    `;

    if(confirm(message))
    {
        deleteFromPairKey("finance_main", pairkey);
    }
}


function getMainPageInfo()
{
    var pageinfo = `

        <table class="basic-table" width="60%">

        <tr>
        <th>Month</th>
        <th>Type</th>
        <th>#Main</th>
        <th>$ / |$|</th>
        <th>Bookend</th>
        <th>...</th>
        </tr>


    `;

    const datamap = getDataPackage();
    const pairlist = [... datamap.keys()].sort().reverse();

    pairlist.forEach(function(pair) {

        const val = datamap.get(pair);
        const tokens = pair.split("__");

        const netdollar = val.reduce((acc, item) => acc + item.getCentAmount(), 0);
        const absdollar = val.reduce((acc, item) => acc + Math.abs(item.getCentAmount()), 0);

        val.sort(U.proxySort(item => [item.getTransactDate()]));
        const frstone = val[0].getTransactDate();
        const lastone = val[val.length-1].getTransactDate();


        pageinfo += `
            <tr>
            <td>${tokens[0]}</td>
            <td>${tokens[1]}</td>
            <td>${val.length}</td>
            <td>${(absdollar/100).toFixed(2)}</td>
            <td>
            ${frstone.substring(5)} / ${lastone.substring(5)}
            </td>

            <td>
            <a href="javascript:deleteMonthPair('${pair}')"><img src="/u/shared/image/trashbin.png" height="18"/></a>
            </td>
            </tr>
        `;

    });


    pageinfo += `
        </table>
    `;

    return pageinfo;


}


function handleNavBar() 
{
    populateTopNavBar(getFinanceHeaderInfo(), "Upload Stats");
}

</script>

</head>

<body onLoad="javascript:redisplay()">


<center>

<div class="topnav"></div>

<h2>Upload Stats</h2>


<div id="mainpage"></div>

<br/>
<br/>




</center>
</body>
</html>
