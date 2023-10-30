

<%@include file="CoreImport.jsp_inc" %>

<%
    AuthLogic.performLogOut(request, response);

%>


<html>

<link rel="shortcut icon" href="/crm/images/favicon.png" type="image/png">

<head><title>Log Out</title>

<%@include file="AssetInclude.jsp_inc" %>

<script>

const params = getUrlParamHash()
if("bounceback" in params)
{
    window.location.href = params["bounceback"];
}

</script>



</head>

<body>

<center>

<br/>

<h3>LOG OUT</h3>


<table class="basic-table" width="50%" align="center">
<tr>
<td>You have been logged-out. Thanks for using WebWidgets.io!</td>
</tr>
</table>

<br/>

<a href="LogIn.jsp"><button>LogIn Again</button></a>



</center>
</body>
</html>
