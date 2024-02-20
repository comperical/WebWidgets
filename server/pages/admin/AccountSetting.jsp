
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

    ArgMap argMap = WebUtil.getArgMap(request);
    String serverMessage = argMap.getStr("message", "");


    String opcode = argMap.getStr("opcode", "");
    if(opcode.equals("update_email"))
    {
      

      
    }


    String emailAddrDisp = currentUser.get().getEmail();
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

function deleteAccount()
{

  alert(`
This action will delete your account and remove all of your data from the server. Please download any data you wish to retain before continuing.

Your data backups will be kept for 30 days before deletion. If you wish to retrieve your backups after deletion, please contact support.

Please answer the following confirmation question to proceed.
  `)


  const checkconfirm = prompt("Please enter your username backwards to confirm deletion:");
  const usernamerev = '<%= currentUser.get().toString() %>'.split("").reverse().join("");


  if(usernamerev != checkconfirm)
  {
    alert("Confirmation failed. Please enter your user name BACKWARDS to confirm delete.");
    return;
  }

  submit2Base({
    "checkconfirm" : checkconfirm,
    "opcode": "deleteuser"
  });

}


</script>
  
  
</head>
<body>
  <div class="container-scroller">
    <!-- partial:partials/_navbar.html -->
    <nav class="navbar col-lg-12 col-12 p-0 fixed-top d-flex flex-row">
      <div class="navbar-brand-wrapper d-flex justify-content-center">
        <div class="navbar-brand-inner-wrapper d-flex justify-content-between align-items-center w-100">  
        </div>  
      </div>
      <div class="navbar-menu-wrapper d-flex align-items-center justify-content-end">
    </nav>
    <!-- partial -->
    <div class="container-fluid page-body-wrapper">
      <!-- partial:partials/_sidebar.html -->
      <%@include file="MajesticNavBar.jsp_inc" %>


<%

    // Okay, little bit hacky, but here's the deal
    // After the deletion runs, the currentUser is no longer really valid
    // So the sidebar stuff above will break (and anything that tries to run queries on currentUser's entry)
    // So do the actual deletion after the nav bar is built

    if(opcode.length() > 0)
    {



      if(opcode.equals("deleteuser"))
      {
        Util.massert(!currentUser.get().isAdmin(), "Admin users must be deleted through command line!!");

        List<String> consumer = Util.vector();
        ArgMap mymap = new ArgMap();
        mymap.put("username", currentUser.get().toString());
        mymap.put("checkconfirm", argMap.get("checkconfirm"));

        CoreCommand.MasterDeleteUser deletor = new CoreCommand.MasterDeleteUser();
        deletor.initFromArgMap(mymap);
        deletor.setLogResult(consumer);
        deletor.runOp();
        serverMessage = Util.join(consumer, "<br/>");
      }
    }
%>


      <!-- partial -->
      <div class="main-panel">
        <div class="content-wrapper">
        



        
          <% if(serverMessage.length() > 0) { %>    
          <div class="row">            
            <div class="col-md-12 stretch-card">
              <div class="card">
                <div class="card-body">
                  <p class="card-title">Message</p>
                  <p class="mb-4"><%= serverMessage %></p>

                  <br/>

                  <p>Thanks for using WebWidgets.io, sorry to see you go!</p>

                </div>
              </div>
            </div>
          </div>
          <br/>


          <% }  else  { %>
        
          <div class="row">
            <div class="col-md-12 stretch-card">
              <div class="card">
                <div class="card-body">
                    <p class="card-title">Account Settings</p>


                      <div class="row">
                      User: <%= currentUser.get() %>
                      </div>

                      <div class="row">
                      Email: <%= emailAddrDisp %>
                      </div>



                </div>
              </div>
            </div>
          </div>


          <br/>
          <br/>

          <div class="row">
            <div class="col-md-12 stretch-card">
              <div class="card">
                <div class="card-body">
                  <p class="card-title">Account Deletion</p>
                  <p class="mb-4">

                  Click this button and answer confirmation questions to delete your account.

                  <center>
                  <a href="javascript:deleteAccount()"><button>Delete Account</button></a>
                  </center>
                  
                </div>
              </div>
            </div>
          </div>
          <br/>
          <br/>

          <% } %>


        <!-- content-wrapper ends -->
      </div>
      <!-- main-panel ends -->
    </div>
    <!-- page-body-wrapper ends -->
  </div>
  <!-- container-scroller -->

  <!-- plugins:js -->
  <script src="/u/shared/majestic/vendors/base/vendor.bundle.base.js"></script>
  <!-- endinject -->
  <!-- Plugin js for this page-->
  <script src="/u/shared/majestic/vendors/chart.js/Chart.min.js"></script>
  <script src="/u/shared/majestic/vendors/datatables.net/jquery.dataTables.js"></script>
  <script src="/u/shared/majestic/vendors/datatables.net-bs4/dataTables.bootstrap4.js"></script>
  <!-- End plugin js for this page-->
  <!-- inject:js -->
  <script src="/u/shared/majestic/js/off-canvas.js"></script>
  <script src="/u/shared/majestic/js/hoverable-collapse.js"></script>
  <script src="/u/shared/majestic/js/template.js"></script>
  <!-- endinject -->
  <!-- Custom js for this page-->
  <script src="/u/shared/majestic/js/dashboard.js"></script>
  <script src="/u/shared/majestic/js/data-table.js"></script>
  <script src="/u/shared/majestic/js/jquery.dataTables.js"></script>
  <script src="/u/shared/majestic/js/dataTables.bootstrap4.js"></script>
  <!-- End custom js for this page-->
  <script src="/u/shared/majestic/js/jquery.cookie.js" type="text/javascript"></script>
</body>

</html>

