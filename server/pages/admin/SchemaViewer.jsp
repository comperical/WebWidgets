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
      String bounce = Util.sprintf("SchemaViewer?widget=" + widgetList.get(0).theName);
      response.sendRedirect(bounce);
      return;
    }


    List<String> widgetNameList = Util.map2list(widgetList, item -> item.theName);
    WidgetItem selectedItem = new WidgetItem(currentUser.get(), argMap.getStr("widget"));

    // false : hide tables with __ prefix, including __archived_table
    Map<String, String> schemaInfo = CoreUtil.getCreateTableMap(selectedItem, false);
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

function addReadPerm()
{
  promptAddPerm('read');
}

function addWritePerm()
{
  promptAddPerm('write');

}

function removePerm(grantee)
{
  if(confirm("Are you sure you want to remove the permissions from user " + grantee + "?"))
  {
    const subpack = {
      "opcode" : "remove_perm",
      "widget" : "<%= selectedItem.theName %>",
      "grantee" : grantee
    }
    submit2Base(subpack);
  }
}


function promptAddPerm(permlevel)
{
  const grantee = prompt("Enter the Widget username to grant permissions: ");
  if(grantee)
  {
    const subpack = {
      "opcode" : "add_perm",
      "widget" : "<%= selectedItem.theName %>",
      "permlevel" : permlevel,
      "grantee" : grantee
    }
    submit2Base(subpack);
  }
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
<body data-page="SchemaViewer" onload="javascript:redisplay()">

  <%@include file="AdminTopBar.jsp_inc" %>

  <div class="admin-shell">

    <%@include file="AdminSideBar.jsp_inc" %>

    <main class="admin-main">

      <section class="card">
        <div class="card-body">
          <p class="card-title">Schema Viewer</p>

          <form class="form-inline" style="margin-bottom: 16px">
            <div class="form-group">
              <label>Widget:</label>
              <span id="widget_select_span"></span>
            </div>
          </form>

          <div class="table-wrap">
            <table class="table">
              <thead>
                <tr>
                  <th>Table</th>
                  <th>Definition</th>
                </tr>
              </thead>
              <tbody>
<% 

    for(String table : schemaInfo.keySet())
    {
      String definition = schemaInfo.get(table);

%>
                <tr>
                  <td><b><%= table %></b></td>
                  <td class="code"><%= definition %></td>
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
