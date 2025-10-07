
<html>
<head>
<title>Plan Layout</title>

<wisp/>

<script>

// TODO: get recent
var SELECTED_LAYOUT = getActiveLayoutName();

function handleNavBar() 
{
    const current = "W/O Layout";

    populateTopNavBar(WO_HEADER_INFO, current);
}

function getLayoutList()
{
    const layset = new Set(W.getItemList("plan_layout").map(item => item.getLayoutName()));
    return [... layset];
}

function updateLayoutSel()
{
    SELECTED_LAYOUT = U.getDocFormValue("layout_sel");
    redisplay();
}

function deleteLayoutItem(itemid)
{
    U.genericDeleteItem("plan_layout", itemid);
}

function activateSelectedLayout()
{
    const prevactive = getActiveLayoutName();

    if(confirm(`This will deactivate layout ${prevactive} and activate ${SELECTED_LAYOUT}, okay?`))
    {
        const olditems = W.getItemList("plan_layout").filter(item => item.getLayoutName() == prevactive);

        const newitems = W.getItemList("plan_layout").filter(item => item.getLayoutName() == SELECTED_LAYOUT);

        olditems.forEach(function(item) {
            item.setIsActive(0);
            item.syncItem();
        });

        newitems.forEach(function(item) {
            item.setIsActive(1);
            item.syncItem();
        });

        redisplay();
    }


}

function add2Layout()
{
    if(SELECTED_LAYOUT == null)
    {
        alert("Please create a new layout first");
        return;
    }


    const woselected = U.getDocFormValue("workout_sel");

    const isactive = (SELECTED_LAYOUT == null || getActiveLayoutName() == SELECTED_LAYOUT) ? 1 : 0;

    const record = {
        "layout_name" : SELECTED_LAYOUT,
        "wo_code" : woselected,
        "goal_distance" : 5,
        "is_active" : isactive
    }

    const item = W.buildItem("plan_layout", record);
    item.syncItem();
    redisplay();
}

function newLayout()
{
    const layname = prompt("Enter a name for the new Layout: ");

    if(layname)
    {

        // CREATE TABLE plan_layout(id int, layout_name varchar(30), wo_code varchar(20), goal_distance int, is_recent smallint, primary key(id));

        const record = {
            "layout_name" : layname,
            "wo_code" : "erg",
            "goal_distance" : 5,
            "is_active" : 0
        }

        const item = W.buildItem("plan_layout", record);
        item.syncItem();
        SELECTED_LAYOUT = layname;
        redisplay();
    }

}

function editGoalDistance(itemid)
{
    genericEditIntField("plan_layout", "goal_distance", itemid);
}

function redisplay()
{
    handleNavBar();

    const layoutSel = buildOptSelector()
                        .configureFromList(getLayoutList())
                        .sortByDisplay()
                        .setSelectedKey(SELECTED_LAYOUT)
                        .setElementName("layout_sel")
                        .setOnChange("javascript:updateLayoutSel()")
                        .getHtmlString();

    var pageinfo = `

        <h3>Play Layouts</h3>

        ${layoutSel}

        <br/>
        <br/>

    `;

    if(getActiveLayoutName() == SELECTED_LAYOUT) 
    {
        pageinfo += `
            <table class="basic-table" width="20%">
            <tr>
            <td><b>Active</b></td>
            </tr>
            </table>
        `;
    } else {


        pageinfo += `
            <table class="basic-table" width="40%">
            <tr>
            <td><b>Inactive</b></td>
            <td>
            <a href="javascript:activateSelectedLayout()"><button>activate</button></a>
            </td>  
            </tr>
            </table>
        `
    }

    pageinfo += `

        <br/><br/>


        <table class="basic-table" width="50%">
        <tr>
        <th>Workout</th>
        <th>Goal</th>
        <th>Active</th>
        <th>...</th>
        </tr>

    `

    const thislayout = W.getItemList("plan_layout").filter(item => item.getLayoutName() == SELECTED_LAYOUT);

    thislayout.forEach(function(item) {

        const workout = W.getItemList("exercise_plan").filter(exitm => exitm.getShortCode() == item.getWoCode())[0];

        const activ = item.getIsActive() == 1 ? "Y" : "N";

        const rowstr = `
            <tr>
            <td>${item.getWoCode()}</td>
            <td>${item.getGoalDistance()}  ${workout.getUnitCode()}</td>
            <td>${activ}</td>
            <td>

            <a href="javascript:editGoalDistance(${item.getId()})"><img src="/u/shared/image/edit.png" height="16"/></a>

            &nbsp;
            &nbsp;
            &nbsp;

            <a href="javascript:deleteLayoutItem(${item.getId()})"><img src="/u/shared/image/remove.png" height="16"/></a>
            </td>
            </tr>
        `

        pageinfo += rowstr;
    })

    pageinfo += `
        </table>
    `;


    const workoutList = W.getItemList("exercise_plan").map(item => item.getShortCode());
    const workoutSel = buildOptSelector()
                            .configureFromList(workoutList)
                            .sortByDisplay()
                            .setElementName("workout_sel")
                            .setOnChange("javascript:add2Layout()")
                            .insertStartingPair(-1, "---")
                            .getHtmlString();


    pageinfo += `

        <br/>
        <br/>

        Add to this Layout: ${workoutSel}

        <br/>
        <br/>

        <a href="javascript:newLayout()"><button>+layout</button></a>

    `;


    U.populateSpanData({ "complete_log": pageinfo });
}



</script>

</head>

<body onLoad="javascript:redisplay()">




<center>

<div class="topnav"></div>

<br/>

<center>

<div id="complete_log"></div>


</center>
</body>
</html>
