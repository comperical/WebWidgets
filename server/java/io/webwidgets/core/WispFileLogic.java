package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.util.zip.*;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.servlet.http.*;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.FileUtils;
import net.danburfoot.shared.StringUtil;

import io.webwidgets.core.AuthLogic.*;
import io.webwidgets.core.WidgetOrg.*;
import io.webwidgets.core.DataServer.*;


public class WispFileLogic
{


    // WISP file format servlet
    // This is now the preferred way to build WWIO apps. JSP is now restricted to admin users
    // WISP format is cleaner and more secure
    @WebServlet(urlPatterns = "*.wisp") 
    public static class WispServlet extends HttpServlet {

        public WispServlet() {
            super();
        }

        protected void doGet(HttpServletRequest request, HttpServletResponse response)  throws ServletException, IOException 
        {
            // Copied from AuthInclude
            if(!request.isSecure() && !AdvancedUtil.allowInsecureConnection())
            {
                String insecure = request.getRequestURL().toString();
                String oksecure = "https://" + insecure.substring("http://".length());
                response.sendRedirect(oksecure);
                return;
            }


            String path = request.getServletPath();

            File wispfile = new File(getServletContext().getRealPath(path));
            Util.massert(wispfile.exists(), "File does not exist: %s", wispfile);

            Optional<WidgetUser> accessor = AuthLogic.getLoggedInUser(request);
            Optional<WidgetItem> pageitem = WebUtil.lookupWidgetFromPageUrl(request);

            // TODO: This is not a great error message
            Util.massert(pageitem.isPresent(), "Somehow failed to find the widget in the request URL");

            if(!AuthChecker.build().directSetAccessor(accessor).directDbWidget(pageitem.get()).allowRead())
            {
                WebUtil.bounce2LogInPage(request, response);
                return;
            }


            WispFileFormat wff = new WispFileFormat(wispfile, pageitem.get());
            wff.sendResultToStream(request, response.getOutputStream(), accessor);
            response.getOutputStream().close();

            WebUtil.logPageLoad(request);
        }
    }


    public static class WispTagParser
    {
        public static String WISP_TAG_RESTR = "<wisp(?:\\s+\\w+=(\"[^\"]*\"|'[^']*'))*\\s*/>";

        static Pattern WISP_TAG_PATTERN = Pattern.compile(WISP_TAG_RESTR);

        static Pattern ATTR_PATTERN = Pattern.compile("(\\w+)=(\"[^\"]*\"|'[^']*')");

        public static Map<String, String> parse2AttributeMap(String tagline)
        {
            Matcher m = WISP_TAG_PATTERN.matcher(tagline.trim());

            if(!m.find())
                { return null; }

            Matcher attmatch = ATTR_PATTERN.matcher(m.group());
            Map<String, String> atts = Util.treemap();

            while (attmatch.find()) {
                String k = attmatch.group(1);
                String v = attmatch.group(2);

                // Removing the surrounding quotes
                v = v.substring(1, v.length() - 1);
                atts.put(k, v);
            }

            return atts;
        }

        public static Map<DataIncludeArg, String> parse2DataMap(String tagline)
        {
            Map<String, String> attmap = parse2AttributeMap(tagline);
            if(attmap == null)
                { return null; }


            Map<DataIncludeArg, String> incmap = Util.treemap();
            for(String k : attmap.keySet())
            {
                String v = attmap.get(k);
                incmap.put(DataIncludeArg.valueOf(k), v);
            }

            return incmap;
        }
    }


    public static class WispFileFormat
    {
        private final List<String> _srcList;

        private final WidgetItem pageItem;

        WispFileFormat(List<String> srclist, WidgetItem item)
        {
            _srcList = srclist;

            pageItem = item;
        }

        WispFileFormat(File src, WidgetItem item)
        {
            this(FileUtils.getReaderUtil().setFile(src).readLineListE(), item);
        }


        public void sendResultToStream(HttpServletRequest request, OutputStream out, Optional<WidgetUser> optacc) throws IOException
        {
            // Line number => Wisp data
            TreeMap<Integer, WispServerUtil> tagmap = Util.treemap();

            for(int idx : Util.range(_srcList))
            {
                String s = _srcList.get(idx);

                // Warning if the <wisp tag is not in the right place, ie within the <head> section?
                if(s.trim().startsWith("<wisp"))
                {
                    try {
                        // TODO: this needs to be integrated with the CodeFormatChecker,
                        // this should never happen here
                        Map<DataIncludeArg, String> dargmap = WispTagParser.parse2DataMap(s);

                        // This means the Wisp tag parsing failed
                        // Usually, but not always, this should be detected by the uploader
                        if(dargmap == null)
                        { 
                            String mssg =
                                "Your wisp file has a badly formatted wisp tag on line " + (idx+1) + 
                                " Any line starting with &lt;wisp must include a wisp tag " + 
                                " that is properly formatted and nothing else";

                            throw new RuntimeException(mssg);
                        }

                        maybePullUrlInfo(request, dargmap);
                        WispServerUtil wisptag = new WispServerUtil(optacc, pageItem, dargmap);
                        tagmap.put(idx, wisptag);

                    } catch (IllegalArgumentException illex) {
                        throw illex;
                    }
                }
            }

            Optional<WidgetItem> optItem = WebUtil.lookupWidgetFromPageUrl(request);
            double alphatime = Util.curtime();

            for(int idx : Util.range(_srcList))
            {
                String r = _srcList.get(idx);
                WispServerUtil tag = tagmap.get(idx);

                if(tag != null)
                {

                    StringBuilder sb = new StringBuilder();

                    // Pull in the Global includes BEFORE the first batch of Widget data.
                    if(idx == tagmap.firstKey())
                        { sb.append(ServerUtilCore.getGlobalInclude()); }

                    sb.append(tag.include());

                    // Epic bug caused by stray semicolon at the end of this line: 
                    // if(idx == tagmap.lastKey() && optItem.isPresent());

                    // If the Home widget is present, pull in user-defined auto-includes AFTER the last tag
                    if(idx == tagmap.lastKey() && optItem.isPresent())
                    { 
                        sb.append(ServerUtilCore.getUserAutoInclude(optItem.get())); 
                        sb.append(Util.sprintf("<!-- WISP_TAG_PROCESS_COMPLETE, took %.03f seconds -->\n", (Util.curtime()-alphatime)/1000));
                    }

                    r = sb.toString();
                }

                out.write(r.getBytes());
                out.write("\n".getBytes());
            }

        }

        private void maybePullUrlInfo(HttpServletRequest request, Map<DataIncludeArg, String> include)
        {

            if(request == null || !include.containsKey(DataIncludeArg.from_url))
                { return; }

            {
                String bitflag = include.get(DataIncludeArg.from_url);
                Util.massert(Util.setify(true+"", false+"").contains(bitflag),
                    "Argument of DataIncludeArg::from_url must be exactly equal to strings true or false, found %s", bitflag);

                if(!bitflag.equals(""+true))
                    { return; }
            }

            ArgMap reqmap = WebUtil.getArgMap(request);

            for(String k : reqmap.keySet())
            {
                String klow = k.toLowerCase();

                // If it's not a DataIncludeArg, skip it
                if(!DataServer.OKAY_ARG_SET.contains(klow))
                    { continue; }

                DataIncludeArg dia = DataIncludeArg.valueOf(klow);

                // Do not overwrite params that are already in the wisp tag
                if(include.containsKey(dia))
                    { continue; }

                include.put(dia, reqmap.get(k));
            }
        }

        public void checkCodeFormat()
        {
            for(int idx : Util.range(_srcList))
            {
                String s = _srcList.get(idx);

                // Warning if the <wisp tag is not in the right place, ie within the <head> section?
                if(!s.trim().startsWith("<wisp"))
                    { continue; }

                Map<String, String> attmap = WispTagParser.parse2AttributeMap(s);
                Util.massert(attmap != null, "Found improperly formatted wisp tag: %s", s);

                // THis conversion is dumb, the other code is just going to convert it back again
                Map<DataIncludeArg, String> dimap = Util.treemap();

                for(String argstr : attmap.keySet())
                { 
                    try {
                        DataIncludeArg diarg = DataIncludeArg.valueOf(argstr);
                        dimap.put(diarg, attmap.get(argstr));
                    } catch (IllegalArgumentException illex) {
                        // Bad wisp tag attribute name
                        Util.massert(false, "Found bad Wisp atttribute name %s in tag %s", argstr, s);
                    }
                }

                checkDataInclude(dimap);
            }
        }

        private void checkDataInclude(Map<DataIncludeArg, String> dimap)
        {
            WidgetUser owner = pageItem.theOwner;
            {
                String userstr = dimap.get(DataIncludeArg.username);
                if(userstr != null)
                {
                    Optional<WidgetUser> optowner = WidgetUser.softLookup(userstr);
                    Util.massert(optowner.isPresent(), "No widget user found with name %s", userstr);
                    owner = optowner.get();
                    Util.massert(dimap.containsKey(DataIncludeArg.widgetname),
                        "If you specify an widget owner in a wisp tag, you must also specify the widget name");
                }
            }

            // Default
            WidgetItem dbitem = pageItem;
            {
                String widgetstr = dimap.get(DataIncludeArg.widgetname);
                if(widgetstr != null)
                { 
                    Util.massert(widgetstr.equals(widgetstr.toLowerCase()), "Widget names must be lowercase, found %s", widgetstr);
                    dbitem = new WidgetItem(owner, widgetstr);
                }

                // This is probably redundant if the widget name was not overriden, but check again anyway
                Util.massert(dbitem.dbFileExists(), "Widget DB not found: %s", dbitem);

                // For cross-loading, the owner of the uploaded page must have read perms for other widget
                boolean canread = AuthChecker.build().directSetAccessor(pageItem.theOwner).directDbWidget(dbitem).allowRead();
                Util.massert(canread, "User %s does not have read permission for %s", owner, dbitem);
            }

            // Check table names
            {
                String tablestr = dimap.get(DataIncludeArg.tables);
                if(tablestr != null)
                {
                    Set<String> dbset = CoreDb.getLiteTableNameSet(dbitem);
                    for(String tbl : tablestr.split(","))
                    {
                        Util.massert(dbset.contains(tbl),
                            "Table %s not found in Widget DB %s, options are %s", tbl, dbitem, dbset);
                    }
                }
            }

            for(DataIncludeArg bitflag : Util.listify(DataIncludeArg.okay_if_absent, DataIncludeArg.no_data))
            {
                String bitstr = dimap.get(bitflag);
                if(bitstr == null)
                    { continue; } 

                Set<String> okayset = Util.setify(true+"", false+"");
                Util.massert(okayset.contains(bitstr), 
                    "Invalid value for binary argument %s :: %s, options are %s", bitflag, bitstr, okayset);

            }

            // TODO: check the view prefixes
        }


    }


    // This thing is a weird contraption that might not actually be necessary
    // It seems to be required because of the way the old DataServer.include(...) statements
    // "mark" that the inclusion of the core JS files is complete
    public static class WispServerUtil extends DataServer.ServerUtilCore
    {
        final Optional<WidgetUser> pageAccessor;

        final WidgetItem pageItem;

        private boolean _doGlobalInclude = false;

        private boolean _doUserInclude = false;
        
        public WispServerUtil(Optional<WidgetUser> accessor, WidgetItem pitem, Map<DataIncludeArg, String> dargmap)
        {
            super(dargmap);

            pageAccessor = accessor;

            pageItem = pitem;
        }
        
        void setGlobalInclude()
        {
            _doGlobalInclude = true;
        }

        void setUserInclude()
        {
            _doUserInclude = true;
        }
        
        @Override
        protected Optional<WidgetUser> getPageAccessor()
        {
            return pageAccessor;
        }


        @Override
        protected boolean shouldPerformInclude(boolean global)
        {
            // return _includeComplete;
            return global ? _doGlobalInclude : _doUserInclude;
        }

        @Override
        protected void markIncludeComplete(boolean global)
        {
            boolean relbit = global ? _doGlobalInclude : _doUserInclude;
            Util.massert(relbit, "Marked include complete for global=%s, but this tag was not configured to include it!!");
        }

        @Override
        protected Optional<WidgetItem> lookupPageWidget()
        {
            return Optional.of(pageItem);
        }

        @Override
        protected boolean sendToDirectLoad()
        {
            // August 2024, temporary testing approach, use only for me
            // return getPageAccessor().map(user -> user.toString()).orElse(".....").equals("dburfoot");
            return true;
        }
    }
}