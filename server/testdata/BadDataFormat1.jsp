
<html>
<head>
<title>&#x1FA92 &#x1FAA3</title>

<!-- Basic import okay -->
<%= DataServer.include(request) %>

<!-- Incorrect DataFormat argument name, should be tables=my_table -->
<%= DataServer.include(request, "tables:my_table") %>



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
