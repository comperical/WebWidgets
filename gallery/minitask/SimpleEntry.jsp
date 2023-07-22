
<html>
<head>
<title>Mini Task List</title>

<%= DataServer.include(request) %>

<script>


function createNewTask(priority)
{

    
    var itemname = getDocFormValue("simple_item")
    
    if(itemname)
    {           
        var todaycode = getTodayCode().getDateString();
        
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
    getUniqElementByName("simple_item").value = "";
    getUniqElementByName("simple_item").focus();
}





</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<h2>Simple Task Entry</h2>


<textarea name="simple_item" rows="10" cols="60"></textarea>

<br/><br/>

<a class="css3button" style="background:-webkit-gradient(linear,left top,left bottom,from(#f39),to(#f39));"
href="javascript:createNewTask(20)">TOP</a>

&nbsp;
&nbsp;
&nbsp;

&nbsp;
&nbsp;



<a class="css3button" href="javascript:createNewTask(10)"
style="background:-webkit-gradient(linear,left top,left bottom,from(#c0c),to(#c0c));">HIGH</a>

&nbsp;
&nbsp;


&nbsp;
&nbsp;
&nbsp;

<a class="css3button" href="javascript:createNewTask(5)">REG.</a>


</center>

</body>
</html>
