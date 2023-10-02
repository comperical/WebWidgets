
<html>
<head>
<title>Junk Food Log</title>

<%= DataServer.include(request) %>

<%= DataServer.include(request, "widgetname=junkfood") %>


<%= DataServer.include(request, "widgetname=other&tables=alc_log") %>


<script>

const SMOOTH_WINDOW = 15;

function getDataArray()
{

  // const junkmap = getMonthlySum(getItemList("junk_food_log"), item => item.getJunkfactor());
  // const boozmap = getMonthlySum(getItemList("alc_log"), item => item.getNumDrink());

  const itemlist = getTargetItemList();

  const fullmap = getSmoothedSpendInfo(itemlist);

  var data = [['Date', 'Full Spend']];

  [... fullmap.keys()].forEach(function(datestr) {

    const record = [datestr, fullmap.get(datestr)];
    data.push(record);
  })

  return data;
}

function getTargetItemList()
{
  return W.getItemList("finance_main")
            .filter(item => item.getExpenseCat() == "food")
            // .filter(item => item.getExpenseCat() != "taxes")
            // .filter(item => item.getExpenseCat() == "ignore")
            .filter(item => item.getCentAmount() < 0);
}


function getSmoothedSpendInfo(itemlist)
{

  const daymap = new Map();

  itemlist.forEach(function(item) {

    if(item.getTransactDate() < "2020-01-01")
      { return; }

    smoothedMapUpdate(daymap, item);
  });

  return daymap;
}

function smoothedMapUpdate(dmap, item)
{ 
  const p = lookupDayCode(item.getTransactDate()).nDaysBefore(SMOOTH_WINDOW);
  const share = -item.getCentAmount() / (100 * SMOOTH_WINDOW * 2);

  for(var d = -SMOOTH_WINDOW; d < SMOOTH_WINDOW; d++)
  {
    const delt = p.nDaysBefore(d).getDateString();
    const prev = dmap.has(delt) ? dmap.get(delt) : 0;
    dmap.set(delt, prev+share);
  }
}


function getMonthlySum(itemlist, lookupfunc)
{
  // month --> weight
  const datamap = {};

  itemlist.forEach(function(item) {

    const month = item.getDayCode().substring(0, 7);

    if(!(month in datamap)) {
      datamap[month] = 0;
    }

    datamap[month] += lookupfunc(item);

  });

  return datamap;
}
</script>

<script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
<script type="text/javascript">
  google.charts.load('current', {'packages':['corechart']});
  google.charts.setOnLoadCallback(drawChart);

  function drawChart() {

    const data = google.visualization.arrayToDataTable(getDataArray());

    var options = {
      title: 'Junk Food and Booze',
      // curveType: 'function',
      legend: { position: 'bottom' }
    };

    var chart = new google.visualization.LineChart(document.getElementById('curve_chart'));

    chart.draw(data, options);
  }
</script>
</head>


<body>
  <center>
  <div id="curve_chart" style="width: 900px; height: 500px"></div>
  </center>
</body>
</html>
