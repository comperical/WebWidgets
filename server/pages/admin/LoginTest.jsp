
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

    // TODO: integrate these into the PluginCentral just like for Google
    // This should just return a JSON object, with three fields
    String azureClientIdToken = "1ddb8e29-ab25-4314-99a0-8874e57a8bfb";
    String azureTenantIdToken = "cc3e2363-0c10-46a2-8a91-7f1a6cb0972a";

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
    max-width: 300px; /* Adjust to your preferred width */
    display: inline-block; /* Or as per your layout needs */
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
  updateGoogleLoginButton();
}

function updateGoogleLoginButton()
{
  const okaygoogle = <%= optClientId.isPresent() %>;

  if(!okaygoogle)
    { return; }

  const googledata = `

    <br/>
    <br/>

    <p>Single Sign On Providers</p>

    <div id="g_id_onload"
         data-client_id="<%= optClientId.get() %>"
         data-context="signin"
         data-ux_mode="popup"
         data-login_uri="https://webwidgets.io/u/exadmin/OAuthHandler.jsp<%= bounceBackAppend %>"
         data-auto_prompt="false">
    </div>


    <div class="g_id_signin"
         data-type="standard"
         data-shape="pill"
         data-theme="filled_blue"
         data-text="signin_with"
         data-size="large"
         data-logo_alignment="left">
    </div>
  `;

  const loginsection = document.getElementById("google_sign_on");

  if(loginsection != null)
  {
    loginsection.innerHTML = googledata;
    loadGoogleClientInfo();
  }

  // TODO: I am piggy-backing here on the Google Client ID presence.
  // Need to add a MSFT client ID option as well.
  const azuresection = document.getElementById("azure_sign_on");

  if(azuresection != null)
  {
    loadAzureClientInfo();

    const signon = `
      <a href="javascript:azureLogin()"><img src="/u/shared/image/msft-signin-button.svg"/></a>
    `
    azuresection.innerHTML = signon;
  }
}

function loadGenericSource(srcurl)
{
  var script = document.createElement("script");
  
  // Set the type attribute
  script.type = "text/javascript";
    
  script.src = srcurl;

  // Append the script element to the document's head (or body)
  document.head.appendChild(script);
}

function loadGoogleClientInfo()
{
  loadGenericSource("https://accounts.google.com/gsi/client");
}

function loadAzureClientInfo()
{
  loadGenericSource("https://alcdn.msauth.net/browser/2.14.2/js/msal-browser.min.js");
}

function azureLogin()
{
  // GPT told me to include this config, but it doesn't actually seem to be necessary
  /*
      cache: {
      cacheLocation: 'localStorage', // This configures where your cache will be stored
      storeAuthStateInCookie: true,  // Set to true if you are having issues on IE11 or Edge
    },
  */

  // The redirect URI doesn't seem to actually be used, but the Azure portal gives me an error
  // if I don't include it


  const msalConfig = {
    auth: {
      clientId: '<%= azureClientIdToken %>',
      authority: 'https://login.microsoftonline.com/<%= azureTenantIdToken %>',
      redirectUri: 'https://webwidgets.io/u/exadmin/DummyAzureHandler.jsp'
    }
  };

  const msalInstance = new msal.PublicClientApplication(msalConfig);
  const loginRequest = { scopes: ['openid', 'profile'] };

  msalInstance
      .loginPopup(loginRequest)
      .then(response => {
          // We just forward the response token here to the OAuthHandler
          const idtoken = response.idToken;
          document.__azure_form.azureidtoken.value = response.idToken;
          document.__azure_form.submit();
      })
      .catch(error => {
        alert(`Error with Azure login ${error}`);
      });
}



</script>
  
  
</head>
<body onLoad="javascript:redisplay()">
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

                  <!-- This remains empty if Google SSO is not present -->
                  <div id="google_sign_on"></div>

                  <br/>

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


                  <!-- This remains empty if Google configuration is not present -->
                  <div id="google_sign_on"></div>

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







                  <p>You can access your home page from the User Home link on the side bar, or log-out and log-in as another user.</p>

                  <br/>

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

          <form name="__azure_form" method="POST" action="/u/exadmin/OAuthHandler.jsp">
          <input type="hidden" name="azureidtoken" value="" />
          <input type="hidden" name="bounceback" value="<%= optBounceBack.orElse("") %>" />
          </form>


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

