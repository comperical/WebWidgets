


<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>TODO List</title>

<wisp widgetname="minitask"/>

<script>

var WITHIN_ACTIVE_IDX = 0;

function goToPrev()
{
    WITHIN_ACTIVE_IDX += 1;

    if(WITHIN_ACTIVE_IDX < 0)
        { WITHIN_ACTIVE_IDX = getDisplayList().length - 1; }

    redisplay();
}

function goToNext()
{
    WITHIN_ACTIVE_IDX += 1;

    if(WITHIN_ACTIVE_IDX == getDisplayList().length)
        { WITHIN_ACTIVE_IDX = 0; }

    redisplay();
}

function getDisplayList()
{
    return getTaskItemList(false).filter(item => item.getTaskType() == "life");
}


function redisplay()
{
    const activelist = getDisplayList();
    const item = activelist[WITHIN_ACTIVE_IDX];

    var pageinfo = `

    <label for="item1" class="todo-label">${item.getShortDesc()}</label>
    <p class="todo-description">

        ${item.getExtraInfo()}

    </p>

    `;


    populateSpanData({
        "mainitem" : pageinfo
    })

}

</script>


<!-- Add CSS for styling -->
<style>
    /* General styles */
    body {
        font-family: Arial, sans-serif;
    }

    /* Container for the TODO list items */
    .todo-container {
        max-width: 600px;
        margin: 0 auto;
        padding: 20px;
        border: 1px solid red; /* Add border style with desired color */

        padding-left: 60px;
        padding-right: 60px;

        position: relative;
        background-color: white;
    }

    /* Slideshow styles */
    .slideshow-container {
        overflow: hidden;
        border: 1px solid green; /* Add border style with desired color */            
    }

    .slideshow-items {
        display: flex;
        /* transition: transform 0.5s ease-in-out; */
    }

    .slideshow-item {
        /* flex: 0 0 100%; */
        padding: 20px;
        opacity: 1; /* Set initial opacity for non-foreground items */
    }

    .prev,
    .next {
        /* top: 50%; */
        /* transform: translateY(-50%); */
        position: absolute;
        top: 50%;

        cursor: pointer;
        padding: 20px; /* Adjust padding as needed */
        background-color: lightblue; /* Add background color for better visibility */
    }

    .prev {
        left: 0; /* Position left arrow at the left edge of the container */
    }

    .next {
        right: 0; /* Position right arrow at the right edge of the container */
    }

    /* Styling for TODO list items */
    .todo-item {

        margin-bottom: 10px;
        padding: 20px;
    }

    .todo-label {
        font-size: 18px; /* Example font size value, you can adjust as needed */
        font-weight: bold; /* Example font weight value, you can adjust as needed */
        /* Add any other desired styles for the TODO task labels */
    }


    /* Responsive styles */
    @media screen and (max-width: 768px) {
        .todo-container {
            padding: 10px;
        }

        .todo-item {
            font-size: 14px;
        }
    }
</style>
</head>
<body onLoad="javascript:redisplay()">
    <div class="todo-container">
        <h1>TODO List</h1>


        <div class="slideshow-container">
            <div class="todo-item">
                <div id="mainitem"></div>
            </div>
        </div>

        <div>
            <a class="prev" href="javascript:goToPrev()">&#10094;</a>
            <a class="next" href="javascript:goToNext()">&#10095;</a>  
        </div>



    </div>
</body>
</html>