
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
    List<String> widgetNameList = Util.map2list(widgetList, item -> item.theName);

    // User will see ugly error, but better than just being confused.
    Util.massert(widgetNameList.size() > 0, 
      "You must have at least one widget defined before accessing this page");

    if(!argMap.containsKey("widget"))
    {
      CollUtil.sortListByFunction(widgetList, item -> -item.getLocalDbFile().lastModified());
      String bounce = Util.sprintf("PermissionControl?widget=" + widgetList.get(0).theName);
      response.sendRedirect(bounce);
      return;
    }

    WidgetItem selectedItem = new WidgetItem(currentUser.get(), argMap.getStr("widget"));
    PermInfoPack selectedPerm = GlobalIndex.getPermInfo4Widget(selectedItem);

    String serverMessage = argMap.getStr("message", "");


    String opcode = argMap.getStr("opcode", "");

    if(opcode.length() > 0)
    {

      String granteeStr = argMap.getStr("grantee", "").toLowerCase();
      Optional<WidgetUser> optGrantee = WidgetUser.softLookup(granteeStr);

      boolean toggle = opcode.equals("toggle_public");

      if(!toggle && !optGrantee.isPresent())
      {
        String message = Util.sprintf("No Widget User found with name _%s_. Please check the spelling and try again, or contact system admin", granteeStr);

        String bounce = Util.sprintf("PermissionControl?widget=%s&message=%s", 
          selectedItem.theName, StringUtil.encodeURIComponent(message));

        response.sendRedirect(bounce);
        return;
      }

      if(toggle)
      {
        boolean ispublic = selectedPerm.isPublicRead();
        AuthLogic.markPublicRead(selectedItem, !ispublic);

      } else if(opcode.equals("add_perm")) {

        PermLevel grantperm = PermLevel.valueOf(argMap.getStr("permlevel"));
        AuthLogic.assignPermToGrantee(selectedItem, optGrantee.get(), grantperm);

      } else if(opcode.equals("remove_perm")) {

        AuthLogic.removePermFromGrantee(selectedItem, optGrantee.get());

      } else {

        Util.massert(false, "Invalid op code " + opcode);
      }

      String bounce = Util.sprintf("PermissionControl?widget=%s", selectedItem.theName);
      response.sendRedirect(bounce);
      return;
    }

    Map<WidgetUser, PermLevel> permInfoMap = selectedPerm.getCorePermMap();

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



function togglePublicRead()
{
  const pubread = <%= selectedPerm.isPublicRead() %>;
  const mssg = `
    This widget is currently set as 
    public-read :: ${pubread}
    this will change it to
    public-read :: ${!pubread}

    Okay?
  `;

  if(confirm(mssg))
  {
    const subpack = {
      "opcode" : "toggle_public",
      "widget" : "<%= selectedItem.theName %>"
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

</script>
  
  
</head>
<body data-page="PermissionControl" onload="javascript:redisplay()">

  <%@include file="AdminTopBar.jsp_inc" %>

  <div class="admin-shell">

    <%@include file="AdminSideBar.jsp_inc" %>

    <main class="admin-main">

          <% if(serverMessage.length() > 0) { %>
      <div class="alert alert-warning">
        <i class="fa-solid fa-triangle-exclamation"></i>
        <p><%= serverMessage %></p>
      </div>
          <% } %>

      <section class="card">
        <div class="card-body">
          <p class="card-title">Permission Control</p>

          <form class="form-inline" style="margin-bottom: 16px">
            <div class="form-group">
              <label>Widget:</label>
              <span id="widget_select_span"></span>
            </div>
          </form>

          <div class="table-wrap narrow">
            <table class="table">
              <thead>
                <tr>
                  <th>User</th>
                  <th>Permission</th>
                  <th class="actions"></th>
                </tr>
              </thead>
              <tbody>
<% 

    for(WidgetUser grantee : permInfoMap.keySet())
    {
      PermLevel level = permInfoMap.get(grantee);

%>
                <tr>
                  <td><b><%= grantee %></b></td>
                  <td><span class="badge badge-accent"><%= level %></span></td>
                  <td class="actions">
                    <a class="icon-action danger" href="javascript:removePerm('<%= grantee %>')" title="Remove permission"><i class="fa-solid fa-trash"></i></a>
                  </td>
                </tr>

<% } %>

                <tr>
                  <td><b>Public Read</b></td>
                  <td><span class="badge"><%= selectedPerm.isPublicRead() %></span></td>
                  <td class="actions">
                    <a class="icon-action" href="javascript:togglePublicRead()" title="Toggle public read"><i class="fa-solid fa-arrows-spin"></i></a>
                  </td>
                </tr>

              </tbody>
            </table>
          </div>

          <div class="btn-row" style="margin-top: 16px">
            <button class="btn btn-primary" onclick="addReadPerm()"><i class="fa-solid fa-plus"></i>Read</button>
            <button class="btn btn-primary" onclick="addWritePerm()"><i class="fa-solid fa-plus"></i>Write</button>
          </div>
        </div>
      </section>

    </main>
  </div>

</body>

</html>
