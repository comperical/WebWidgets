<%@include file="CoreImport.jsp_inc" %>

<%
    Optional<WidgetUser> currentUser = AuthLogic.getLoggedInUser(request);

    String bounce2url = currentUser.isPresent()
            ? WebUtil.getUserHomeRelative(currentUser.get())
            : "/u/admin/LogIn.jsp";

    response.sendRedirect(bounce2url);
%>