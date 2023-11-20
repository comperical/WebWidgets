
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 

import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.CollUtil;
import net.danburfoot.shared.RunnableTech.*;

import io.webwidgets.core.CoreUtil.*;
import io.webwidgets.core.WidgetOrg.*;
import io.webwidgets.core.AuthLogic.*;

public class TemplateGenerator
{

    private final LiteTableInfo _liteTable;

    List<String> _resultList = Util.vector();

    public TemplateGenerator(LiteTableInfo lti)
    {
        _liteTable = lti;

    }

    public List<String> runGeneration()
    {
        _liteTable.runSetupQuery();

        _resultList.clear();

        genHeaderStuff();

        return _resultList;
    }


    private void add(String formstr, Object... varargs)
    {
        _resultList.add(String.format(formstr, varargs));

    }

    private void genHeaderStuff()
    {

        additems(

            "<html>",
            "<head>",
            "",
            "<!-- standard wisp include tag -->",
            "<wisp/>",
            "",
            "<script>",
            "",
            "var EDIT_STUDY_ITEM = -1;",
            ""
        );


        add("function deleteItem(itemid) {");

        add("\tconst item = W.lookupItem('%s', itemid)", _liteTable.getSimpleTableName());
        add("\titem.deleteItem();");
        add("\tredisplay();");
        add("}");


        addCreateNew();

        addEditCode();


        addReDisplay();

        additems(
            "</script>",
            "<body onLoad=\"javascript:redisplay()\">",
            "<center>",
            "<div id=\"page_info\"></div>",
            ""

        );


        additems(
            "</center>",
            "</body>",
            "</html>"
        );

    }

    private static String jsonAssign(String colname, String coltype)
    {
        ArgMap mymap = new ArgMap();
        mymap.put(colname, "454534");

        Object lookup = LiteTableInfo.getPayLoad(colname, coltype, mymap);

        String result = lookup instanceof String ? "''" : 
                            (lookup instanceof Integer ? "0" : "0.0");

        return String.format("\t\t'%s' : %s", colname, result);
    }

    private static String jsonAssign(Map.Entry<String, String> entry)
    {
        return jsonAssign(entry.getKey(), entry.getValue());

    }

    private void addCreateNew()
    {
        additems(
            "",
            "// Auto-generated create new function",
            "function createNew() {",
            ""
        );

        add("\tconst newrec = {");

        List<String> assignlist = _liteTable.getColTypeMap()
                                            .entrySet()
                                            .stream()
                                            .filter(entry -> !entry.getKey().toLowerCase().equals("id"))
                                            .map(TemplateGenerator::jsonAssign)
                                            .collect(CollUtil.toList());

        add(Util.join(assignlist, ",\n"));


        add("\t};");

        add("\tconst newitem = W.buildItem('%s', newrec);", _liteTable.getSimpleTableName());
        // newitem.syncItem();
        // redisplay();

        additems(
            "\tnewitem.syncItem();",
            "\tredisplay();",
            "}",
            ""
        );
    }

    private void addEditCode()
    {
        additems(
            "",
            "// Auto-generated redisplay function",
            "function editStudyItem(itemid) {",
            "\tEDIT_STUDY_ITEM = itemid;",
            "\tredisplay();",
            "}"
        );


        additems(
            "",
            "function back2Main() {",
            "\tEDIT_STUDY_ITEM = -1;",
            "\tredisplay();",
            "}"
        );


        additems(
            "",
            "function shorten4Display(ob) {",
            "\tconst s = '' + ob;",
            "\tif(s.length < 40) { return s; }",
            "\treturn s.substring(0, 37) + '...';",
            "}"
        );        

    }

    private static String getGenericEditFunc(Class colclass)
    {
        String shortcode = null;

        if(colclass == Integer.class)
            { shortcode = "Int"; }

        if(colclass == Double.class)
            { shortcode = "Float"; }

        if(colclass == String.class)
            { shortcode = "Text"; }

        Util.massert(shortcode != null, "Unknown/invalid class type for generic function lookup: " + colclass);
        return String.format("genericEdit%sField", shortcode);
    }

    private void addReDisplay()
    {

        additems(
            "",
            "// Auto-generated redisplay function",
            "function redisplay() {",
            "\tconst pageinfo = EDIT_STUDY_ITEM == -1 ? getMainPageInfo() : getEditPageInfo();",
            "\tpopulateSpanData({\"page_info\" : pageinfo });",
            "}"
        );

        additems(
            "",
            "// Auto-generated getEditPageInfo function",
            "function getEditPageInfo() {",
            "",
            String.format("\tconst item = W.lookupItem('%s', EDIT_STUDY_ITEM);", _liteTable.getSimpleTableName()),
            "\tvar pageinfo = `",
            "\t<h4>Edit Item</h4>",
            "\t<table class=\"basic-table\" width=\"50%\">"
        );

        additems(
            "\t<tr>",
            "\t<td>Back</td>",
            "\t<td></td>",
            "\t<td><a href=\"javascript:back2Main()\"><img src=\"/u/shared/image/leftarrow.png\" height=\"18\"/></a></td>",
            "\t</tr>"
        );

        for(String col : _liteTable.getColTypeMap().keySet()) {

            Class colclass = LiteTableInfo.getJavaTypeFromLite(_liteTable.getColTypeMap().get(col));
            String genericfunc = getGenericEditFunc(colclass);

            add("\t<tr><td>%s</td>", CoreUtil.snake2CamelCase(col));
            add("\t<td>${item.get%s()}</td>", CoreUtil.snake2CamelCase(col));

            String tdcell = "\t<td></td>";

            if(!col.equals("id"))
            {
                tdcell = String.format(
                    "\t<td><a href=\"javascript:%s('%s', '%s', EDIT_STUDY_ITEM)\"><img src=\"/u/shared/image/edit.png\" height=\"18\"></a></td>", 
                    genericfunc, _liteTable.getSimpleTableName(), col
                );
            }

            add(tdcell);
            add("\t</tr>");
        }


        additems(
            "\t</table>",
            "\t`;",
            "\treturn pageinfo;",
            "",
            "}",
            ""
        );


        additems(
            "",
            "// Auto-generated getMainPageInfo function",
            "function getMainPageInfo() {",
            "",
            "\tvar pageinfo = `<h3>Main Listing</h3>",
            "\t\t<table class=\"basic-table\" width=\"80%\">",
            "\t\t<tr>"
        );

        for(String col : _liteTable.getColTypeMap().keySet()) {

            add("\t\t<th>%s</th>", col);
        }

        additems(
            "\t\t<th>..</th></tr>",
            "\t`;",
            String.format("\n\tconst itemlist = W.getItemList('%s');", _liteTable.getSimpleTableName()),
            "",
            "\titemlist.forEach(function(item) {",
            "\t\tconst rowstr = `",
            "\t\t\t<tr>"
        );

        for(String col : _liteTable.getColTypeMap().keySet()) {

            add("\t\t\t<td>${shorten4Display(item.get%s())}</td>", CoreUtil.snake2CamelCase(col));
        }

            // "\t\t<td></td>"
        // );


        additems(
            "\t\t\t<td>", 

            "\t\t\t<a href=\"javascript:editStudyItem(${item.getId()})\"><img src=\"/u/shared/image/inspect.png\" height=\"16\"/></a>", 
            "\t\t\t&nbsp;&nbsp;&nbsp;",

            "\t\t\t<a href=\"javascript:deleteItem(${item.getId()})\"><img src=\"/u/shared/image/remove.png\" height=\"16\"/></a>", 
            "\t\t\t</td>", 
            "\t\t\t</tr>", 
            "\t\t`;",           
            "\t\tpageinfo += rowstr;"
        );


        additems("\t});");

        additems(
            "",
            "\tpageinfo += `</table>`;",
            "\tpageinfo += `<br/><br/><a href=\"javascript:createNew()\"><button>new</button></a>`;",
            "\treturn pageinfo;"
        );


        additems(
            "}",
            ""
        );

    }

    private void additems(String... itemlist)
    {
        _resultList.addAll(Util.listify(itemlist));
    }

    public static class RunTemplateGenerator extends ArgMapRunnable
    {

        public void runOp()
        {
            WidgetUser user = WidgetUser.lookup(_argMap.getStr("username"));
            WidgetItem dbitem = new WidgetItem(user, _argMap.getStr("widgetname"));
            Util.massert(dbitem.dbFileExists(), "Missing local DB %s", dbitem);

            String tablename = _argMap.getStr("tablename");
            Util.massert(dbitem.getDbTableNameSet().contains(tablename),
                "No table named %s, options are %s", tablename, dbitem.getDbTableNameSet());

            LiteTableInfo info = new LiteTableInfo(dbitem, tablename);
            List<String> result = (new TemplateGenerator(info)).runGeneration();

            for(String s : result)
                { Util.pf("%s\n", s); }

            //String outputpath = "/opt/userdata/external/WebWidgets/gallery/links/TemplateTest.jsp";

            //FileUtils.getWriterUtil().setFile(outputpath).writeLineListE(result);

        }

    }
}
