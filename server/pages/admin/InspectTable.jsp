
<%@include file="CoreImport.jsp_inc" %>

<%
    // TODO: should include Auth page above.
    // The gotcha for this page is that it is an ADMIN page 
    // that requires a login, but it is under the "/life" subpath.

    // You shouldn't get sent to this page if you're not logged in, 
    // TODO: this should forward to a new page.
    Optional<WidgetUser> currentUser = AuthLogic.getLoggedInUser(request);
    if(!currentUser.isPresent())
    {
        String bounce2url = request.getRequestURL().toString();
        response.sendRedirect("/u/admin/LogIn.jsp?bounceback="+bounce2url);
        return;
    }



    ArgMap argMap = WebUtil.getArgMap(request);
    Util.massert(argMap.containsKey("widgetname"), "Must have a widgetname= parameter in query string");
    String widgetName = argMap.getStr("widgetname");

    {
        Set<String> checkset = Util.map2set(currentUser.get().getUserWidgetList(), witem -> witem.theName);
        Util.massert(checkset.contains(widgetName), 
            "No widget named %s exists for this user, options are %s", widgetName, checkset);
    }

    WidgetItem widgetItem = new WidgetItem(currentUser.get(), widgetName);
    Set<String> tableNameSet = CoreDb.getLiteTableNameSet(widgetItem);
    String targetTableName = argMap.getStr("tablename", "");

    // Very important - this is an anti-SQL-injection step.
    Util.massert(targetTableName.isEmpty() || tableNameSet.contains(targetTableName),
        "Unknown table name %s", targetTableName);


    QueryCollector targetTableData = null;
    if(!targetTableName.isEmpty())
    {
        String idquery = String.format("SELECT * FROM %s ORDER BY id DESC", targetTableName);
        targetTableData = QueryCollector.buildAndRun(idquery, widgetItem);
    }


    String serverMessage = argMap.getStr("message", "");

    String opcode = argMap.getStr("opcode", "");

    if(opcode.length() > 0)
    {

        /*
        Util.massert(message != null, "Unknown opcode %s", opcode);
        String encmssg = StringUtil.encodeURIComponent(message);
        String bounce2 = "ImportWidget.jsp?message=" + encmssg;
        response.sendRedirect(bounce2);
        return;        
        */
    }

    String usercode = currentUser.get().toString();
    String userHome = Util.sprintf("/%s/index.jsp", usercode);
%>


<html>

<link rel="shortcut icon" href="/crm/images/favicon.png" type="image/png">

<head><title>Table Inspector</title>

<%@include file="AssetInclude.jsp_inc" %>

<script>

function maybeAlertMessage()
{
    const mymessage = "<%= serverMessage %>";

    if(mymessage.length > 0)
    {
        alert(mymessage);
        window.location.href = "AdminMain.jsp";
    }
}

function studyTable(tablename)
{
    const params = getUrlParamHash();
    const subpack = { 
        "tablename" : tablename,
        "widgetname" : params['widgetname']
    };

    submit2Base(subpack);
}


</script>



</head>

<body onLoad="javascript:maybeAlertMessage()">

<center>


<h3>Widget Table Inspector</h3>

<%@include file="AdminHeader.jsp_inc" %>

<h3>Table List</h3>

<table class="dcb-basic" id="dcb-basic" width="40%">
<tr>
<th>Table</th>
<th>Desc</th>
<th width="10%">...</th>
</tr>

<% 

    for(String tablename : tableNameSet)
    {
        if(tablename.startsWith("__"))
            { continue; }

        // String thedesc = descriptionMap.getOrDefault(witem.theName, "---");


%>
<tr>
<td><%= tablename %></td>
<td></td>
<td>

<a href="javascript:studyTable('<%= tablename %>')">
<img src="/u/shared/image/inspect.png" height="18" /></a>


</td>
</tr>

<% } %>


</table>

<br/><br/>


<%
    if(targetTableData != null && targetTableData.getNumRec() > 0)
    {

        //List<String> ordered = LifeUtil.getOrderedColumnList(widgetItem, targetTableName);
        List<String> ordered = Util.listify();
        ArgMap proto = targetTableData.recList().get(0);
%>

<table class="basic-table" width="70%">
<tr>

<%
    for(String colname : ordered)
    {

%>
<th><%= colname %></th>
<% } %>
</tr>

<%

    for(ArgMap record : targetTableData.recList())
    {

%>
<tr>
<%
        for(String colname : ordered)
        {

            String rowstr = record.get(colname);
            if(rowstr.length() > 30)
                { rowstr = rowstr.substring(0, 30) + "..." ; }
%>

<td>
<%= rowstr %>
</td>
<% } %>
</tr>
<% } %>
</table>
<% } %>

</center>
</body>
</html>
