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

    List<WidgetItem> currentList = currentUser.get().getUserWidgetList();
    List<String> currentNameList = Util.map2list(currentList, item -> item.theName);


    Set<String> demoReadySet = CoreUtil.getDemoDataReadySet();

    Map<String, String> descriptionMap = Util.treemap();

    descriptionMap.put("chores",
        "Define chores and set frequency. Get reminded when it's time to do the chore again");

    descriptionMap.put("dayplan",
        "Organize your day! Plan activities to maximize efficiency. Create templates for routine days.");

    descriptionMap.put("health",
        "A very simple health-logging tool. Keep track of when you're not feeling well.");

    descriptionMap.put("links",
        "Link Manager - keep track of web links, categorize them, etc.");

    descriptionMap.put("mroutine",
        "Create a checklist of activities to do in the morning (email, calendar, make bed, etc)");

    descriptionMap.put("questions",
        "Your own mini version of Stack Overflow. Create questions, answer them, search for previous answers");

    descriptionMap.put("stuff",
        "Keep track of your stuff. Create Locations, and Containers, to hold objects. Search for an object name/description to find out where it is");



    /*
    descriptionMap.put("media",
        "Keep track of what books/TV/podcasts/movies you want to consume. Assign priorities and rank them.");

    descriptionMap.put("recipes",
        "Organize your recipes. Plan the weekly menu, and create shopping lists");

    descriptionMap.put("workout",
        "Dan's patented workout log system. Set weekly goals and make sure to meet them, or go into debt and make it up next week");



    descriptionMap.put("junkfood",
        "Track your junk food consumption, look at running averages, make sure it doesn't go too high!");


    descriptionMap.put("rage",
        "Remember the things that piss you off...! So you can avoid them in the future");

    descriptionMap.put("minitask", "Simple TODO list, with a couple of categories");
    */

    {
        var badlist = Util.filter2list(descriptionMap.keySet(), w -> !demoReadySet.contains(w));
        Util.foreach(badlist, w -> descriptionMap.remove(w));
    }

    String opcode = argMap.getStr("opcode", "");

    if(opcode.length() > 0)
    {

        String message = null;

        if(opcode.equals("do_import"))
        {
            String widgetname = argMap.getStr("widgetname");
            Util.massert(demoReadySet.contains(widgetname), "Unknown widget %s", widgetname);

            ImportWidgetFromGallery importer = new ImportWidgetFromGallery();
            importer.runWithArgs(currentUser.get(), widgetname);
            message = Util.sprintf("Successfully imported widget %s", widgetname);
        }

        Util.massert(message != null, "Unknown opcode %s", opcode);
        String encmssg = StringUtil.encodeURIComponent(message);
        String bounce2 = "ImportWidget.jsp?message=" + encmssg;
        response.sendRedirect(bounce2);
        return;        
    }

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
  
function importWidget(widgetname)
{
    const subpack = { "opcode" : "do_import", "widgetname" : widgetname };
    submit2Base(subpack);
}

function maybeAlertMessage()
{
    <% 

        if(serverMessage.length() > 0)
        {
    %>

    alert("<%= serverMessage %>");

    <% } %>
}

</script>


</head>
<body onLoad="javascript:maybeAlertMessage()">
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
      <%@include file="MajesticNavBar.jsp_inc" %>
      <!-- partial -->
      <div class="main-panel">
        <div class="content-wrapper">
          

          <div class="row">
            <div class="col-md-12 stretch-card">
              <div class="card">
                <div class="card-body">
                  <p class="card-title">Import Widget Template</p>
                  <p class="mb-md-0">
                  This tool allows you to copy pre-created widgets from a template.
                  <br/>
                  You can use them directly, or tweak them to suite your own needs.
                  </p>
                  
                  <div class="table-responsive">
                    <table id="recent-purchases-listing" class="table">
                      <thead>
                        <tr>
                            <th>Widget</th>
                            <th>Description</th>
                            <th>..</th>
                        </tr>
                      </thead>
                      <tbody>
<% 

    for(String importname : descriptionMap.keySet())
    {
        String thedesc = descriptionMap.get(importname);


%>
<tr>
<td><b><%= importname %></b></td>
<td><%= thedesc %></td>
<td>

<a href="javascript:importWidget('<%= importname %>')">
<img src="/u/shared/image/leftarrow.png" style="height: 18px; width: 18px" /></a>


</td>
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

