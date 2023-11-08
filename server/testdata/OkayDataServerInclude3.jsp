
<html>
<head>
<title>&#x1FA92 &#x1FAA3</title>

<!-- Basic import okay -->
<%= DataServer.include(request) %>

<!-- Check complex includes -->
<%= DataServer.include(request, "tables=my_table,another_table,table3") %>

<%= DataServer.include(request, "username=d57tm&widgetname=links") %>

<script>

function blahBlah()
{
    alert("...");
}
</script>

<body onLoad="javascript:redisplay()"/>


<center>

<h3>Dummy HTML Data<h3>

</center>
</body>
</html>
