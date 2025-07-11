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
    String serverMessage = argMap.getStr("message", "");


    List<WidgetItem> widgetList = WidgetItem.getUserWidgetList(currentUser.get());
    CollUtil.sortListByFunction(widgetList, witem -> -witem.getLocalDbFile().length());


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

            ActionJackson.createCode4Widget(witem);
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
        String bounce2 = "AdminMain.jsp?message=" + encmssg;
        response.sendRedirect(bounce2);
        return;
    }

    String usercode = currentUser.get().toString();
    String userHome = WebUtil.getUserHomeRelative(currentUser.get());
%>


<!DOCTYPE html>
<html lang="en">

<head>
  <!-- Required meta tags -->
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
  <title>WebWidgets Admin</title>
  <!-- plugins:css -->
  <link rel="stylesheet" href="/u/shared/majestic/vendors/mdi/css/materialdesignicons.min.css">
  <link rel="stylesheet" href="/u/shared/majestic/vendors/base/vendor.bundle.base.css">
  <!-- endinject -->
  <!-- plugin css for this page -->
  <link rel="stylesheet" href="/u/shared/majestic/vendors/datatables.net-bs4/dataTables.bootstrap4.css">
  <!-- End plugin css for this page -->
  <!-- inject:css -->
  <link rel="stylesheet" href="/u/shared/majestic/css/style.css">
  <!-- endinject -->

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
<body onLoad="javascript:maybeAlertMessage()">
  <div class="container-scroller">
    <!-- partial:partials/_navbar.html -->
    <%@include file="AdminNavBar.jsp_inc" %>

    <!-- partial -->
    <div class="container-fluid page-body-wrapper">
      <!-- partial:partials/_sidebar.html -->
      <%@include file="MajesticNavBar.jsp_inc" %>
      <!-- partial -->
      <div class="main-panel">
        <div class="content-wrapper">
          
          <div class="row">
            <div class="col-md-12 grid-margin">
              <div class="d-flex justify-content-between flex-wrap">
                <div class="d-flex align-items-end flex-wrap">
                  <div class="mr-md-3 mr-xl-5">
                    <h2>Welcome <%= currentUser.get() %></h2>
                    <p class="mb-md-0">Your WebWidgets admin dashboard.</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="row">
            <div class="col-md-12 stretch-card">
              <div class="card">
                <div class="card-body">
                  <p class="card-title">Widgets</p>

                  <p align="center">
                    <a href="javascript:createBlankWidget()"><button>new widget</button></a>
                  </p>

                  <div class="table-responsive">
                    <table id="recent-purchases-listing" class="table">
                      <thead>
                        <tr>
                            <th>Name</th>
                            <th>#Tables</th>
                            <th>Size</th>
                            <th></th>
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
                      
<td><b><%= witem.theName %></b></td>
<td><%= tableset.size() %></td>
<td><%= sizestr %></td>
<td width="15%">

<!-- TODO: rebuild the InspectTable tool -->

<%
  if(targetFile.isPresent())
  {
    String widgetlink = Util.sprintf("/u/%s/%s/%s", usercode, witem.theName, targetFile.get().getName());

%>

<a class="no-underline" href="<%= widgetlink %>"><i class="fa-solid fa-link"></i></a>

<% } else { %>

<img src="/u/shared/image/purewhite.png" style="height: 18px; width: 18px" /></a>

<% } %>


&nbsp;
&nbsp;


<a href="javascript:deleteWidget('<%= witem.theName %>')"><i class="fa-solid fa-trash"></i></a>

</td>
</tr>

<% } %>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        <!-- content-wrapper ends -->
      </div>
      <!-- main-panel ends -->
    </div>
    <!-- page-body-wrapper ends -->
  </div>
  <!-- container-scroller -->

  <%@include file="MajesticFooter.jsp_inc" %>

</body>

</html>

