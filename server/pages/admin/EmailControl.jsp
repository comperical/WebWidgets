<%@include file="CoreImport.jsp_inc" %>

<%@ page import="io.webwidgets.extend.EmailControl" %>

<%
    // TODO: refactor to remove dependence on EmailControl above

    Optional<WidgetUser> currentUser = AuthLogic.getLoggedInUser(request);


    ArgMap argMap = WebUtil.getArgMap(request);

    // ZHVtbXkuZW1haWxAZ21haWwuY29t = dummy.email@gmail.com. This is used for testing purposes
    String emailAddr = StringUtil.base64Decode(argMap.getStr("email64", "ZHVtbXkuZW1haWxAZ21haWwuY29t"));

    WidgetUser widgetSender = WidgetUser.valueOf(argMap.getStr("sender"));

    QueryCollector emailStatusResult = EmailControl.runStatusQuery(ValidatedEmail.from(emailAddr), widgetSender);

    boolean currentAllow = EmailControl.canUserSendToAddr(emailStatusResult);

    Optional<String> validationError = Optional.empty();

    String opcode = argMap.getStr("opcode", "");

    if(!validationError.isPresent() && opcode.length() > 0)
    {
        if(opcode.equals("toggle_status"))
        {
          String notes = argMap.getStr("notes", "");

          if(currentAllow)
            { EmailControl.addManualBlockRecord(widgetSender, ValidatedEmail.from(emailAddr), notes); } 
          else
            { EmailControl.addManualAllowRecord(widgetSender, ValidatedEmail.from(emailAddr), notes); } 


          String link = EmailControl.composeEmailControlLink(ValidatedEmail.from(emailAddr), widgetSender); 
          response.sendRedirect(link);
          return;
        } 


        Util.massert(false, "Unknown op code " + opcode);
        return;
    }

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


<!-- IMPORTANT : user may not be logged in on this page !!! -->
<!-- But we need the JavaScript libraries -->
<%@include file="AssetInclude.jsp_inc" %>

<!-- Unlike other pages in this section, this does not include a NavBar -->
<script>

function toggleStatus(currentAllow)
{
  const subpack = {"opcode" : "toggle_status"};
  if(currentAllow)
  {
    const mssg = `
      This will prevent any further messages from this user.
      You may optionally enter a comment for why you wish to block the user.
      This will help us prevent misuse of our email system.
    `

    const comment = prompt(mssg);

    if(comment)
      { subpack["notes"] = comment; }
  }

  submit2Current(subpack);
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
      <!-- TODO: remove Nav Bar for this page!!! -->
      <%@include file="MajesticNavBar.jsp_inc" %>
      <!-- partial -->
      <div class="main-panel">
        <div class="content-wrapper">
          
          <div class="row">
            <div class="col-md-12 grid-margin">
              <div class="d-flex justify-content-between flex-wrap">
                <div class="d-flex align-items-end flex-wrap">
                  <div class="mr-md-3 mr-xl-5">
                    <h2>Email Control</h2>
                    <p class="mb-md-0">Control the emails you receive from WebWidgets.IO</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="row">
            <div class="col-md-12 stretch-card">
              <div class="card">
                <div class="card-body">
                  <p class="card-title">Email Info</p>

                  <p>
                    <b>Address</b> : <%= emailAddr %>
                  </p>            

                  <p>
                    <b>Sender</b> : <%= widgetSender %>
                  </p>      

                  <p>
                    <b>Status</b> : <%= currentAllow ? "ALLOWED" : "BLOCKED" %>
                  </p>                        


                  <p>
                  <%
                    if(currentAllow) {
                  %>
                    <a href="javascript:toggleStatus(true)"><button>BLOCK</button></a>
                  <% } else { %>
                    <a href="javascript:toggleStatus(false)"><button>ALLOW</button></a>
                  <% } %>
                  </p>


                  <br/>
                  <br/>

                  <div>
                    <table class="table">
                      <thead>
                        <tr>
                            <th>Status</th>
                            <th>Comment</th>
                            <th>Timestamp (UTC)</th>
                        </tr>
                      </thead>
                      <tbody>

                      <%

                        for(ArgMap statusRec : emailStatusResult.recList())
                        {
                      %>
                      <tr>
                        <td><%= statusRec.getStr("status") %></td>
                        <td><%= statusRec.getStr("notes") %></td>
                        <td><%= statusRec.getStr("timestamp_utc") %></td>
                      <tr>

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

