
<%@include file="CoreImport.jsp_inc" %>

<%
    // You shouldn't get sent to this page if you're not logged in, 
    // TODO: this should forward to a new page.
    Optional<WidgetUser> currentUser = AuthLogic.getLoggedInUser(request);

    if(!currentUser.isPresent())
    {
        response.sendRedirect("LogIn");
        return;
    }

    ArgMap argMap = WebUtil.getArgMap(request);
    List<WidgetItem> widgetList = WidgetItem.getUserWidgetList(currentUser.get());

    // User will see ugly error, but better than just being confused.
    Util.massert(widgetList.size() > 0, 
      "You must have at least one widget defined before accessing this page");

    if(!argMap.containsKey("widget"))
    {
      CollUtil.sortListByFunction(widgetList, item -> -item.getLocalDbFile().lastModified());
      String bounce = Util.sprintf("TemplateGenerator?widget=" + widgetList.get(0).theName);
      response.sendRedirect(bounce);
      return;
    }



    List<String> widgetNameList = Util.map2list(widgetList, item -> item.theName);
    WidgetItem selectedItem = new WidgetItem(currentUser.get(), argMap.getStr("widget"));
    Set<String> dbTableNameSet = selectedItem.getDbTableNameSet();
    String userHome = Util.sprintf("/%s/index.jsp", currentUser.get());

%>


<!DOCTYPE html>
<html lang="en">

<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
  <title>WebWidgets Admin</title>
  
<%@include file="AssetInclude.jsp_inc" %>
<%@include file="AdminStyle.jsp_inc" %>

<script>

function changeWidgetSelect()
{
  const newselect = getDocFormValue("widget_selector");
  const subpack = {"widget" : newselect};
  submit2Base(subpack);
}

function redisplay()
{
    const widgetnames = ["<%= Util.join(widgetNameList, "\", \"") %>"];

    const optsel = buildOptSelector()
                        .configureFromList(widgetnames)
                        .sortByDisplay()
                        .setOnChange("javascript:changeWidgetSelect()")
                        .setElementName("widget_selector")
                        .setSelectedKey("<%= selectedItem.theName %>")
                        .getHtmlString();

    populateSpanData({"widget_select_span" : optsel});
}



</script>
  
  
</head>
<body data-page="TemplateGenerator" onload="javascript:redisplay()">

  <%@include file="AdminTopBar.jsp_inc" %>

  <div class="admin-shell">

    <%@include file="AdminSideBar.jsp_inc" %>

    <main class="admin-main">

      <section class="card">
        <div class="card-body">
          <p class="card-title">Template Generator</p>

          <form class="form-inline" style="margin-bottom: 16px">
            <div class="form-group">
              <label>Widget:</label>
              <span id="widget_select_span"></span>
            </div>
          </form>

          <p>
          This template generator builds a simple WISP page that has basic view and edit capability.
          This is a useful starting point for further development.</p>

          <p class="muted">
          Download the file and move it into your widget code directory, then upload
          it back to the server with the CodePush script. Then you can start making
          updates to suit your own goals.
          </p>

          <div class="table-wrap narrow">
            <table class="table">
              <thead>
                <tr>
                  <th>Table</th>
                  <th class="actions">Download</th>
                </tr>
              </thead>
              <tbody>
<% 

    for(String table : dbTableNameSet)
    {

%>
                <tr>
                  <td><b><%= table %></b></td>
                  <td class="actions">
                    <a class="icon-action" href="/u/gentemplate?widgetname=<%= selectedItem.theName %>&tablename=<%= table %>" download="<%= table %>.wisp" title="Download template"><i class="fa-solid fa-download"></i></a>
                  </td>
                </tr>

<% } %>
              </tbody>
            </table>
          </div>
        </div>
      </section>

    </main>
  </div>

</body>

</html>
