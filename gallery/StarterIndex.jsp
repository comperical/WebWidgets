
<%

%>

<html>
<head>
<style>
body
{
    background: #ADD8E6;
}
</style>

<script>

function firstTimeInfo()
{
    const info = `
        Hello and welcome to your widgets page!
        
        I set up this skeleton page for you to help you get started.
        In the future, you can put anything you want here - it's your space.
        I recommend bookmarking this URL and using it as a bounce page to access other widgets.
        
        I also set up some initial Gallery widgets for you.
        You don't have to use them if you don't want, but take a look to get the basic idea of how widgets work.
        
        Also check out the Admin Section, where you can:
        - change your password
        - grab your credentials file for up/down-loading Widget data
        - import other Gallery widgets
        - delete widgets you don't use
        
        Thanks for checking out the site and PLEASE reach out to me if you have any questions!
        
        best,
        Dan
    `;
    
    
    alert(info);
    
}

</script>

</head>

<body>

<center>
<h3>Widgets</h3>
</center>

<table width="95%" border="2" style="border-collapse: collapse; background: White;" align="center">

<tr>
<td width="35%">


<center>
<h3>Info</h3>
</center>

<ul>
<li><a href="./links/widget.jsp">Links</a></li>
<li><a href="./questions/widget.jsp">Questions</a></li>

</ul>


</td>
<td width="35%">

<center>
<h3>Morning</h3>
</center>

<ul>
<li><a href="./mroutine/widget.jsp">Morning Routine</a></li>
</ul>


</td>
<td>
<center>
<h3>Ops</h3>
</center>

<ul>
<li><a href="./chores/widget.jsp">Chores</a></li>
</ul>

</td>
</tr>

</table>

<br/>
<br/>

<center>
<a href="/u/admin/AdminMain.jsp"><button>Admin Section</button></a>
<center>

<br/>
<br/>
First Time Users:
<a href="javascript:firstTimeInfo()"><button>click here</button></a>


</body>
</html>
