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
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
  <title>WebWidgets Admin</title>


<!-- IMPORTANT : user may not be logged in on this page !!! -->
<!-- But we need the JavaScript libraries -->
<%@include file="AssetInclude.jsp_inc" %>
<%@include file="AdminStyle.jsp_inc" %>

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
<body data-page="EmailControl">

  <%-- The person viewing this page may not be logged in (they arrived from a link in an email),
       so per the TODO in EmailControl.jsp it has only the top bar, no admin sidebar. --%>
  <%@include file="AdminTopBar.jsp_inc" %>

  <div class="admin-shell">

    <main class="admin-main">

      <div class="page-header">
        <h2>Email Control</h2>
        <p>Control the emails you receive from WebWidgets.IO</p>
      </div>

      <section class="card">
        <div class="card-body">
          <p class="card-title">Email Info</p>

          <dl class="kv-list">
            <dt>Address</dt>
            <dd><%= emailAddr %></dd>
            <dt>Sender</dt>
            <dd><%= widgetSender %></dd>
            <dt>Status</dt>
            <dd><span class="badge <%= currentAllow ? "badge-success" : "badge-danger" %>"><%= currentAllow ? "ALLOWED" : "BLOCKED" %></span></dd>
          </dl>

          <div class="btn-row" style="margin-bottom: 20px">
                  <%
                    if(currentAllow) {
                  %>
            <a class="btn btn-danger" href="javascript:toggleStatus(true)"><i class="fa-solid fa-ban"></i>Block</a>
                  <% } else { %>
            <a class="btn btn-primary" href="javascript:toggleStatus(false)"><i class="fa-solid fa-check"></i>Allow</a>
                  <% } %>
          </div>

          <div class="table-wrap">
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
                  <td class="num"><%= statusRec.getStr("timestamp_utc") %></td>
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
