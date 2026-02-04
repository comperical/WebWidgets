

ANTHRO = {

    SONNET_MODEL_CODE : "claude-sonnet-4-5-20250929",

    HAIKU_MODEL_CODE : "claude-haiku-4-5-20251001",

    CURRENT_MODEL_CODE : null,

    // Max log table size, if you are using the log technique
    MAX_GAI_TABLE_SIZE : 100,

    // You must set this to your API key
    API_KEY : null,

    // Max token size for basic messages
    MAX_TOKEN_BASIC : 8000,

    MESSAGE_ENDPOINT : "https://api.anthropic.com/v1/messages",

    setModelHaiku : function()
    {
        ANTHRO.CURRENT_MODEL_CODE = ANTHRO.HAIKU_MODEL_CODE;
    },

    setModelSonnet : function()
    {
        ANTHRO.CURRENT_MODEL_CODE = ANTHRO.SONNET_MODEL_CODE;
    },

    basicResponseOkay : function(gairesponse)
    {
        try {
            const data = ANTHRO.getGaiResponseText(gairesponse);
            return true;
        } catch (e) {
            return false;
        }
    },

    getGaiResponseText : function(gairesponse)
    {
        return gairesponse.content[0].text;
    },

    dummyRequest : function()
    {
        ANTHRO.setModelHaiku();

        const prompt = "Please tell me the weather on a typical day in fall in Raleigh, North Carolina";

        const cb = function(gairesponse)
        {
            const textinfo = ANTHRO.basicResponseOkay(gairesponse) ? ANTHRO.getGaiResponseText(gairesponse) : "Request Failed!!";
            console.log(textinfo);
        }

        ANTHRO.sendBasicMessage(prompt, cb);
    },

    getCurrentModelCode()
    {
        return ANTHRO.CURRENT_MODEL_CODE;
    },


    // Just a basic prompt message
    sendBasicMessage : function(prompt, callback)
    {
        const modelcode = ANTHRO.getCurrentModelCode();

        const query = {
            model : modelcode,
            max_tokens : ANTHRO.MAX_TOKEN_BASIC,
            messages : [
                {"role": "user", "content": prompt}
            ]
        };

        ANTHRO.sendFullQuery(query, callback);
    },


    // For this method, you compose the full Anthro JS format query yourself
    sendFullQuery : function(fullquery, callback)
    {
        U.massert(ANTHRO.API_KEY != null, "You must set the Anthro API Key first");

        const xhttp = new XMLHttpRequest();
        xhttp.open("POST", ANTHRO.MESSAGE_ENDPOINT, true);

        // Set the content type of your request
        xhttp.setRequestHeader("x-api-key", ANTHRO.API_KEY);
        xhttp.setRequestHeader("anthropic-dangerous-direct-browser-access", true);

        xhttp.setRequestHeader("anthropic-version", "2023-06-01");
        xhttp.setRequestHeader("content-type", "application/json");

        xhttp.onreadystatechange = function() {
            
            if (this.readyState == 4) {

                massert(this.status == 200 || this.status == 529,
                    `Unexpected error code on Ajax operation: ${this.status}. Please reach out to Dan to debug`);


                if(this.status == 200)
                {
                    const gairesponse = JSON.parse(this.responseText);
                    callback(gairesponse);
                }

                if(this.status == 529)
                {
                    alert("The Anthropic service is overloaded. Please try again at a later time");
                    callback(null);
                }
            }
        };

        xhttp.send(JSON.stringify(fullquery));
    },


    // This is for the scenario where you want to log responses
    // You need a table named "gai_response" with columns id, log_time_utc, and full_response
    clean2MaxTableSize : function()
    {
        const itemlist = W.getItemList("gai_response").sort(U.proxySort(item => [item.getLogTimeUtc()]));

        const num2delete = itemlist.length - ANTHRO.MAX_GAI_TABLE_SIZE;

        for(let idx = 0; idx < num2delete; idx++)
        {
            const olditem = itemlist[idx];
            olditem.deleteItem();
            console.log(`Cleaned old GAI response ${olditem.getId()}`);
        }
    },

    // Send the response, and log it in the gai_response table
    // The simple CB gets the ID of the resulting record in the gai_response table
    sendAndLogResponse : function(prompt, simplecb)
    {
        const mycb = function(gairesponse)
        {
            ANTHRO.clean2MaxTableSize();

            const record = {
                log_time_utc : exactMomentNow().asIsoLongBasic("UTC"),
                full_response : JSON.stringify(gairesponse)
            }

            const newitem = W.buildItem("gai_response", record);
            newitem.syncItem();
            simplecb(newitem.getId());
        }

        ANTHRO.sendBasicMessage(prompt, mycb);
    }

};


ANTHRO.CURRENT_MODEL_CODE = ANTHRO.HAIKU_MODEL_CODE;


