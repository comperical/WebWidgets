<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Note App</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.2.0/dist/css/bootstrap.min.css" rel="stylesheet">


<wisp no_data="true"/>

<script>

function createNote(priority)
{
    const itemname = U.getDocFormValue("simple_item")
    
    if(itemname)
    {
        const todaycode = U.getTodayCode().getDateString();
        
        const newrec = {
            "task_type" : "life",
            "short_desc" : "SimpleEntry::" + itemname,
            "extra_info" : "",
            "alpha_date" : todaycode,
            "omega_date" : "",
            "priority" : priority,
            "is_backlog" : 0
        };
            
        const newtaskitem = W.buildItem("mini_task_list", newrec);
        newtaskitem.syncItem();
        redisplay();

        alert("Item created!!");
    }
}

function doClear()
{
    if(confirm("Are you sure you want to clear this entry?"))
    {
        redisplay();
    }


}

function redisplay()
{
    U.getUniqElementByName("simple_item").value = "";
    document.getElementById("noteText").focus();
}

</script>


</head>
<body onLoad="javascript:redisplay()">
    <div class="container p-3">
        <h2 class="mb-3">Simple Entry</h2>
        <textarea name="simple_item" class="form-control mb-3" id="noteText" rows="4" placeholder="Type your note here..."></textarea>
        <div class="btn-group" role="group">
            <button type="button" class="btn btn-danger" onclick="createNote(20)">Top Priority</button>
            <button type="button" class="btn btn-warning" onclick="createNote(10)">High Priority</button>
            <button type="button" class="btn btn-secondary" onclick="createNote(5)">Regular Priority</button>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.2.0/dist/js/bootstrap.bundle.min.js"></script>

</body>
</html>
