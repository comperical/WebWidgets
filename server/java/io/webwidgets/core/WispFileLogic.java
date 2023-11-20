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


    // Experimental new WISP file format
    // This is a much cleaner way of pulling in the data than the old JSP format
    @WebServlet(urlPatterns = "*.wisp") 
    public static class WispServlet extends HttpServlet {

        public WispServlet() {
            super();
        }

        protected void doGet(HttpServletRequest request, HttpServletResponse response)  throws ServletException, IOException 
        {
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
            wff.sendResultToStream(response.getOutputStream(), accessor);
            response.getOutputStream().close();
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


        public void sendResultToStream(OutputStream out, Optional<WidgetUser> optacc) throws IOException
        {
            boolean includedone = false;

            for(String s : _srcList)
            {
                // Warning if the <wisp tag is not in the right place, ie within the <head> section?
                if(!s.trim().startsWith("<wisp"))
                {
                    // TODO: warning here if you see a <wisp tag but it's not at the start of the line
                    out.write(s.getBytes());
                    out.write("\n".getBytes());
                    continue;
                }

                // TODO: protect against scenarios where the line starts with <wisp but is not well-formatted

                try {
                    // TODO: this needs to be integrated with the CodeFormatChecker,
                    // this should never happen here
                    Map<DataIncludeArg, String> include = WispTagParser.parse2DataMap(s);

                    // THis conversion is dumb, the other code is just going to convert it back again
                    ArgMap convert = new ArgMap();
                    for(DataIncludeArg arg : include.keySet())
                        { convert.put(arg.toString(), include.get(arg)); }

                    WispServerUtil dstest = new WispServerUtil(optacc, pageItem, convert, includedone);
                    out.write(dstest.include().getBytes());
                    out.write("\n".getBytes());
                    includedone = true;

                } catch (IllegalArgumentException illex) {
                    throw illex;
                }
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
        final boolean _includeComplete;

        final Optional<WidgetUser> pageAccessor;

        final WidgetItem pageItem;
        
        public WispServerUtil(Optional<WidgetUser> accessor, WidgetItem pitem, ArgMap amap, boolean complete)
        {
            super(amap);

            pageAccessor = accessor;

            pageItem = pitem;

            _includeComplete = complete;
        }
        
        
        @Override
        protected Optional<WidgetUser> getPageAccessor()
        {
            return pageAccessor;
        }

        @Override
        protected boolean isIncludeComplete()
        {
            return _includeComplete;
        }

        @Override
        protected void markIncludeComplete()
        {
            // 
        }

        @Override
        protected Optional<WidgetItem> lookupPageWidget()
        {
            return Optional.of(pageItem);
        }
    }
}