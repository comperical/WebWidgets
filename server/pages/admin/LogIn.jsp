
<%@include file="../admin/CoreImport.jsp_inc" %>


<%
    ArgMap argMap = WebUtil.getArgMap(request);



    Optional<WidgetUser> currentUser = AuthLogic.getLoggedInUser(request);
    Optional<WidgetUser> noAuthUser = AuthLogic.getUserNoAuthCheck(request);

    String bounceBackRaw = argMap.getStr("bounceback", "");
    Optional<String> optBounceBack = bounceBackRaw.isEmpty() ? Optional.empty() : Optional.of(bounceBackRaw);
    Optional<WidgetItem> bounceItem = optBounceBack.isPresent() 
                                        ? WebUtil.lookupWidgetFromPageUrl(optBounceBack.get())
                                        : Optional.empty();


    boolean anyPassWordInfo = WebUtil.getCookieArgMap(request).containsKey(CoreUtil.ACCESS_HASH_COOKIE);

    // If the user has logged in another tab, don't require re-login.
    if(optBounceBack.isPresent())
    {
        // Handle special login logic. This forwards to a special URL
        // For this behavior to be enabled, the special plugin must be configured properly
        Optional<String> optLogin = PluginCentral.getGeneralPlugin().getSpecialLoginUrl(optBounceBack.get());
        if(optLogin.isPresent())
        {
            response.sendRedirect(optLogin.get());
            return;
        }

        // Careful, not all URLs can be mapped to a specific Widget
        if(bounceItem.isPresent())
        {
            AuthChecker bouncecheck = AuthChecker.build().userFromRequest(request).directDbWidget(bounceItem.get());
            if(bouncecheck.allowRead())
            {
                response.sendRedirect(optBounceBack.get());
                return;
            }
        }
    }


    String passwordFailCode = null;

    if(argMap.getBit("serverhash", false))
    {
      // Dec 2023 note: previous versions of login performed the password hash client-side,
      // so that the hashed data was never sent to the server. I think that is just paranoia,
      // makes me depend on weird JS crypto client libs
      // Jan 2026 update: it is actually required to do it this way; because the accesshash
      // is now set to be HttpOnly, it cannot be read in JS
      String username = argMap.getStr("username");
      String accessHash = AuthLogic.canonicalHash(argMap.getStr("password"));
      boolean checkLogIn = AuthLogic.checkCredential(username, accessHash);
  
      if(!checkLogIn)
      {
          passwordFailCode = "Password for that user does not match";
      
      } else {

          AuthLogic.setUserCookie(request, response, username);
          AuthLogic.setAuthCookie(request, response, accessHash);
          
          String bounce2 = optBounceBack.orElse("/u/admin/LogIn.jsp");
          response.sendRedirect(bounce2);
          return;
      }
    }

    String userHome = "#";
    if(noAuthUser.isPresent())
      { userHome = Util.sprintf("/%s/index.jsp", noAuthUser.get()); }

    String bounceBackAppend = optBounceBack.isPresent() ? "?bounceback=" + optBounceBack.get() : "";


    Optional<String> optClientId = PluginCentral.getGeneralPlugin().getGoogleClientId();
    // Optional<String> optClientId = Optional.empty();

    // TODO: June, 2026: this should return an optional Azure Client ID from the General Plugin
    Optional<String> optAzureId = Optional.of("dummy");
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
  
<%@include file="../admin/AssetInclude.jsp_inc" %>

<style>

code 
{
  background-color: lightgrey;
  color: black;
  border: 1px solid;
  border-color: black;
}

.g_id_signin {
    display: inline-block;
    min-width: 230px;
    min-height: 41px;
}

.google-signin-placeholder {
    display: inline-flex;
    align-items: center;
    width: 230px;
    height: 41px;
    padding: 0 12px;
    background-color: #1a73e8;
    color: #ffffff;
    font-family: Roboto, Arial, sans-serif;
    font-size: 15px;
    font-weight: 500;
    border: 1px solid #1558b0;
    border-radius: 4px;
    box-sizing: border-box;
}

</style>

<script>

// TODO: make the goddam code style above global


function serverSideHashLogin()
{
    const subform = document.forms._sub_form;
    subform.username.value = getDocFormValue("input_username");
    subform.password.value = getDocFormValue("input_password");
    subform.bounceback.value = "<%= optBounceBack.isPresent() ? optBounceBack.get() : "" %>";
    subform.submit();
}


function redisplay()
{
  updateAzureLoginButton();
}

function updateAzureLoginButton()
{

  const okayazure = <%= optAzureId.isPresent() %>;
  const asection = document.getElementById("azure_sign_on");

  if(!okayazure || asection == null)
    { return; }

  // This link auto-starts the AzureHandler flow
  const azureflow = "/u/exadmin/AzureHandler.jsp?gologin=true";

  asection.innerHTML = `

    <br/>
    <br/>

    <a href="${azureflow}" id="azure_sign_on_button" style="
         display: inline-flex;
         align-items: center;
         width: 230px;
         height: 41px;
         padding: 0 12px;
         background-color: #0090e7;
         color: #ffffff;
         font-family: 'Segoe UI', Segoe, Tahoma, Geneva, Verdana, sans-serif;
         font-size: 15px;
         font-weight: 600;
         text-decoration: none;
         border: 1px solid #0077bd;
         border-radius: 4px;
         box-sizing: border-box;">
      <svg xmlns="http://www.w3.org/2000/svg" width="21" height="21" viewBox="0 0 21 21" style="margin-right: 12px;">
        <rect x="1"  y="1"  width="9" height="9" fill="#f25022"/>
        <rect x="11" y="1"  width="9" height="9" fill="#7fba00"/>
        <rect x="1"  y="11" width="9" height="9" fill="#00a4ef"/>
        <rect x="11" y="11" width="9" height="9" fill="#ffb900"/>
      </svg>
      Sign in with Microsoft
    </a>
  `;
}

</script>

<% if(optClientId.isPresent()) { %>
<script src="https://accounts.google.com/gsi/client" async defer></script>
<% } %>
  
  
</head>
<body onLoad="javascript:redisplay()">
  <div class="container-scroller">
    <!-- partial:partials/_navbar.html -->
    <%@include file="AdminNavBar.jsp_inc" %>

    <!-- partial -->
    <div class="container-fluid page-body-wrapper">
      <!-- partial:partials/_sidebar.html -->
      <%@include file="../admin/MajesticNavBar.jsp_inc" %>
      <!-- partial -->
      <div class="main-panel">
        <div class="content-wrapper">
        

          <% 
            // This means there's NOTHING in the login cookies, probably user cleared cookies
            if(!noAuthUser.isPresent()) { 
          %>
          <div class="row">
            <div class="col-md-12 stretch-card">
              <div class="card">
                <div class="card-body">
                  <p class="card-title">Log In</p>
                  <p class="mb-4">
                  Please log-in with username and password
                  </p>

                  <%
                    if(passwordFailCode != null)
                    {
                  %>
                  <p style="color: red;">Incorrect password, please try again</p>
                  <% } %>


                  <form class="forms-sample">
                  <label style="font-size: 0.875rem;">Username:</label>
                  <input type="text" name="input_username" cols="40" autofocus />
                  <br/>
                  <label style="font-size: 0.875rem;">Password:</label>
                  <input type="password" name="input_password" cols="40" />
                  </form>

                  <br/>

                  <button class="btn btn-primary mr-2" onclick="javascript:serverSideHashLogin()">Submit</button>

                  <!-- This remains absent if Google SSO is not configured. -->
                  <% if(optClientId.isPresent()) { %>
                  <div id="google_sign_on">
                    <br/>
                    <br/>
                    <div id="g_id_onload"
                         data-client_id="<%= optClientId.get() %>"
                         data-context="signin"
                         data-ux_mode="popup"
                         data-login_uri="https://webwidgets.io/u/exadmin/OAuthHandler.jsp<%= bounceBackAppend %>"
                         data-auto_prompt="false">
                    </div>
                    <div class="g_id_signin"
                         data-type="standard"
                         data-shape="rectangular"
                         data-theme="filled_blue"
                         data-text="signin_with"
                         data-size="large"
                         data-width="230"
                         data-logo_alignment="left">
                      <span class="google-signin-placeholder">Sign in with Google</span>
                    </div>
                  </div>
                  <% } %>

                  <div id="azure_sign_on"></div>
                </div>
              </div>
            </div>
          </div>

          <% 

          // Okay, have a username, but the password is not valid
          // Show a re-login screen
          } else if (!currentUser.isPresent()) { 

            String messageHeader = "Session Expired";
            String messageBody = "Your session has expired. Please re-enter your password to continue";

            if(anyPassWordInfo)
            {
              messageHeader = "Invalid Password";
              messageBody = "The password you entered is no longer valid. Please re-enter your password:";
            }


          %>

          <div class="row">
            <div class="col-md-12 stretch-card">
              <div class="card">
                <div class="card-body">
                  <p class="card-title"><%= messageHeader %></p>
                  <p class="mb-4">
                  <%= messageBody %>
                  </p>



                  <%
                    if(passwordFailCode != null)
                    {
                  %>
                  <p style="color: red;">Incorrect password, please try again</p>
                  <% } %>


                  <p>Username: <code><%= noAuthUser.get() %></code></p>
                  <form class="forms-sample">
                  <label style="font-size: 0.875rem;">Password:</label>
                  <input type="hidden" name="input_username" value="<%= noAuthUser.get() %>" />
                  <input type="password" name="input_password" cols="40" autofocus />
                  </form>

                  <br/>
                  <br/>

                  <button class="btn btn-primary mr-2" onclick="javascript:serverSideHashLogin()">Submit</button>

                  &nbsp;
                  &nbsp;
                  &nbsp;


                  <button class="btn btn-primary mr-2" onclick="javascript:logoutAndReturn()">Log-Out</button>


                  <% if(optClientId.isPresent()) { %>
                  <div id="google_sign_on">
                    <br/>
                    <br/>
                    <div id="g_id_onload"
                         data-client_id="<%= optClientId.get() %>"
                         data-context="signin"
                         data-ux_mode="popup"
                         data-login_uri="https://webwidgets.io/u/exadmin/OAuthHandler.jsp<%= bounceBackAppend %>"
                         data-auto_prompt="false">
                    </div>
                    <div class="g_id_signin"
                         data-type="standard"
                         data-shape="rectangular"
                         data-theme="filled_blue"
                         data-text="signin_with"
                         data-size="large"
                         data-width="230"
                         data-logo_alignment="left">
                      <span class="google-signin-placeholder">Sign in with Google</span>
                    </div>
                  </div>
                  <% } %>

                  <div id="azure_sign_on"></div>
                </div>
              </div>
            </div>
          </div>
          <% 

            // In this situation, user is logged-in properly, but does not have access to the given widget
            } else if(optBounceBack.isPresent())  {

                String noAccessPage = String.format("<br/><br/>%s<br/>", optBounceBack.get());
                String pageOwner = " the owner of the page";

                if(bounceItem.isPresent())
                {
                  noAccessPage = String.format(" widget <code>%s</code>", bounceItem.get());
                  pageOwner = String.format(" owner of account <code>%s</code>", bounceItem.get().theOwner);
                }
          %>


          <div class="row">
            <div class="col-md-12 stretch-card">
              <div class="card">
                <div class="card-body">
                  <p class="card-title">Permission Denied</p>
                  <p class="mb-4">
                  Your account <code><%= noAuthUser.get() %></code> 
                  does not have permission to access <%= noAccessPage %>
                  </p>

                  <p class="mb-4">
                  If you think you should have access to this page, please ask for access from the <%= pageOwner %>
                  </p>

                  <p>
                  You can also log-out and log-in under a different account.
                  </p>
                  <br/>
                  <br/>

                  <button class="btn btn-primary mr-2" onclick="javascript:logoutAndReturn()">Log-Out</button>

                </div>
              </div>
            </div>
          </div>
          <% 

          // This is the final condition, user is logged-in and there's no bounceback, 
          // So just show a sucess message
          } else  { 

          %>

      
          <div class="row">
            <div class="col-md-12 stretch-card">
              <div class="card">
                <div class="card-body">
                  <p class="card-title">Logged In</p>
                  <p class="mb-4">
                  You are logged in as <code><%= currentUser.get() %></code>
                  </p>

                  <p>You can access your home page from the User Home button, or log-out and log-in as another user.</p>

                  <br/>
                  <br/>

                  <a href="<%= WebUtil.getUserHomeRelative(currentUser.get()) %>">
                  <button class="btn btn-primary mr-2">User Home</button></a>

                  &nbsp;
                  &nbsp;
                  &nbsp;

                  <button class="btn btn-primary mr-2" onclick="javascript:logoutAndReturn()">Log-Out</button>

                </div>
              </div>
            </div>
          </div>
          <% } %>

          <form name="_sub_form" method="POST">
          <input type="hidden" name="serverhash" value="true" />
          <input type="hidden" name="username" value="" />
          <input type="hidden" name="password" value="" />
          <input type="hidden" name="bounceback" value="" />
          </form>

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
