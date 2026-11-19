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

    List<WidgetItem> currentList = WidgetItem.getUserWidgetList(currentUser.get());
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
        String bounce2 = "ImportWidget?message=" + encmssg;
        response.sendRedirect(bounce2);
        return;        
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
  
function importWidget(widgetname)
{
    const subpack = { "opcode" : "do_import", "widgetname" : widgetname };
    submit2Base(subpack);
}

// The server message is shown in the info box on the page; just drop ?message= from the
// address bar so a refresh doesn't show it again.
function clearMessageFromUrl()
{
    <%

        if(serverMessage.length() > 0)
        {
    %>

    history.replaceState(null, "", "ImportWidget");

    <% } %>
}

</script>


</head>
<body data-page="ImportWidget" onLoad="javascript:clearMessageFromUrl()">

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

      <section class="card">
        <div class="card-body">
          <p class="card-title">Import Widget Template</p>
          <p class="muted">
          This tool allows you to copy pre-created widgets from a template.
          You can use them directly, or tweak them to suite your own needs.
          </p>

          <div class="table-wrap">
            <table id="recent-purchases-listing" class="table">
              <thead>
                <tr>
                  <th>Widget</th>
                  <th>Description</th>
                  <th class="actions"></th>
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
                  <td class="actions">
                    <a class="btn btn-sm" href="javascript:importWidget('<%= importname %>')"><i class="fa-solid fa-file-import"></i>Import</a>
                  </td>
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
