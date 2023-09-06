
<html>
<head>
<title>Junk Food Log</title>

<%= DataServer.include(request) %>

<%= DataServer.include(request, "widgetname=other&tables=alc_log") %>


<script>

function getDataArray()
{

  const junkmap = getMonthlySum(getItemList("junk_food_log"), item => item.getJunkfactor());
  const boozmap = getMonthlySum(getItemList("alc_log"), item => item.getNumDrink());

  var data = [['Month', 'Junk Food', 'Booze']];

  Object.keys(junkmap).forEach(function(month) {

    if(month < "2018-10") {
      return;
    }

    const record = [month, junkmap[month], boozmap[month]];
    data.push(record);
  })

  return data;
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
