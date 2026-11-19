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
        String bounce2 = "MailRunner?message=" + encmssg;
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
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
  <title>WebWidgets Admin</title>

  <%@include file="AssetInclude.jsp_inc" %>
<%@include file="AdminStyle.jsp_inc" %>

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
<body data-page="MailRunner">

  <%@include file="AdminTopBar.jsp_inc" %>

  <div class="admin-shell">

    <%@include file="AdminSideBar.jsp_inc" %>

    <main class="admin-main">

                  <%
                    // Original checked (serverMessage != null), which is always true and
                    // rendered an empty message box; only the display condition changed here.
                    if(serverMessage.length() > 0) {

                  %>
      <div class="alert alert-info">
        <i class="fa-solid fa-circle-info"></i>
        <p><%= serverMessage %></p>
      </div>
                  <%
                    }
                  %>

      <section class="card">
        <div class="card-body">
          <div class="card-header">
            <p class="card-title">Widget Mail System</p>
            <div class="btn-row">
                  <%
                    if(!haveMailBox)
                    {

                  %>
              <a class="btn" href="javascript:createMailBox()"><i class="fa-solid fa-inbox"></i>Create MailBox</a>
                  <% } %>

                  <%

                    if(!allReadyMap.isEmpty()) {
                  %>
              <a class="btn btn-primary" href="javascript:sendNextMail()"><i class="fa-solid fa-paper-plane"></i>Send Next Mail</a>
                  <% } %>
            </div>
          </div>

          <p class="muted">
          Normally, the widget mailing system runs every 15 minutes.
          This tool allows you to send widget mails directly.
          </p>

                  <%
                    if(allReadyMap.isEmpty()) {
                  %>
          <p>You do not have any emails that are ready to be sent.</p>
                  <% } %>

          <div class="table-wrap">
            <table class="table">
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
                  <td class="num"><%= onemail.getStr("send_target_utc") %></td>
                  <td class="num"><%= onemail.getStr("sent_at_utc") %></td>
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
