<%@include file="CoreImport.jsp_inc" %>

<%
    Optional<WidgetUser> currentUser = AuthLogic.getLoggedInUser(request);
    if (!currentUser.isPresent()) {
        response.sendRedirect("LogIn.jsp");
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

    <link rel="stylesheet" href="/u/shared/majestic/vendors/mdi/css/materialdesignicons.min.css">
    <link rel="stylesheet" href="/u/shared/majestic/vendors/base/vendor.bundle.base.css">
    <link rel="stylesheet" href="/u/shared/majestic/vendors/datatables.net-bs4/dataTables.bootstrap4.css">
    <link rel="stylesheet" href="/u/shared/majestic/css/style.css">

    <%@include file="AssetInclude.jsp_inc" %>


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

<body>
    <div class="container-scroller">
        <%@include file="AdminNavBar.jsp_inc" %>

        <div class="container-fluid page-body-wrapper">
            <%@include file="MajesticNavBar.jsp_inc" %>

            <div class="main-panel">
                <div class="content-wrapper">


                    <div class="row">
                        <div class="col-md-12 stretch-card">
                            <div class="card">
                                <div class="card-body">
                                    <p class="card-title"> User Group Table</p>

                                    <div class="center-btn-container mb-4 mx-auto">
                                        <button type="button" 
                                        class="btn btn-primary new-record-btn"
                                            onclick="createNewRecord()">
                                            New Record
                                        </button>
                                    </div>


                                    <% if (serverMessage.length() > 0) { %>
                                    <div class="row">
                                        <div class="col-md-12 stretch-card">
                                            <div class="alert alert-info" id="server-message">
                                                <%= serverMessage %>
                                            </div>
                                        </div>
                                    </div>
                                    <% } %>


                                    <div class="table-responsive">
                                        <table 
                                        class="table table-striped table-bordered border-light w-75">
                                            <thead>
                                                <tr>
                                                    <th>User</th>
                                                    <th>Group</th>
                                                    <th width="8%">Delete</th>
                                                </tr>
                                            </thead>
                                            <tbody>

<%
    for(ArgMap record : groupInfoList)
    {
        int recid = record.getInt(CoreUtil.STANDARD_ID_COLUMN_NAME);
%>
        <tr>
            <td><%= record.getStr("group_name") %></td>
            <td><%= record.getStr("user_name") %></td>
            <td class="text-center">
            <a href="javascript:deleteOldRecord(<%= recid %>)">
            <i class="fa-solid fa-trash"></i></a>
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
        </div>
    </div>

    <%@include file="MajesticFooter.jsp_inc" %>
</body>

</html>
