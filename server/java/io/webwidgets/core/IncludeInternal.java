package io.webwidgets.core; 


import java.io.*;
import java.util.*; 


import javax.servlet.http.*;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;



import io.webwidgets.core.AuthLogic.*;
import io.webwidgets.core.WidgetOrg.*;
import io.webwidgets.core.DataServer.*;
import io.webwidgets.core.WispFileLogic.*;


public class IncludeInternal
{

    // Internal data serve
    // This is a way of pulling in the JSON data for a tag using a separate <script src="...."> tag
    // This can be 
    @WebServlet(urlPatterns = "/directload") 
    public static class DirectJsonLoader extends HttpServlet {

        public DirectJsonLoader() {
            super();
        }

        protected void doGet(HttpServletRequest request, HttpServletResponse response)  throws ServletException, IOException
        {
            // TODO: maybe do something smarter here...?
            Util.massert(request.isSecure(), "This can only be served on a secure connection");

            Optional<WidgetUser> accessor = AuthLogic.getLoggedInUser(request);

            Map<DataIncludeArg, String> dargmap = getDargMap(request.getQueryString());

            Util.massert(dargmap != null, "Failed to parse DARG map with query string %s", request.getQueryString());

            var directinc = new DirectLoadInclude(dargmap, AuthLogic.getLoggedInUser(request));

            if(!AuthChecker.build().directSetAccessor(accessor).directDbWidget(directinc.sourceItem).allowRead())
            {
                // TODO: need to figure out clean-ish way to do error checking / notification here

            }

            if(!directinc.sourceItem.dbFileExists())
            {
                // Convey an error message of file not found

            }

            // Log some timing info?
            response.getOutputStream().write(directinc.include().getBytes());
            response.getOutputStream().write("\n".getBytes());
            response.getOutputStream().close();
        }

        private static Map<DataIncludeArg, String> getDargMap(String querystring)
        {
            ArgMap submap = ArgMap.buildFromQueryString("?" + querystring);
            Map<DataIncludeArg, String> dargmap = Util.treemap();

            for(String k : submap.keySet())
            {
                var kd = DataIncludeArg.valueOf(k);
                dargmap.put(kd, submap.get(k));
            }

            return dargmap;
        }
    }



    static class DirectLoadInclude extends ServerUtilCore
    {
        public final WidgetItem sourceItem;

        public final Optional<WidgetUser> pageAccessor;

        private DirectLoadInclude(Map<DataIncludeArg, String> amap, Optional<WidgetUser> pageacc)
        {
            super(amap);

            // TODO: reject some DARG params that are not valid in this 

            Util.massert(
                amap.containsKey(DataIncludeArg.username) && amap.containsKey(DataIncludeArg.widgetname),
                "Servlet based include must contain explicit username and widgetname fields, cannot infer from URL"
            );

            var srcuser = WidgetUser.lookup(amap.get(DataIncludeArg.username));
            sourceItem = new WidgetItem(srcuser, amap.get(DataIncludeArg.widgetname));

            pageAccessor = pageacc;
        }

        @Override
        protected boolean shouldPerformInclude(boolean global)
        {
            return false;
        }

        @Override
        protected void markIncludeComplete(boolean global)
        {
            Util.massert(false, "This include option should NEVER perform inclusion!!");
        }

        @Override
        protected Optional<WidgetItem> lookupPageWidget()
        {
            return Optional.of(sourceItem);
        }

        @Override
        protected Optional<WidgetUser> getPageAccessor()
        {
            return pageAccessor;
        }
    }


}