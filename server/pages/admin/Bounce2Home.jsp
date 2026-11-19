<%@include file="CoreImport.jsp_inc" %>

<%
    Optional<WidgetUser> currentUser = AuthLogic.getLoggedInUser(request);

    String bounce2url = currentUser.isPresent()
            ? WebUtil.getUserHomeRelative(currentUser.get())
            : "/u/admin/LogIn";

    response.sendRedirect(bounce2url);
%>