
<%@include file="../../admin/AuthInclude.jsp_inc" %>

<html>
<head>
<title>Mini Task List</title>

<%@include file="../../admin/AssetInclude.jsp_inc" %>

<%= DataServer.basicInclude(request) %>

<script>


function createNewTask()
{

    
    var itemname = getDocFormValue("simple_item")
    
    if(itemname)
    {   
        var newid = newBasicId("mini_task_list");
        
        var todaycode = getTodayCode().getDateString();
        
        const newrec = {
            "id" : newid,
            "task_type" : "life",
            "short_desc" : "SimpleEntry::" + itemname,
            "extra_info" : "",
            "alpha_date" : todaycode,
            "omega_date" : "",
            "priority" : 5,
            "is_backlog" : 0
        };
            
        const newtaskitem = buildItem("mini_task_list", newrec);
        newtaskitem.registerNSync();
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
    getUniqElementByName("simple_item").value="..";
}





</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<h2>Simple Task Entry</h2>


<textarea name="simple_item" rows="10" cols="60"></textarea>

<br/><br/>

<a class="css3button" href="javascript:createNewTask()">create</a>

&nbsp;
&nbsp;
&nbsp;

<a class="css3button" href="javascript:doClear()">clear</a>


</center>

</body>
</html>
