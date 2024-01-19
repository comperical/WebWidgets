


// Copied from D57TM 
function buildGenericDict(items, keyfunc, valfunc)
{
    const mydict = {};

    items.forEach(function(itm){
        const k = keyfunc(itm);
        const v = valfunc(itm);
        mydict[k] = v;
    });

    return mydict;
}

