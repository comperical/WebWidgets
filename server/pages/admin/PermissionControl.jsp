
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
    List<WidgetItem> widgetList = WidgetItem.getUserWidgetList(currentUser.get());
    List<String> widgetNameList = Util.map2list(widgetList, item -> item.theName);

    // User will see ugly error, but better than just being confused.
    Util.massert(widgetNameList.size() > 0, 
      "You must have at least one widget defined before accessing this page");

    if(!argMap.containsKey("widget"))
    {
      CollUtil.sortListByFunction(widgetList, item -> -item.getLocalDbFile().lastModified());
      String bounce = Util.sprintf("PermissionControl.jsp?widget=" + widgetList.get(0).theName);
      response.sendRedirect(bounce);
      return;
    }

    WidgetItem selectedItem = new WidgetItem(currentUser.get(), argMap.getStr("widget"));
    PermInfoPack selectedPerm = GlobalIndex.getPermInfo4Widget(selectedItem);

    String serverMessage = argMap.getStr("message", "");


    String opcode = argMap.getStr("opcode", "");

    if(opcode.length() > 0)
    {

      String granteeStr = argMap.getStr("grantee", "").toLowerCase();
      Optional<WidgetUser> optGrantee = WidgetUser.softLookup(granteeStr);

      boolean toggle = opcode.equals("toggle_public");

      if(!toggle && !optGrantee.isPresent())
      {
        String message = Util.sprintf("No Widget User found with name _%s_. Please check the spelling and try again, or contact system admin", granteeStr);

        String bounce = Util.sprintf("PermissionControl.jsp?widget=%s&message=%s", 
          selectedItem.theName, StringUtil.encodeURIComponent(message));

        response.sendRedirect(bounce);
        return;
      }

      if(toggle)
      {
        boolean ispublic = selectedPerm.isPublicRead();
        AuthLogic.markPublicRead(selectedItem, !ispublic);

      } else if(opcode.equals("add_perm")) {

        PermLevel grantperm = PermLevel.valueOf(argMap.getStr("permlevel"));
        AuthLogic.assignPermToGrantee(selectedItem, optGrantee.get(), grantperm);

      } else if(opcode.equals("remove_perm")) {

        AuthLogic.removePermFromGrantee(selectedItem, optGrantee.get());

      } else {

        Util.massert(false, "Invalid op code " + opcode);
      }

      String bounce = Util.sprintf("PermissionControl.jsp?widget=%s", selectedItem.theName);
      response.sendRedirect(bounce);
      return;
    }

    Map<WidgetUser, PermLevel> permInfoMap = selectedPerm.getCorePermMap();

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

function changeWidgetSelect()
{
  const newselect = getDocFormValue("widget_selector");
  const subpack = {"widget" : newselect};
  submit2Base(subpack);
}

function addReadPerm()
{
  promptAddPerm('read');
}

function addWritePerm()
{
  promptAddPerm('write');

}

function removePerm(grantee)
{
  if(confirm("Are you sure you want to remove the permissions from user " + grantee + "?"))
  {
    const subpack = {
      "opcode" : "remove_perm",
      "widget" : "<%= selectedItem.theName %>",
      "grantee" : grantee
    }
    submit2Base(subpack);    
  }
}

function redisplay()
{
    const widgetnames = ["<%= Util.join(widgetNameList, "\", \"") %>"];

    const optsel = buildOptSelector()
                        .configureFromList(widgetnames)
                        .sortByDisplay()
                        .setOnChange("javascript:changeWidgetSelect()")
                        .setElementName("widget_selector")
                        .setSelectedKey("<%= selectedItem.theName %>")
                        .getHtmlString();

    populateSpanData({"widget_select_span" : optsel});
}



function togglePublicRead()
{
  const pubread = <%= selectedPerm.isPublicRead() %>;
  const mssg = `
    This widget is currently set as 
    public-read :: ${pubread}
    this will change it to
    public-read :: ${!pubread}

    Okay?
  `;

  if(confirm(mssg))
  {
    const subpack = {
      "opcode" : "toggle_public",
      "widget" : "<%= selectedItem.theName %>"
    }
    submit2Base(subpack);      
  }
}

function promptAddPerm(permlevel)
{
  const grantee = prompt("Enter the Widget username to grant permissions: ");
  if(grantee)
  {
    const subpack = {
      "opcode" : "add_perm",
      "widget" : "<%= selectedItem.theName %>",
      "permlevel" : permlevel,
      "grantee" : grantee
    }
    submit2Base(subpack);
  }
}

</script>
  
  
</head>
<body onload="javascript:redisplay()">
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
        
        
          <% if(serverMessage.length() > 0) { %>    
          <div class="row">            
            <div class="col-md-12 stretch-card">
              <div class="card">
                <div class="card-body">
                  <p class="card-title">Message</p>
                  <p class="mb-4"><%= serverMessage %></p>
                </div>
              </div>
            </div>            
          </div>
          <br/>
          <% } %>
        
          <div class="row">
            <div class="col-md-12 stretch-card">
              <div class="card">
                <div class="card-body">
                  <p class="card-title">Permission Control</p>

                  <center>
                  <form class="forms-sample" align="center">
                    <div class="row">    
                    <div class="form-group">
                      <label>Widget:</label>
                      <span id="widget_select_span"></span>
                    </div>
                    </div>
                  </form> 
                  </center>


                  <div>
                    <table class="table" border="1">
                      <thead>
                        <tr>
                            <th>User</th>
                            <th>Permission</th>
                            <th>..</th>
                        </tr>
                      </thead>
                      <tbody>
<% 

    for(WidgetUser grantee : permInfoMap.keySet())
    {
      PermLevel level = permInfoMap.get(grantee);

%>
<tr>
<td><b><%= grantee %></b></td>
<td><%= level %></td>
<td>

<a href="javascript:removePerm('<%= grantee %>')"><i class="fa-solid fa-trash fa-lg"></i></a>

</td>
</tr>

<% } %>


<tr>
<td><b>Public Read</b></td>
<td><%= selectedPerm.isPublicRead() %></td>
<td>

<a href="javascript:togglePublicRead()"><i class="fa-solid fa-arrows-spin fa-lg"></i></a>


</td>
</tr>



                      </tbody>
                    </table>

                    <br/>
                    <br/>

                  <center>

                  <button class="btn btn-primary mr-2" onclick="addReadPerm()">+Read</button>

                  &nbsp;
                  &nbsp;
                  &nbsp;
                  &nbsp;

                  <button class="btn btn-primary mr-2" onclick="addWritePerm()">+Write</button>

                  </center>

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

