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

    String opcode = argMap.getStr("opcode", "");

    if(opcode.length() > 0)
    {

        if(opcode.equals("create_mailbox"))
        {
          MailSystem.createMailBox4User(currentUser.get());
          serverMessage = "Mailbox created!";
        }
        else 
        {
          Util.massert(false, "Unknown opcode %s", opcode);
        }

        String encmssg = StringUtil.encodeURIComponent(serverMessage);
        String bounce2 = "MailRunner.jsp?message=" + encmssg;
        response.sendRedirect(bounce2);
        return;

    }


    boolean haveMailBox = MailSystem.haveMailBox4User(currentUser.get());
    Map<Integer, WidgetMail> allReadyMap = MailSystem.loadReadyMailForUser(currentUser.get());
    List<ArgMap> bigMailList = MailSystem.directMailQuery(currentUser.get(), Optional.of(100));
    CollUtil.sortListByFunction(bigMailList, amap -> amap.get("send_target_utc"));
    Collections.reverse(bigMailList);
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
  function sendNextMail()
  { 
    const xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
        
        // This block of code is actually called several times before
        // It is ready. readyState == 4 implies the request completed.
        if (this.readyState == 4) {         
            massert(this.status == 200, "Unexpected error code on Ajax operation: " + this.status);
            showResponseInfo(this.responseText);
        }
    };

    const opurl = "/u/extend?openum=SendNextMail";
    xhttp.open("GET", opurl, true);
    xhttp.send();

  }

  function showResponseInfo(rtext)
  {
      console.log(rtext);
      const response = JSON.parse(rtext);
      const message = response["user_message"];
      alert(message);
      window.location.reload();
  }  

  function createMailBox()
  {
    const subpack = {"opcode" : "create_mailbox" };
    submit2Base(subpack);    
  }

  </script>



</head>
<body>
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
                  <p class="card-title">Widget Mail System</p>
                  <p class="mb-md-0">
                  Normally, the widget mailing system runs every 15 minutes.
                  <br/>
                  This tool allows you to send widget mails directly.
                  </p>


                  <%
                    if(!haveMailBox)
                    {

                  %>
                    <center>
                    <a href="javascript:createMailBox()"><button>Create MailBox</button></a>
                    </center>
                    <br/>
                  <% } %>


                  <%

                    if(!allReadyMap.isEmpty()) {
                  %>
                    <br/>
                    <center>
                    <a href="javascript:sendNextMail()"><button>Send Next Mail</button></a>
                    </center>
                    <br/>
                  <%
                    } else { 
                  %>
                    <center>
                    <br/>
                    <p> You do not have any emails that are ready to be sent.</p>
                    </center>

                  <% } %>


                  <%
                    if(serverMessage != null) {

                  %>
                    <table width="50%" class="basic-table" align="center">
                    <tr>
                    <td><%= serverMessage %></td>
                    </tr>
                    </table>
                  <%
                    }
                  %> 

                  <div class="table-responsive">
                    <table id="recent-purchases-listing" class="table">
                      <thead>
                        <tr>
                            <th>Recipient</th>
                            <th>Subject</th>
                            <th>Send-Target (UTC)</th>
                            <th>Sent-At (UTC)</th>
                        </tr>
                      </thead>
                      <tbody>
<% 

    for(ArgMap onemail : bigMailList)
    {

      // WidgetMail themail = allReadyMap.get(mailid);
      // String thedesc = descriptionMap.getOrDefault(witem.theName, "---");


%>
<tr>
<td><b><%= onemail.getStr("recipient") %></b></td>
<td><%= onemail.getStr("subject") %></td>
<td><%= onemail.getStr("send_target_utc") %></td>
<td><%= onemail.getStr("sent_at_utc") %></td>

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

