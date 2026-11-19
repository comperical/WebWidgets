
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

    String templateString = Util.join(WebUtil.getConfigTemplate(currentUser.get()), "\n");
    String userHome = Util.sprintf("/%s/index.jsp", currentUser.get());
    String userConfigFileName = String.format("%s__widget.conf", currentUser.get().toString());

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


function downloadConfig()
{

    let csvContent = "data:text/plain;charset=utf-8," + `<%= templateString %>\n`;


    var encodedUri = encodeURI(csvContent);
    var link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `<%= userConfigFileName %>`);
    document.body.appendChild(link); // Required for FF

    link.click();
}

</script>


</head>
<body data-page="GetConfig">

  <%@include file="AdminTopBar.jsp_inc" %>

  <div class="admin-shell">

    <%@include file="AdminSideBar.jsp_inc" %>

    <main class="admin-main">

      <section class="card">
        <div class="card-body">
          <p class="card-title">Download Config File for Widget Development</p>
          <p>
          This page will help you get started with Widget development.
          The WebWidgets framework was designed to enable fast development, and easy setup.
          After you download the configuration file,
            follow the instructions on the <a href="https://webwidgets.io/u/docs/WidgetSetup">Widget Setup</a> page.
          </p>

          <a class="btn btn-primary" href="javascript:downloadConfig()"><i class="fa-solid fa-download"></i>Download Config File</a>
        </div>
      </section>

    </main>
  </div>

</body>

</html>
