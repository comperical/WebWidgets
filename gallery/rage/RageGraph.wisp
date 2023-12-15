
<html>
<head>
<title>&#x1F621 &#x1F624</title>

<wisp/>

<script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>

<script>

var EDIT_STUDY_ITEM = -1;

var SHOW_YEAR_INFO = true;


function getSortedData()
{
    const itemlist = W.getItemList("rage_log").sort(proxySort(item => [item.getDayCode()]));
    const result = [['Month', 'Number of Events']];

    var curtime = null;
    var bucket = 0;

    itemlist.forEach(function(item) {

        const yrmnth = item.getDayCode().substring(0, 7);
        if(yrmnth != curtime)
        {
            if(curtime != null)
            {
                result.push([yrmnth, bucket]);
            }

            curtime = yrmnth;
            bucket = 0;
        }

        bucket += 1;
    });


    return result;
}


function drawChart() {

    var data = google.visualization.arrayToDataTable(getSortedData());

    var options = {
        chart: {
            title: 'Rage Frequency By Month',
        },
        bars: 'vertical', // Required for Material Bar Charts.
        legend: { position: 'none' } // This line hides the legend
    };

    var chart = new google.charts.Bar(document.getElementById('bar_chart'));
    chart.draw(data, google.charts.Bar.convertOptions(options));
}


function loadAndDisplay()
{

    google.charts.load('current', {'packages':['bar']});
    google.charts.setOnLoadCallback(drawChart);


    redisplay();
}

function redisplay()
{
    handleNavBar("Rage Graph");

}

</script>

</head>

<body onLoad="javascript:loadAndDisplay()">

<center>
<div class="topnav"></div>
</center>

<br/>
<br/>


<div id="bar_chart"></div>



</body>
</html>
