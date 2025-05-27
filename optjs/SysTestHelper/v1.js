

TEST_HELP = {

    EXAMINE_TEST_LABEL_KEY : null,

    TEST_CODE_PACKAGE : null,


    // This will typically be "TEST"
    configureTestCodePackage : function(tpack)
    {
        TEST_HELP.TEST_CODE_PACKAGE = tpack;
    },

    clearExamineTestLabel : function()
    {
        TEST_HELP.EXAMINE_TEST_LABEL_KEY = null;
        redisplay();
    },

    setExamineTestLabel: function(exlabel)
    {
        TEST_HELP.EXAMINE_TEST_LABEL_KEY = decodeURIComponent(exlabel);
        redisplay();
    },



    // Show the specific results of one of the test labels
    getExamineTestTable : function()
    {
        const labelkey = TEST_HELP.EXAMINE_TEST_LABEL_KEY;

        if(labelkey == null)
            { return ""; }


        let tableinfo = `
            <table class="basic-table" width="70%">
            <tr>
            <th>${labelkey} Detail Info</th>
            <th width="20%"><a href="javascript:TEST_HELP.clearExamineTestLabel()"><button>clear</button></a></th>
            </tr>
        `

        const labelmap = TEST_HELP.TEST_CODE_PACKAGE.getLabelTestMap();
        massert(labelmap.has(labelkey), `No test found with label ${labelkey}`);
        const errorlist = labelmap.get(labelkey)();

        errorlist.forEach(function(err) {
            tableinfo += `<tr><td colspan="2">${err}</td></tr>`
        })



        tableinfo += `</table>`;

        return tableinfo;
    },


    // Return the exam test table, which is either empty (if no label key is selected)
    // Or the table plus some padding around it, if it is not empty
    getExamineTestPadded : function()
    {
        const examtable = TEST_HELP.getExamineTestTable();
        return examtable.length == 0 ? "" : `<br/>${examtable}<br/>`;
    },

    getMainTestTable : function()
    {
        let mtable = `

            <table class="basic-table" width="70%">
            <tr>
            <th>TestName</th>
            <th>#Error</th>
            <th>Example</th>
            <th width="10%">Status</th>
            <th>..</th>
            </tr>
        `;

        const labelmap = TEST_HELP.TEST_CODE_PACKAGE.getLabelTestMap();

        [... labelmap.keys()].forEach(function(label) {

            const tfunc = labelmap.get(label);
            mtable += TEST_HELP.getTableRow(label, tfunc());
        })

        mtable += `
            </table>
        `;

        return mtable;
    },



    getTableRow : function(testname, errorlist)
    {
        if(errorlist.length == 0)
        {
            return `
                <tr>
                <td>${testname}</td>
                <td>0</td>
                <td>---</td>
                <td style="background-color: lightgreen"></td>
                <td></td>
                </tr>
            `;
        }


        const enclabel = encodeURIComponent(testname);


        return `
                <tr>
                <td>${testname}</td>
                <td>${errorlist.length}</td>
                <td>${errorlist[0]}</td>
                <td style="background-color: OrangeRed"></td>
                <td>
                <a href="javascript:TEST_HELP.setExamineTestLabel('${enclabel}')">
                <img src="/u/shared/image/inspect.png" height="18"/></a>
                </td>
                </tr>
        `;

    },

    getRecordCountTable : function()
    {
        const tablelist = W.getWidgetTableList();

        var rtable = `
            <table class="basic-table" width="60%">
            <tr>
            <th>Table Name</th>
            <th>#Rec</th>
            </tr>
        `;

        tablelist.forEach(function(tbl) {

            const numrec = W.getItemList(tbl).length;
            const rowstr = `
                <tr>
                <td>${tbl}</td>
                <td>${numrec}</td>
                </tr>
            `;

            rtable += rowstr;
        });

        rtable += "</table>";

        return rtable;
    }

}

