

EXTRA = {

    EDIT_TEXT_MODE : false, 

    TEXT_AREA_DEFAULT_NAME : "extRA_infO_eDIt",

    getEiBox : function(text) {
        return new ExtraInfoBox(text);
    },

    go2EditMode : function(areaid) {
        EXTRA.EDIT_TEXT_MODE = true;
        redisplay();
        document.getElementById(areaid).focus();
    },

    clearEditMode : function() {
        EXTRA.EDIT_TEXT_MODE = false;
        redisplay();
    }
};

function ExtraInfoBox(textdata) {

    this.theText = textdata;

    this.textRows = null;
    this.textCols = null;

    // default to 50%
    this.tableWidth = 50;

    this.textAreaId = "myTextAREAid";

    this.saveFuncName = null;
    this.textAreaName = EXTRA.TEXT_AREA_DEFAULT_NAME;
}

ExtraInfoBox.prototype.setSaveFunction = function(savefunc)
{
    massert(typeof(savefunc) == "string" && savefunc.startsWith("javascript:"), 
        `By convention, savefunc is a text string that starts with javascript:, found ${savefunc}`);

    this.saveFuncName = savefunc;
    return this;
}


ExtraInfoBox.prototype.setTableWidth = function(twidth)
{
    massert(parseInt(twidth) == twidth, `Expected integer, got ${twidth}`);
    massert(3 <= twidth && twidth <= 100, `Invalid value for table width, expected integer from 3-100, got ${twidth}`);

    this.tableWidth = twidth;
    return this;
}


ExtraInfoBox.prototype.getHtmlString = function()
{
    massert(this.saveFuncName != null, "You must supply a saveFuncName");

    if(EXTRA.EDIT_TEXT_MODE) {

        return `

            <textarea id="${this.textAreaId}" name="${this.textAreaName}" cols="80" rows="10">${this.theText}</textarea>
            <br/>
            <br/>
            <a href="${this.saveFuncName}"><button>save</button></a>
        `;

    } else {

        let extrainfo = this.theText;

        if(extrainfo.length == 0)
            { extrainfo = "Not Yet Set"; }
        
        const extralist = extrainfo.replace(/\n/g, "<br/>");

        return `
            <table class="basic-table" width="${this.tableWidth}%">
            <tr>
            <td style="text-align: left;" onClick="javascript:EXTRA.go2EditMode('${this.textAreaId}')">
            ${extralist}
            </td>
            </table>
        `; 

    }




}