<%@include file="CoreImport.jsp_inc" %>

<%
    // TODO: need a way for the user to CREATE the groups DB
    // Also need to be able to filter by user / group

    Optional<WidgetUser> currentUser = AuthLogic.getLoggedInUser(request);
    if (!currentUser.isPresent()) {
        response.sendRedirect("LogIn");
        return;
    }

    ArgMap argMap = WebUtil.getArgMap(request);

    WidgetItem groupInfoDb = new WidgetItem(currentUser.get(), GranularPerm.GROUP_DB_NAME);
    boolean haveGroupDb = groupInfoDb.dbFileExists();

    String opcode = argMap.getStr("opcode", "");

    if(opcode.length() > 0)
    {

        String message = null;

        if(opcode.equals("create_new"))
        {

            int newid = groupInfoDb.newRandomId(GranularPerm.GROUP_INFO_TABLE);
            LinkedHashMap<String, Object> payload = CoreDb.getRecMap(
                CoreUtil.STANDARD_ID_COLUMN_NAME, newid,
                "user_name", argMap.getStr("user_name"),
                "group_name", argMap.getStr("group_name")
            );

            CoreDb.upsertFromRecMap(groupInfoDb, GranularPerm.GROUP_INFO_TABLE, 1, payload);
            message = String.format("Created new group record");
        }

        if(opcode.equals("delete_old"))
        {
            // Single record of "id" -> integer ID
            int delid = argMap.getInt("delete_id");
            var payload = CoreDb.getRecMap(CoreUtil.STANDARD_ID_COLUMN_NAME, delid);
            CoreDb.deleteFromColMap(groupInfoDb, GranularPerm.GROUP_INFO_TABLE, payload);
            message = "Deleted user / group association";
        }

        Util.massert(message != null, "Unknown opcode %s", opcode);
        String encmssg = StringUtil.encodeURIComponent(message);
        String bounce2 = "GroupControl?message=" + encmssg;
        response.sendRedirect(bounce2);
        return;
    }



    List<ArgMap> groupInfoList = Collections.emptyList();
    if(haveGroupDb)
    {
        groupInfoList = CoreUtil.fullTableQuery(groupInfoDb, GranularPerm.GROUP_INFO_TABLE).recList();
    }


    String serverMessage = argMap.getStr("message", "");    
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

// TODO: check for valid user and group names
function createNewRecord() {

    const opcode = "create_new";

    const group_name = prompt("Please enter the group name: ");
    if(group_name == null)
        { return; }

    const user_name = prompt("Please enter the user name:");
    if(user_name == null)
        { return; }

    U.submit2Base({ opcode, user_name, group_name });

}

function deleteOldRecord(itemid)
{
    const opcode = "delete_old";

    if(confirm("Are you sure you want to delete this group / user record?"))
    {
        const delete_id = itemid;
        U.submit2Base({ opcode, delete_id });
    }
}

// TODO: this can be used by other admin pages
function maybeRemoveServerMessage()
{
    const msg = document.getElementById("server-message");
    if (msg) {
        // Wait 3 seconds before starting fade-out
        setTimeout(function() {
            msg.style.transition = "opacity 1s ease";
            msg.style.opacity = "0";
            // Optionally remove after fade-out completes
            setTimeout(() => msg.remove(), 1000);
        }, 3000);
    }
}

document.addEventListener("DOMContentLoaded", maybeRemoveServerMessage);

</script>
</head>

<body data-page="GroupControl">

  <%@include file="AdminTopBar.jsp_inc" %>

  <div class="admin-shell">

    <%@include file="AdminSideBar.jsp_inc" %>

    <main class="admin-main">

      <% if (serverMessage.length() > 0) { %>
      <div class="alert alert-info" id="server-message">
        <i class="fa-solid fa-circle-info"></i>
        <p><%= serverMessage %></p>
      </div>
      <% } %>

      <section class="card">
        <div class="card-body">
          <div class="card-header">
            <p class="card-title">User Group Table</p>
            <button type="button" class="btn btn-primary" onclick="createNewRecord()"><i class="fa-solid fa-plus"></i>New Record</button>
          </div>

          <div class="table-wrap narrow">
            <table class="table">
              <thead>
                <tr>
                  <th>User</th>
                  <th>Group</th>
                  <th class="actions">Delete</th>
                </tr>
              </thead>
              <tbody>

<% if(groupInfoList.isEmpty()) { %>
                <tr>
                  <td colspan="3" class="empty-state">
                    <i class="fa-solid fa-users"></i>
                    <div>No group records found.</div>
                    <small>Click New Record to add your first group.</small>
                  </td>
                </tr>
<% } else {

    for(ArgMap record : groupInfoList)
    {
        int recid = record.getInt(CoreUtil.STANDARD_ID_COLUMN_NAME);
%>
                <tr>
                  <td><%= record.getStr("group_name") %></td>
                  <td><%= record.getStr("user_name") %></td>
                  <td class="actions">
                    <a class="icon-action danger" href="javascript:deleteOldRecord(<%= recid %>)" title="Delete record"><i class="fa-solid fa-trash"></i></a>
                  </td>
                </tr>

<% } %>
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
