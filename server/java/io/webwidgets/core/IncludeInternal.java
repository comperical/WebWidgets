package io.webwidgets.core; 


import java.io.*;
import java.util.*; 


import javax.servlet.http.*;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.CollUtil.Pair;

import io.webwidgets.core.AuthLogic.*;
import io.webwidgets.core.WidgetOrg.*;
import io.webwidgets.core.DataServer.*;
import io.webwidgets.core.WispFileLogic.*;


public class IncludeInternal
{

    // Internal data serve
    // This is a way of pulling in the JSON data for a tag using a separate <script src="...."> tag
    @WebServlet(urlPatterns = "/directload") 
    public static class DirectJsonLoader extends HttpServlet {

        public DirectJsonLoader() {
            super();
        }

        protected void doGet(HttpServletRequest request, HttpServletResponse response)  throws ServletException, IOException
        {
            Util.massert(request.isSecure() || AdvancedUtil.allowInsecureConnection(),
                "This can only be served on a secure connection");

            Optional<WidgetUser> accessor = AuthLogic.getLoggedInUser(request);

            Map<DataIncludeArg, String> dargmap = DataServer.parseQuery2DargMap(request.getQueryString());

            Util.massert(dargmap != null, "Failed to parse DARG map with query string %s", request.getQueryString());

            var directinc = new DirectLoadInclude(dargmap, AuthLogic.getLoggedInUser(request));

            if(!directinc.sourceItem.dbFileExists())
            {
                // Convey an error message of file not found
                Util.massert(false, "The Widget DB %s was not found", directinc.sourceItem);
            }

            if(!AuthChecker.build().directSetAccessor(accessor).directDbWidget(directinc.sourceItem).allowRead())
            {
                // This error could be caused if a Widget developer wrote a page with a cross-load,
                // but didn't give the accessor read permissions for the page
                Util.massert(false,
                    "User %s attempted to load widget %s, but does not have read permissions, this can be caused by cross-loading",
                    accessor, directinc.sourceItem
                );
            }

            Pair<Long, Long> nmpair = parseNoneMatch(request.getHeader("If-None-Match"));
            long modtime = directinc.sourceItem.getLocalDbFile().lastModified();

            // Here we're checking if the SQLite DB has been modified. If not,
            // we can get away without doing very much work at all
            if(nmpair != null)
            {
                long nmtime = nmpair._1;
                if(nmtime == modtime)
                {
                    response.setStatus(HttpServletResponse.SC_NOT_MODIFIED);
                    return;
                }
            }

            // Generate the full include, and calculate the ETag
            byte[] content = directinc.include().getBytes();
            long conhash = generateContentHash(content);

            // Okay, this is the secondary check. If the DB was modified, but
            // the specific view of the data was not, we are probably still okay
            if(nmpair != null)
            {
                long nmhash = nmpair._2;
                if(nmhash == conhash)
                {
                    response.setStatus(HttpServletResponse.SC_NOT_MODIFIED);
                    return;
                }
            }

            // Okay, we have to actually serve the data. Compose an ETag based on the modtime and the hash
            response.setHeader("ETag", composeETag(modtime, conhash));
            response.setCharacterEncoding("UTF-8");
            response.getOutputStream().write(content);
            response.getOutputStream().write("\n".getBytes());
            response.getOutputStream().close();
        }

        // Very cautious parsing of NoneMatch field
        // It is a Long::Long pair, enclosed in double quotes
        private static Pair<Long, Long> parseNoneMatch(String nonematch)
        {
            if(nonematch == null)
                { return null; }

            String[] mod_hash = nonematch.replaceAll("\"", "").split("::");

            if(mod_hash.length != 2)
                { return null; }

            try {
                long a = Long.valueOf(mod_hash[0]);
                long b = Long.valueOf(mod_hash[1]);
                return Pair.build(a, b);
            } catch (NumberFormatException nfex) {
                return null;
            }
        }

        private static long generateContentHash(byte[] content)
        {
            var crc = new java.util.zip.CRC32();
            crc.update(content);
            return crc.getValue();
        }

        private static String composeETag(long modtime, long conhash)
        {
            return String.format("\"%d::%d\"", modtime, conhash);
        }
    }



    // This ServerUtil implementation just serves a DirectLoad request
    static class DirectLoadInclude extends ServerUtilCore
    {
        public final WidgetItem sourceItem;

        public final Optional<WidgetUser> pageAccessor;

        private DirectLoadInclude(Map<DataIncludeArg, String> amap, Optional<WidgetUser> pageacc)
        {
            super(amap);

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

        @Override
        protected boolean coreIncludeScriptTag()
        {
            return false;
        }
    }


}