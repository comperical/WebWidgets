
<%@include file="CoreImport.jsp_inc" %>

<%


    // Okay the imports above are kind of dumb. 
    // Doing that because of the way we're generating the config file in the JSP, using the response output writer.
    // If you layout the imports normally, these become empty lines at the top of the file.
    // By collapsing them all together, we remove the empty lines, at the price of cluttering up the header.

    // You shouldn't get sent to this page if you're not logged in, 
    // TODO: this should forward to a new page.
    Optional<WidgetUser> currentUser = AuthLogic.getLoggedInUser(request);

    if(!currentUser.isPresent())
    {
        response.sendRedirect("LogIn.jsp");
        return;
    }



    ArgMap argMap = WebUtil.getArgMap(request);

    String widgetName = argMap.getStr("widgetname");
    String tableName = argMap.getStr("tablename");

    WidgetItem theWidget = new WidgetItem(currentUser.get(), widgetName);
    Util.massert(theWidget.dbFileExists(), "This widget does not exist : " + theWidget);

    Util.massert(theWidget.getDbTableNameSet().contains(tableName),
        "No table named %s, options are %s", tableName, theWidget.getDbTableNameSet());

    LiteTableInfo liteTable = new LiteTableInfo(theWidget, tableName);
    List<String> codeGenResult = (new TemplateGenerator(liteTable)).runGeneration();

    for(String line : codeGenResult) {
        response.getWriter().write(line + "\n");
    }

    response.getWriter().close();

%>

