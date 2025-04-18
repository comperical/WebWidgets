

MODAL = {
    build : function() {
        return new SimpleModal();
    }
};

function SimpleModal() 
{

    this.topClass = "modal-top";

    this.titleClass = "modal-title";

    this.contentClass = "modal-content";

    this.contentHtml = null;

    this.titleHtml = null;

    this.useButton = false;

    // Only applied if requested
    this.buttonClass = null;

    this.buttonText = "X";

    this.buttonOnClick = null;
}


SimpleModal.prototype.setModalTopClass = function(topclass)
{
    this.topClass = topclass;
    return this;
}


SimpleModal.prototype.setModalTitleClass = function(titclass)
{
    this.titleClass = titclass;
    return this;
}

SimpleModal.prototype.setModalTitleHtml = function(titlehtml)
{
    this.titleHtml = titlehtml;
    return this;
}


SimpleModal.prototype.setModalContentHtml = function(conthtml)
{
    this.contentHtml = conthtml;
    return this;
}

SimpleModal.prototype.setUseButton = function(usebutton)
{
    massert(this.titleHtml != null, `Buttons only work if you have a modal title, please supply the title first`);
    this.useButton = usebutton;
    return this;
}


SimpleModal.prototype.setModalButtonText = function(buttontext)
{
    massert(this.useButton, `You must call setUseButton(true) before supplying the text`);


    this.buttonText = buttontext;
    return this;
}

SimpleModal.prototype.setButtonOnClick = function(buttonjs)
{
    massert(this.useButton, `You must call setUseButton(true) before supplying the onClick for the button`);


    massert(buttonjs.startsWith("javascript:"), 
            `By convention, argument to this function should have javascript: prefix, found ${buttonjs}`);

    this.buttonOnClick = buttonjs;
    return this;
}


SimpleModal.prototype.getHtmlString = function()
{

    const classinfo = function(classname)
    {
        return classname == null ? ""  : `class="${classname}"`;
    }

    let buttonstr = "";
    if(this.useButton)
    {
        const clickinfo = this.buttonOnClick == null ? "" : `onClick="${this.buttonOnClick}"`;
        buttonstr = `<button ${clickinfo}>${this.buttonText}</button>`;
    }


    let titlestr = "";
    if(this.titleHtml != null)
    {
        titlestr = `
            <div ${classinfo(this.titleClass)}>
                ${this.titleHtml}
                ${buttonstr}
            </div>
        `;
    }


    return `
      <div ${classinfo(this.topClass)}>
        ${titlestr}
        <div ${classinfo(this.contentClass)}>
            ${this.contentHtml}
        </div>
      </div>
    `;
}






