
<html>
<head>
<title>&#x1FA92 &#x1FAA3</title>

<%= DataServer.include(request) %>

<%= DataServer.include(request, "widgetname=minitask&tables=mini_task_list&okay_if_absent=true") %>

<script>

function blahBlah()
{
    alert("...");
}
</script>

<body onLoad="javascript:redisplay()"/>


<center>

<!-- Fails because of JSP tag -->
Hello, <%= "Dan B" %> !!!

<h3>Dummy HTML Data<h3>

</center>
</body>
</html>
