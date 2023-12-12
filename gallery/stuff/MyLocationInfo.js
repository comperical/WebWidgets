const WO_HEADER_INFO = [
    ["Stuff Manager", "widget.wisp"],
    ["Locations", "Locations.wisp"]
];


function getLocationId(item)
{
    if(item.getLocationId() != -1)
        { return item.getLocationId(); }

    if(item.getContainerId() != -1)
    {
        const cont = W.lookupItem("stuff_item", item.getContainerId());
        return getLocationId(cont);
    }

    return -1;
}


function buildGenericMap(items, keyfunc, valfunc)
{
    const mymap = new Map();

    items.forEach(function(itm){
        const k = keyfunc(itm);
        const v = valfunc(itm);
        mymap.set(k, v);
    });

    return mymap;
}


function getLocationCountInfo()
{
    const cmap = buildGenericMap(W.getItemList("stuff_loc"), item => item.getId(), item => 0);

    W.getItemList("stuff_item").forEach(function(item) {
        const locid = getLocationId(item);
        const prev = cmap.has(locid) ? cmap.get(locid) : 0;
        cmap.set(locid, prev+1);
    });


    return cmap;
}


