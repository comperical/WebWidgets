

EXTRA = {

    EDIT_TEXT_MODE : false, 

    TEXT_AREA_DEFAULT_NAME : "extRA_infO_eDIt",

    getEiBox : function() {
        return new ExtraInfoBox();
    },

    go2EditMode : function(areaid) {
        EXTRA.EDIT_TEXT_MODE = true;
        redisplay();
        document.getElementById(areaid).focus();
    },

    clearEditMode : function() {
        EXTRA.EDIT_TEXT_MODE = false;
        redisplay();
    },

    standardSave : function(boxbuilder) {

        U.massert(boxbuilder.startsWith("javascript:"), `Expected box-builder to start with javascript: prefix, found ${boxbuilder}`);
        const boxfunc = boxbuilder.substring("javascript:".length);
        const thebox = eval(boxfunc);

        const newval = getDocFormValue(thebox.textAreaName);
        thebox.consumerFunc(newval);
    }
};

function ExtraInfoBox() {

    this.providerFunc = null;
    this.consumerFunc = null;

    this.textRows = null;
    this.textCols = null;

    this.boxBuilder = null;

    // default to 50%
    this.tableWidth = 50;

    this.textAreaId = "myTextAREAid";

    this.saveFuncName = null;
    this.textAreaName = EXTRA.TEXT_AREA_DEFAULT_NAME;

    this.doRedisplay = true;
}


ExtraInfoBox.prototype.withProvider = function(provfunc)
{
    U.massert(typeof(provfunc) == 'function', `Expected provfunc to be a function, found ${provfunc}`);
    U.massert(this.providerFunc == null, `Attempt to set provider function, but it has already been set`);

    this.providerFunc = provfunc;
    return this;
}


ExtraInfoBox.prototype.withConsumer = function(consfunc)
{
    U.massert(typeof(consfunc) == 'function', `Expected consumer func to be a function, found ${consfunc}`);
    U.massert(this.consumerFunc == null, `Attempt to set provider function, but it has already been set`);

    this.consumerFunc = consfunc;
    return this;
}

ExtraInfoBox.prototype.withTextInput = function(text)
{
    U.massert(typeof(text) == 'string', "Expected string argument for withTextInput(...)");

    const provider = () => text;
    return withProvider(provider);
}

// This is required if you want to use multiple EI boxes on the same page
ExtraInfoBox.prototype.withTextAreaName = function(areaname)
{
    U.massert(typeof(areaname) == 'string', "Expected string argument for withTextAreaName(...)");
    this.textAreaName = areaname;
    return this;
}



ExtraInfoBox.prototype.withStandardConfig = function(tablename, itemid, fieldname)
{
    const consfunc = function(newval)
    {
        const item = W.lookupItem(tablename, itemid);
        item.setField(fieldname, newval);
        item.syncItem();

        EXTRA.EDIT_TEXT_MODE = false;

        if(this.doRedisplay)
            { redisplay(); }
    }

    const provfunc = function()
    {
        const item = W.lookupItem(tablename, itemid);
        return item.getField(fieldname);
    }

    return this.withConsumer(consfunc).withProvider(provfunc);
}

ExtraInfoBox.prototype.withBoxBuilder = function(boxbuilder)
{
    U.massert(typeof(boxbuilder) == 'string' && boxbuilder.startsWith("javascript:"),
        `By convention, boxbuilder is a JS function name, starting with javascript:, found ${boxbuilder}`
    );

    this.boxBuilder = boxbuilder;
    return this;
}


ExtraInfoBox.prototype.withSaveFunction = function(savefunc)
{
    U.massert(typeof(savefunc) == "string" && savefunc.startsWith("javascript:"), 
        `By convention, savefunc is a text string that starts with javascript:, found ${savefunc}`);

    this.saveFuncName = savefunc;
    return this;
}


ExtraInfoBox.prototype.withTableWidth = function(twidth)
{
    U.massert(parseInt(twidth) == twidth, `Expected integer, got ${twidth}`);
    U.massert(3 <= twidth && twidth <= 100, `Invalid value for table width, expected integer from 3-100, got ${twidth}`);

    this.tableWidth = twidth;
    return this;
}

ExtraInfoBox.prototype.__getSaveFunc = function()
{
    if(this.saveFuncName != null)
        { return this.saveFuncName; }


    return `javascript:EXTRA.standardSave('${this.boxBuilder}')`;
}



ExtraInfoBox.prototype.getHtmlString = function()
{
    U.massert(this.providerFunc != null, "You must supply a provider function");
    U.massert(this.consumerFunc != null, "You must supply a consumer function");
    const thetext = this.providerFunc();


    if(EXTRA.EDIT_TEXT_MODE) {

        const savefunc = this.__getSaveFunc();

        return `

            <textarea id="${this.textAreaId}" name="${this.textAreaName}" cols="80" rows="10">${thetext}</textarea>
            <br/>
            <br/>
            <a href="${savefunc}"><button>save</button></a>
        `;

    } else {

        let extradisp = thetext;

        if(extradisp.length == 0)
            { extradisp = "Not Yet Set"; }
        
        const extralist = extradisp.replace(/\n/g, "<br/>");

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