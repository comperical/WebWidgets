
<%@include file="CoreImport.jsp_inc" %>

<%
    // You shouldn't get sent to this page if you're not logged in, 
    // TODO: this should forward to a new page.
    Optional<WidgetUser> currentUser = AuthLogic.getLoggedInUser(request);

    if(!currentUser.isPresent())
    {
        response.sendRedirect("LogIn.jsp");
        return;
    }

    String templateString = Util.join(WebUtil.getConfigTemplate(currentUser.get()), "\n");
    String userHome = Util.sprintf("/%s/index.jsp", currentUser.get());
    String userConfigFileName = String.format("%s__widget.conf", currentUser.get().toString());

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

<script>


function downloadConfig()
{

    let csvContent = "data:text/plain;charset=utf-8," + `<%= templateString %>\n`;


    var encodedUri = encodeURI(csvContent);
    var link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `<%= userConfigFileName %>`);
    document.body.appendChild(link); // Required for FF

    link.click();
}

</script>


</head>
<body>
  <div class="container-scroller">
    <!-- partial:partials/_navbar.html -->
    <%@include file="AdminNavBar.jsp_inc" %>

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
                  <p class="card-title">Download Config File for Widget Development</p>
                  <p class="mb-4">
                  This page will help you get started with Widget development.
                  The WebWidgets framework was designed to enable fast development, and easy setup.
                  After you download the configuration file,
                    follow the instructions on the <a href="https://webwidgets.io/u/docs/WidgetSetup.jsp">Widget Setup</a> page.
                  </p>
                  
                  <center>
                  <a href="javascript:downloadConfig()"><button>Download Config File</button></a>
                  </center>
                  
                </div>
              </div>
            </div>
          </div>
          <br/>
               
            
          <div></div>
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

