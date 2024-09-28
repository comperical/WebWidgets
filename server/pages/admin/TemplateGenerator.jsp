
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
  <link rel="shortcut icon" href="/u/shared/majestic/images/favicon.png" />
  
<%@include file="AssetInclude.jsp_inc" %>

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
<body onload="javascript:redisplay()">
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
            <div class="col-md-12 stretch-card">
              <div class="card">
                <div class="card-body">
                  <p class="card-title">Template Generator</p>

                  <p class="mb-md-0">
                  This template generator builds a simple WISP page that has basic view and edit capability.
                  This is a useful starting point for further development.</p>

                  <br/>

                  <p>
                  Download the file and move it into your widget code directory, then upload
                  it back to the server with the CodePush script. Then you can start making
                  updates to suit your own goals.
                  </p>

                  <br/>

                  <center>
                  <form class="forms-sample" align="center">
                    <div class="row">    
                    <div class="form-group">
                      <label>Widget:</label>
                      <span id="widget_select_span"></span>
                    </div>
                    </div>
                  </form> 
                  </center>


                  <div>
                    <table class="table" border="1">
                      <thead>
                        <tr>
                            <th>Table</th>
                            <th>Download</th>
                        </tr>
                      </thead>
                      <tbody>
<% 

    for(String table : dbTableNameSet)
    {

%>
<tr>
<td><b><%= table %></b></td>
<td>

<a href="GetTemplateCode.jsp?widgetname=<%= selectedItem.theName %>&tablename=<%= table %>" download="<%= table %>.wisp">
<img src="/u/shared/image/downicon.png" style="height: 18px; width: 18px" /></a>


</td>
</tr>

<% } %>
                      </tbody>
                    </table>

                    <br/>

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

