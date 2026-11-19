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
        response.sendRedirect("/u/admin/LogIn?bounceback="+bounce2url);
        return;
    }


    ArgMap argMap = WebUtil.getArgMap(request);
    String serverMessage = argMap.getStr("message", "");


    List<WidgetItem> widgetList = WidgetItem.getUserWidgetList(currentUser.get());
    // Alphabetical by name, ignoring case (was: largest DB file first)
    CollUtil.sortListByFunction(widgetList, witem -> witem.theName.toLowerCase());


    String opcode = argMap.getStr("opcode", "");

    if(opcode.length() > 0)
    {
        String message = null;

        if(opcode.equals("create_new"))
        {
            Set<String> nameset = Util.map2set(widgetList, witem -> witem.theName);
            String newname = argMap.getStr("widget_name");

            Util.massert(!nameset.contains(newname), "You already have a widget named %s", newname);

            WidgetItem witem = WidgetItem.createBlankItem(currentUser.get(), newname);
            message = Util.sprintf("New widget created with name %s", newname);

            witem.createJsCode();
        }

        if(opcode.equals("delete_old"))
        {
            Set<String> nameset = Util.map2set(widgetList, witem -> witem.theName);
            String widgetname = argMap.getStr("widget_name");
            String reversed = argMap.getStr("reversed");
            Util.massert(nameset.contains(widgetname), 
                "No widget named %s appears to exist", widgetname);

            var dbitem = new WidgetItem(currentUser.get(), widgetname);
            dbitem.checkAndDelete(reversed);
            message = Util.sprintf("Successfully deleted widget %s", widgetname);
        }

        Util.massert(message != null, "Unknown opcode %s", opcode);
        String encmssg = StringUtil.encodeURIComponent(message);
        String bounce2 = "AdminMain?message=" + encmssg;
        response.sendRedirect(bounce2);
        return;
    }

    String usercode = currentUser.get().toString();
    String userHome = WebUtil.getUserHomeRelative(currentUser.get());
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


// The server message is shown in the info box on the page; just drop ?message= from the
// address bar so a refresh doesn't show it again.
function clearMessageFromUrl()
{
    const mymessage = "<%= serverMessage %>";

    if(mymessage.length > 0)
        { history.replaceState(null, "", "AdminMain"); }
}

function isReservedName(myname)
{
  <%
    for(String rname : AdvancedUtil.RESERVED_WIDGET_NAMES)
    {
  %>

  if (myname.toLowerCase() == "<%= rname.toLowerCase() %>")
    { return true; }

  <% } %>

  return false;
}

function createBlankWidget()
{
    const newname = prompt("Please enter a name for the new widget: ");
    if(isReservedName(newname))
    {
      alert("The name " + newname + " is reserved for WebWidget system use, please pick something else");
      return;
    }


    if(newname)
    {
        const subpack = { "opcode" : "create_new", "widget_name" : newname };
        submit2Base(subpack);
    }

}

function deleteWidget(widgetname)
{

    const reversed = prompt("To confirm you want to delete this widget " + widgetname + ", please enter its name BACKWARDS:");

    if(reversed)
    {
        const expected = widgetname.split("").reverse().join("");
        console.log("expected is : " + expected);

        if(expected != reversed)
        {
            alert("Please enter the widget name REVERSED to delete");
            return;
        }

        const subpack = { "opcode" : "delete_old", "widget_name" : widgetname, "reversed" : reversed };
        submit2Base(subpack);
    }
}


</script>


</head>
<body data-page="AdminMain" onLoad="javascript:clearMessageFromUrl()">

  <%@include file="AdminTopBar.jsp_inc" %>

  <div class="admin-shell">

    <%@include file="AdminSideBar.jsp_inc" %>

    <main class="admin-main">

      <div class="page-header">
        <h2>Welcome <%= currentUser.get() %></h2>
        <p>Your WebWidgets admin dashboard.</p>
      </div>

          <% if(serverMessage.length() > 0) { %>
      <div class="alert alert-info medium">
        <i class="fa-solid fa-circle-info"></i>
        <p><%= serverMessage %></p>
      </div>
          <% } %>

      <section class="card medium">
        <div class="card-body">
          <div class="card-header">
            <p class="card-title">Widget Listing</p>
            <a class="btn btn-primary" href="javascript:createBlankWidget()"><i class="fa-solid fa-plus"></i>New Widget</a>
          </div>

          <div class="table-wrap">
            <table class="table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th class="num">#Tables</th>
                  <th class="num">Size</th>
                  <th class="actions"></th>
                </tr>
              </thead>
              <tbody>
<%

    for(WidgetItem witem : widgetList)
    {

        long filesize = witem.getLocalDbFile().length();
        String sizestr = filesize + "B";

        if(filesize > 1_000_000){
            sizestr = Util.sprintf("%d Mb", filesize / 1_000_000);
        } else if (filesize > 1_000) {
            sizestr = Util.sprintf("%d Kb", filesize / 1_000);
        }

        Set<String> tableset = CoreDb.getLiteTableNameSet(witem);


        Optional<File> targetFile = witem.findPreferredTargetPage();
%>
                <tr>
                  <td><b><%= witem.theName %></b></td>
                  <td class="num"><%= tableset.size() %></td>
                  <td class="num"><%= sizestr %></td>
                  <td class="actions">
<%
  if(targetFile.isPresent())
  {
    String widgetlink = Util.sprintf("/u/%s/%s/%s", usercode, witem.theName, targetFile.get().getName());

%>
                    <a class="icon-action" href="<%= widgetlink %>" title="Open widget"><i class="fa-solid fa-link"></i></a>
<% } else { %>
                    <span class="icon-action" style="visibility: hidden"></span>
<% } %>
                    <a class="icon-action danger" href="javascript:deleteWidget('<%= witem.theName %>')" title="Delete widget"><i class="fa-solid fa-trash"></i></a>
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
