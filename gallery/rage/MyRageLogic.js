

function getHeaderInfo()
{

    return [
        ["Rage Log", "widget.wisp"],
        ["Rage Stats", "RageStats.wisp"],
        ["Rage Graph", "RageGraph.wisp"]
    ];
}


function handleNavBar(curpage)
{
    populateTopNavBar(getHeaderInfo(), curpage)
}

