
<html>
<head>
<title>SampleTime</title>

<%= DataServer.basicInclude(request) %>

<%= DataServer.includeIfAvailable(request, "sms_box", "outbox") %>


<script>

var LOG_SAMPLE_ID = -1;



function promptRedisplay()
{
    const params = getUrlParamHash();

    massert("id" in params, "Expected an ID param in query string");

    LOG_SAMPLE_ID = parseInt(params["id"]);

    massert(haveItem("samples", LOG_SAMPLE_ID), "Could not find sample ID " + LOG_SAMPLE_ID);

    const sampleitem = lookupItem("samples", LOG_SAMPLE_ID);

    const lognotes = prompt(`Enter activity for sample ${sampleitem.getId()}`, sampleitem.getNotes());
    sampleitem.setNotes(lognotes);
    sampleitem.syncItem();

    redisplay();

}

function redisplay()
{
    const sampleitem = lookupItem("samples", LOG_SAMPLE_ID);
    const outboxitem = lookupItem("outbox", sampleitem.getOutboxId());

    const exready = exactMomentFromIsoBasic(outboxitem.getReadyAtUtc(), "UTC");

    console.log("Ex reayd is " + exready.asIsoLongBasic("UTC"));

    const readypst = exready.asIsoLongBasic("PST").substring(10) + " PST";

    var senddpst = "---";
    if(outboxitem.getSentAtUtc().length > 0)
    {
        const exsendd = exactMomentFromIsoBasic(outboxitem.getSentAtUtc(), "UTC");
        senddpst = exsendd.asIsoLongBasic("PST").substring(10) + " PST";
    }


    populateSpanData({
        "sample_id" : sampleitem.getId(),
        "outbox_id" : sampleitem.getOutboxId(),
        "ready_pst" : readypst,
        "sendd_pst" : senddpst,
        "log_result" : sampleitem.getNotes()
    });    
}


</script>

</head>

<body onLoad="javascript:promptRedisplay()">

<center>

<span class="page_component" id="maintable_cmp">

<h2>Time Samples</h2>

<br/>
<a href="widget.jsp"><button>main</button></a>
<br/>
<br/>

<table width="30%" class="basic-table" >
<tr>
<td width="50%">Sample ID</td><td><div id="sample_id"></div></td>
</tr>
<tr>
<td>OutBox ID</td><td><div id="outbox_id"></div></td>
</tr>
<tr>
<td>Ready Time</td><td><div id="ready_pst"></div></td>
</tr>
<tr>
<td>Send Time</td><td><div id="sendd_pst"></div></td>
</tr>
</table>

<br/>
<br/>

<table width="40%" class="basic-table" >
<tr>
<th>Result</th>
</tr>
<tr>
<td>
<div id="log_result"></div>
</td>
</tr>
</table>

<br/><br/>


</center>
</body>
</html>
