

<%@include file="CoreImport.jsp_inc" %>

<%
    ArgMap argMap = WebUtil.getArgMap(request);

    Optional<String> optBounceBack = argMap.optGetStr("bounceback");
    if(optBounceBack.equals(Optional.of("")))
        { optBounceBack = Optional.empty(); }

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
        Optional<WidgetItem> bounceItem = WebUtil.lookupWidgetFromPageUrl(optBounceBack.get());
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
    
    // Okay, we sent the password to the server, 
    // we'll compute the hash server-side and then just put it in the argmap to use downstream processing
    if(argMap.getBit("serverhash", false))
    {
        Util.massert(!argMap.containsKey("accesshash"), "Should NOT set the access hash here!!");
        Util.massert(CoreUtil.allowInsecureConnection(), 
            "The server-side hash login option can only be used when allow insecure is enabled");

        argMap.put("accesshash", AuthLogic.canonicalHash(argMap.getStr("password")));
    }
    
    
    String passwordFailCode = "";
    String accessHash = argMap.getStr("accesshash", "");

    if(!accessHash.isEmpty())
    {
        String username = argMap.getStr("username");
        boolean checkLogIn = AuthLogic.checkCredential(username, accessHash);
    
        if(!checkLogIn)
        {
            passwordFailCode = "Password for that user does not match";
        
        } else {

            AuthLogic.setUserCookie(request, response, username);
            AuthLogic.setAuthCookie(request, response, accessHash);
            
            WidgetUser wuser = WidgetUser.valueOf(username);
            String bouncedef = WebUtil.getUserHomeRelative(wuser);

            response.sendRedirect(optBounceBack.isPresent() ? optBounceBack.get() : bouncedef);
            return;
        }
    }

    // 
    Optional<WidgetUser> noAuthUser = AuthLogic.getUserNoAuthCheck(request);
    String defaultUserName = noAuthUser.isPresent() ? noAuthUser.get().toString() : "";

%>


<html>

<link rel="shortcut icon" href="/crm/images/favicon.png" type="image/png">

<head><title>Log In</title>

<%@include file="AssetInclude.jsp_inc" %>

<script>

function serverSideHashLogin()
{
    const subpack = { 
        "serverhash" : ""+true,
        "username" : getDocFormValue("input_username"),
        "password" : getDocFormValue("password")
    };

    if("bounceback" in getUrlParamHash())
        { subpack["bounceback"] = getUrlParamHash()["bounceback"]; }


    submit2Base(subpack);
}


function doLogIn()
{
    const connsecure = <%= request.isSecure() %>;

    if(!connsecure)
    {
        // If we allow insecure connections, then do a login where the hash is done server side.
        // Big gotcha : if the connection is not secure, the browser doesn't supply the crypto library (??!?!??)
        if(<%= CoreUtil.allowInsecureConnection() %>)
            { serverSideHashLogin(); }
        else 
            { alert("This can only be entered on a secure connection, please change the URL"); }

        return;
    }

    const password = getDocFormValue("password");
    digestMessage(password).then(hpass => sendLoginInfo(hpass));
}

function sendLoginInfo(hashpass) 
{
    const username = getDocFormValue("input_username");

    document.forms.login_submit.username.value = username;
    document.forms.login_submit.accesshash.value = hashpass;

    <%
        if(argMap.containsKey("bounceback"))
        {
    %>
    document.forms.login_submit.bounceback.value = "<%= argMap.getStr("bounceback") %>";
    <% } %> 

    document.forms.login_submit.submit();
}

// TODO: this function should be shared between this page and change password
async function digestMessage(message) {
    const msgUint8 = new TextEncoder().encode("<%= AuthLogic.WIDGET_PASSWORD_SALT %>" + message); 
    const hashBuffer = await crypto.subtle.digest('SHA-256', msgUint8);           // hash the message
    const hashArray = Array.from(new Uint8Array(hashBuffer));                     // convert buffer to byte array
    const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join(''); // convert bytes to hex string
    return hashHex;
}


function doFocus()
{
    // Focus on either the username, or the password fields
    <%
        String focusField = noAuthUser.isPresent() ? "password" : "username";
    %>

    const formel = getUniqElementByName("<%= focusField %>");
    formel.focus();
}

</script>



</head>

<body onLoad="javascript:doFocus()">

<center>

LOG IN


<table class="basic-table" width="50%" align="center">
<%
    if(passwordFailCode.length() > 0)
    {

%>
<tr>
<td colspan="2">
<%= passwordFailCode %>
</td>
</tr>
<% } %>

<tr>
<td>UserName</td>
<td>
<input type="text" name="input_username" value="<%= defaultUserName %>"/></input>
</td>            
</tr>
<tr>
<td>PassWord</td>
<td>
<input type="password" name="password"/></input>
</td>
</tr>
</table>

<br/>

<a class="css3button" onClick="javascript:doLogIn()">LogIn</a>

<br/><br/>

<form name="login_submit" action="/u/admin/LogIn.jsp" method="post">
<input name="username" type="hidden"/>
<input name="accesshash" type="hidden"/>
<input name="bounceback" type="hidden"/>
</form>

</center>
</body>
</html>
