
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
    String serverMessage = argMap.getStr("message", "");


    String opcode = argMap.getStr("opcode", "");
    if(opcode.equals("add_email"))
    {

      String newemail = argMap.getStr("new_email");
      AdvancedUtil.addEmailAddress(currentUser.get(), ValidatedEmail.from(newemail));
      String encmssg = StringUtil.encodeURIComponent("Added email address " + newemail);
      response.sendRedirect("AccountSetting?message=" + encmssg);
      return;
    }

    if(opcode.equals("remove_email"))
    {

      String email = argMap.getStr("old_email");
      AdvancedUtil.removeEmailAddress(currentUser.get(), ValidatedEmail.from(email));
      String encmssg = StringUtil.encodeURIComponent("Removed email address " + email);
      response.sendRedirect("AccountSetting?message=" + encmssg);
      return;
    }





    String emailAddrDisp = currentUser.get().getEmailSet().toString();
    emailAddrDisp = emailAddrDisp == null ? "" : emailAddrDisp;
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


function addNewEmail()
{
  const newemail = prompt("Please enter a NEW email address for this account: ");

  if(newemail)
  {
    if(newemail.length < 4 || newemail.indexOf("@") == -1)
    {
      alert("That email does not appear to be valid, please enter an email in username@emailservice.com format");
      return;
    }

    const subpack = {"opcode" : "add_email", "new_email" : newemail };
    submit2Base(subpack);
  }


}


function removeEmail(oldemail)
{
  if(confirm(`Are you sure you want to remove the email address ${oldemail}?`))
  {


    const subpack = {"opcode" : "remove_email", "old_email" : oldemail };
    submit2Base(subpack);
  }


}


</script>
  
  
</head>
<body data-page="AccountSetting">

  <%@include file="AdminTopBar.jsp_inc" %>

  <div class="admin-shell">

    <%@include file="AdminSideBar.jsp_inc" %>


<%

    // Okay, little bit hacky, but here's the deal
    // After the deletion runs, the currentUser is no longer really valid
    // So the sidebar stuff above will break (and anything that tries to run queries on currentUser's entry)
    // So do the actual deletion after the nav bar is built

    // Result of account deletion; when present, replaces the normal page content
    String deleteMessage = "";

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
        deleteMessage = Util.join(consumer, "<br/>");
      }
    }
%>


    <main class="admin-main">

          <% if(deleteMessage.length() > 0) { %>
      <section class="card narrow">
        <div class="card-body">
          <p class="card-title">Message</p>
          <div class="alert alert-info" style="margin-bottom: 16px">
            <i class="fa-solid fa-circle-info"></i>
            <p><%= deleteMessage %></p>
          </div>
          <p class="mb-0">Thanks for using WebWidgets.io, sorry to see you go!</p>
        </div>
      </section>


          <% }  else  { %>

          <% if(serverMessage.length() > 0) { %>
      <div class="alert alert-info">
        <i class="fa-solid fa-circle-info"></i>
        <p><%= serverMessage %></p>
      </div>
          <% } %>

      <section class="card">
        <div class="card-body">
          <p class="card-title">Account Settings</p>

          <dl class="kv-list">
            <dt>User</dt>
            <dd><%= currentUser.get() %></dd>
          </dl>

          <p class="card-title" style="font-size: 14px">Email Addresses</p>

          <div class="table-wrap narrow">
            <table class="table">
              <tbody>
                      <%

                        for(String anemail : new TreeSet<>(currentUser.get().getEmailSet()))
                        {
                      %>
                <tr>
                  <td><%= anemail %></td>
                  <td class="actions">
                    <a class="icon-action danger" href="javascript:removeEmail('<%= anemail %>')" title="Remove email"><i class="fa-solid fa-trash"></i></a>
                  </td>
                </tr>
                      <% } %>
              </tbody>
            </table>
          </div>

          <div class="btn-row" style="margin-top: 14px">
            <a class="btn btn-sm" href="javascript:addNewEmail()"><i class="fa-solid fa-plus"></i>Add New Email</a>
          </div>
        </div>
      </section>

      <section class="card">
        <div class="card-body">
          <p class="card-title">Account Deletion</p>
          <p class="muted">Click this button and answer confirmation questions to delete your account.</p>
          <a class="btn btn-danger" href="javascript:deleteAccount()"><i class="fa-solid fa-trash"></i>Delete Account</a>
        </div>
      </section>

          <% } %>

    </main>
  </div>

</body>

</html>
