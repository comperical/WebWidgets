

EXTRA = {

    EDIT_TEXT_MODE : false,

    // Opt-in flag for the SAFE event-binding technique.
    // When true, getHtmlString() emits SAFE data-attribute bindings instead of
    // inline onClick / javascript: handlers. Pages that set this must load the
    // SAFE library and call SAFE.registerAllEventListener() after injecting
    // the box HTML (typically at the end of redisplay()).
    // When false (default), output is identical to previous versions.
    USE_SAFE_BINDING : false,

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

    // Legacy-mode save: the box-builder is a javascript:-prefixed string,
    // resolved with eval. Not usable under a CSP that blocks eval;
    // SAFE-mode pages use safeModeSave instead.
    standardSave : function(boxbuilder) {

        U.massert(boxbuilder.startsWith("javascript:"), `Expected box-builder to start with javascript: prefix, found ${boxbuilder}`);
        const boxfunc = boxbuilder.substring("javascript:".length);
        const thebox = eval(boxfunc);

        const newval = U.getDocFormValue(thebox.textAreaName);
        thebox.consumerFunc(newval);
    },

    // SAFE-mode save: the box-builder function's NAME travels through the
    // SAFE args attribute (functions cannot travel through JSON) and is
    // resolved back at global scope. No eval, works under a strict CSP.
    safeModeSave : function(buildername) {

        const buildfunc = window[buildername];
        U.massert(typeof(buildfunc) == 'function', `Box-builder function ${buildername} not found at global scope`);

        const thebox = buildfunc();
        const newval = U.getDocFormValue(thebox.textAreaName);
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
    // TODO: Confirm whether this should call this.withProvider(provider).
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

// Two contracts, selected by EXTRA.USE_SAFE_BINDING at call time
// (so the flag must be set at page init, before boxes are built):
// legacy mode takes a javascript:-prefixed string, SAFE mode takes an
// actual function, which must be a named function at global scope so
// its name can travel through the SAFE args attribute.
ExtraInfoBox.prototype.withBoxBuilder = function(boxbuilder)
{
    if(EXTRA.USE_SAFE_BINDING)
    {
        U.massert(typeof(boxbuilder) == 'function',
            `Under USE_SAFE_BINDING, the box-builder must be an actual function, found ${boxbuilder}`);

        U.massert(window[boxbuilder.name] === boxbuilder,
            `Under USE_SAFE_BINDING, the box-builder must be a named function at global scope, found "${boxbuilder.name}"`);
    }
    else
    {
        U.massert(typeof(boxbuilder) == 'string' && boxbuilder.startsWith("javascript:"),
            `By convention, boxbuilder is a JS function name, starting with javascript:, found ${boxbuilder}`
        );
    }

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

// Build the save-button HTML for edit mode, honoring USE_SAFE_BINDING.
// Custom save functions are javascript: strings and cannot be converted
// to SAFE bindings, so they are incompatible with SAFE mode.
ExtraInfoBox.prototype.__getSaveButtonHtml = function()
{
    if(!EXTRA.USE_SAFE_BINDING)
        { return `<a href="${this.__getSaveFunc()}"><button>save</button></a>`; }

    U.massert(this.saveFuncName == null,
        "Custom save functions (withSaveFunction) are incompatible with USE_SAFE_BINDING, use the standard save flow via withBoxBuilder");

    U.massert(this.boxBuilder != null,
        "You must configure withBoxBuilder(...) to use the standard save flow with USE_SAFE_BINDING");

    return `<button ${SAFE.smartBinding(EXTRA.safeModeSave, 'click', { buildername : this.boxBuilder.name })}>save</button>`;
}

// Build the attribute string that opens the editor when the display cell
// is clicked, honoring USE_SAFE_BINDING.
ExtraInfoBox.prototype.__getEditModeClicker = function()
{
    if(!EXTRA.USE_SAFE_BINDING)
        { return `onClick="javascript:EXTRA.go2EditMode('${this.textAreaId}')"`; }

    return SAFE.smartBinding(EXTRA.go2EditMode, 'click', { areaid : this.textAreaId });
}



ExtraInfoBox.prototype.getHtmlString = function()
{
    U.massert(this.providerFunc != null, "You must supply a provider function");
    U.massert(this.consumerFunc != null, "You must supply a consumer function");
    const thetext = this.providerFunc();


    if(EXTRA.EDIT_TEXT_MODE) {

        return `

            <textarea id="${this.textAreaId}" name="${this.textAreaName}" cols="80" rows="10">${thetext}</textarea>
            <br/>
            <br/>
            ${this.__getSaveButtonHtml()}
        `;

    } else {

        let extradisp = thetext;

        if(extradisp.length == 0)
            { extradisp = "Not Yet Set"; }

        const extralist = extradisp.replace(/\n/g, "<br/>");

        return `
            <table class="basic-table" width="${this.tableWidth}%">
            <tr>
            <td style="text-align: left;" ${this.__getEditModeClicker()}>
            ${extralist}
            </td>
            </table>
        `;

    }




}
