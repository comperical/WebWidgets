
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

    if(opcode.length() > 0)
    {
        if(opcode.equals("changepass"))
        {
            String newhash = argMap.getStr("newhash");
            String oldhash = argMap.getStr("oldhash");

            String message = "";

            if(!oldhash.equals(currentUser.get().getAccessHash()))
            {
                message = "Old password entered incorrectly, please try again";

            } else {

                AdvancedUtil.updateAccessHash(currentUser.get(), Pair.build(oldhash, newhash));
                message = "Password changed successfully";
                AuthLogic.setAuthCookie(request, response, newhash);
            }


            String encmssg = StringUtil.encodeURIComponent(message);
            String bounce2 = "ChangePass?message=" + encmssg;
            response.sendRedirect(bounce2);
            return;
        }
    }

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

PASS_PACKAGE = {};

// TODO: this function should be shared between this page and change password
async function digestMessage(message) {
  const msgUint8 = new TextEncoder().encode("<%= AuthLogic.WIDGET_PASSWORD_SALT %>" + message); 
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgUint8);           // hash the message
  const hashArray = Array.from(new Uint8Array(hashBuffer));                     // convert buffer to byte array
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join(''); // convert bytes to hex string
  return hashHex;
}


function getHashValuePromise(fieldname)
{
  const formstr = getDocFormValue(fieldname);
  return digestMessage(formstr);
}

function updateMaybeGo(fname, result)
{
  PASS_PACKAGE[fname] = result;

  if(Object.keys(PASS_PACKAGE).length != 3) 
    { return; }

  if(PASS_PACKAGE["new1x_pass"] != PASS_PACKAGE["new2x_pass"])
  {
      alert("Please make sure the 'new' and 'confirm' inputs are identical");
      return;
  }

  const subpack = { "opcode" : "changepass", "newhash": PASS_PACKAGE["new1x_pass"] , "oldhash" : PASS_PACKAGE["current_pass"] };
  submit2Base(subpack);    
}


function doSubmit()
{	
    const secure = <%= request.isSecure() %>;

    if(!secure)
    {
        alert("This can only be entered on a secure connection, please change the URL");
        return;
    }

    PASS_PACKAGE = {};

    getHashValuePromise("new1x_pass").then(x => updateMaybeGo("new1x_pass", x));
    getHashValuePromise("new2x_pass").then(x => updateMaybeGo("new2x_pass", x));
    getHashValuePromise("current_pass").then(x => updateMaybeGo("current_pass", x));
}

</script>
  
  
</head>
<body data-page="ChangePass">

  <%@include file="AdminTopBar.jsp_inc" %>

  <div class="admin-shell">

    <%@include file="AdminSideBar.jsp_inc" %>

    <main class="admin-main">

          <% if(serverMessage.length() > 0) { %>
      <div class="alert alert-info">
        <i class="fa-solid fa-circle-info"></i>
        <p><%= serverMessage %></p>
      </div>
          <% } %>

      <section class="card narrow">
        <div class="card-body">
          <p class="card-title">Change Password</p>

          <form>
            <div class="form-group">
              <label>Old Password</label>
              <input type="password" name="current_pass"/>
            </div>
            <div class="form-group">
              <label>New Password</label>
              <input type="password" name="new1x_pass"/>
            </div>
            <div class="form-group">
              <label>Confirm New</label>
              <input type="password" name="new2x_pass"/>
            </div>
          </form>
          <button class="btn btn-primary" onclick="doSubmit()">Submit</button>
        </div>
      </section>

    </main>
  </div>

</body>

</html>
