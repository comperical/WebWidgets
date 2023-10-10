
<html>
<head>
<title>Spending Graph</title>

<%= DataServer.include(request) %>


<script>

const SMOOTH_WINDOW = 30;

var SHOW_CAT_LIST = ["food", "dailyuse"];


function getDateWindow()
{
    const daylist = W.getItemList("finance_main").map(item => item.getTransactDate()).sort();
    const lastshow = lookupDayCode(daylist[daylist.length-1]).nDaysBefore(SMOOTH_WINDOW);

    return ["2020-01-01", lastshow.getDateString()];
}

function getDataArray()
{
    const dayColMap = new Map();

    var data = [['Date']];

    SHOW_CAT_LIST.forEach(function(cat) {
        data[0].push(cat);
        attachedSmoothedSpendInfo(dayColMap, getCategoryItemList(cat), cat);
    });


    const getrow = function(datestr)
    {
        const r = [datestr];
        SHOW_CAT_LIST.forEach(function(col) {
            cell = dayColMap.get(datestr).get(col);
            r.push(cell);
        });
        return r;
    }

    // console.log(dayColMap);

    const datewindow = getDateWindow();

    const keylist = [... dayColMap.keys()];
    keylist.forEach(function(datestr) {

        if(datewindow[0] < datestr && datestr < datewindow[1])
        { 
            data.push(getrow(datestr));
        }
    });

    return data;
}

function getCategoryItemList(thecat)
{
  return W.getItemList("finance_main")
            .filter(item => item.getExpenseCat() == thecat)
            .filter(item => item.getCentAmount() < 0);
}


function attachedSmoothedSpendInfo(dayColMap, itemlist, colname)
{

  itemlist.forEach(function(item) {

    if(item.getTransactDate() < "2019-01-01")
      { return; }

    smoothedMapUpdate(dayColMap, item, colname);
  });
}

function smoothedMapUpdate(dayColMap, item, colname)
{ 
  const p = lookupDayCode(item.getTransactDate()).nDaysBefore(SMOOTH_WINDOW);
  const share = -item.getCentAmount() / (100 * SMOOTH_WINDOW * 2);

  for(var d = -SMOOTH_WINDOW; d < SMOOTH_WINDOW; d++)
  {
    const delt = p.nDaysBefore(d).getDateString();
    if(!dayColMap.has(delt))
      { dayColMap.set(delt, new Map()); }

    const colmap = dayColMap.get(delt);
    const prev = colmap.has(colname) ? colmap.get(colname) : 0;
    colmap.set(colname, prev+share);
  }
}

function removeCat(remcat)
{
    SHOW_CAT_LIST = SHOW_CAT_LIST.filter(cat => cat != remcat);
    redisplay();
}

function addCat()
{
    const newcat = getDocFormValue("add_cat_sel");
    SHOW_CAT_LIST.push(newcat);
    redisplay();
}

function getAddCatOptionList()
{
    return getExpenseCategoryList().filter(cat => !SHOW_CAT_LIST.includes(cat));

}

function getControlInfo()
{
    const addcat = buildOptSelector()
                        .setKeyList(getAddCatOptionList())
                        .insertStartingPair("---", "---")
                        .setSelectedKey("---")
                        .setElementName("add_cat_sel")
                        .setOnChange("javascript:addCat()")
                        .getSelectString();


    var cattab = `

        <br/>
        <br/>
        ${addcat}
        <br/>
        <br/>

        <table class="basic-table" width="30%">
    `

    SHOW_CAT_LIST.forEach(function(cat) {

        const rowstr = `
            <tr>
            <td>${cat}</td>
            <td><a href="javascript:removeCat('${cat}')"><img src="/u/shared/image/remove.png" height="16"/></td>
            </tr>
        `;

        cattab += rowstr;
    });

    cattab += `</table>`;

    return cattab;
}

function handleNavBar() 
{
    populateTopNavBar(getFinanceHeaderInfo(), "Graph");
}


function redisplay()
{
    handleNavBar();

    drawChart();

    populateSpanData({ "control_info" : getControlInfo() });
}

</script>

<script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
<script type="text/javascript">
  google.charts.load('current', {'packages':['corechart']});
  // google.charts.setOnLoadCallback(drawChart);

  function drawChart() {

    const data = google.visualization.arrayToDataTable(getDataArray());

    var options = {
      title: 'Spending',
      // curveType: 'function',
      legend: { position: 'bottom' }
    };

    var chart = new google.visualization.LineChart(document.getElementById('curve_chart'));

    chart.draw(data, options);
  }
</script>
</head>


<body onLoad="javascript:redisplay()">

    <center>

    <div class="topnav"></div>

    <br/>
    <br/>

    <div id="curve_chart" style="width: 900px; height: 500px"></div>


    <div id="control_info"></div>

    </center>

</body>
</html>
