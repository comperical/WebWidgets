// MyOpenRouter2.js — fluent rewrite of MyOpenRouter.js.
// Module-level state and constants live on OPENR.
// Per-request configuration goes through the OpenRouterRequest fluent builder.

OPENR = {

    // OpenRouter "semantic latest" model codes — aliases that auto-route to the
    // latest version in each model family. See https://openrouter.ai/models
    SONNET_LATEST : "~anthropic/claude-sonnet-latest",

    HAIKU_LATEST : "~anthropic/claude-haiku-latest",

    OPUS_LATEST : "~anthropic/claude-opus-latest",

    GPT_LATEST : "~openai/gpt-latest",

    GPT_MINI_LATEST : "~openai/gpt-mini-latest",

    GEMINI_FLASH_LATEST : "~google/gemini-flash-latest",

    GEMINI_PRO_LATEST : "~google/gemini-pro-latest",

    KIMI_LATEST : "~moonshotai/kimi-latest",

    MESSAGE_ENDPOINT : "https://openrouter.ai/api/v1/chat/completions",

    // Default max_tokens for new OpenRouterRequest instances. Model must be set per-request.
    DEFAULT_MAX_TOKENS : 8000,

    // You must set this to your OpenRouter API key before sending requests
    API_KEY : null,

    // Name of the table used by enableLogging. Override before first request.
    LOG_TABLE_NAME : "gai_response",

    // Max log table size; cleanup runs before each logged insert
    MAX_LOG_TABLE_SIZE : 100,


    setApiKey : function(key)
    {
        OPENR.API_KEY = key;
    },

    setLogTableName : function(name)
    {
        OPENR.LOG_TABLE_NAME = name;
    },

    setMaxLogTableSize : function(size)
    {
        OPENR.MAX_LOG_TABLE_SIZE = size;
    },


    // Extract the model's text response from a result object, or null if !success.
    getResponseText : function(result)
    {
        if (!result.success || result.gai_response == null) { return null; }
        return result.gai_response.choices[0].message.content;
    },

    // Internal: map an HTTP status (and response body) to a human-readable error message.
    __errorMessageForStatus : function(status, responseText)
    {
        if (status == 401) {
            return "OpenRouter rejected the API key (401). Check OPENR.API_KEY.";
        }
        if (status == 400) {
            return `Bad request (400): ${responseText}`;
        }
        if (status == 429) {
            return "OpenRouter rate limit hit (429). Try again later.";
        }
        if (status == 502 || status == 503) {
            return `Upstream LLM provider unavailable (${status}). Try again later.`;
        }
        return `Unexpected status ${status}: ${responseText}`;
    },


    // Internal: send a fully-composed query via XHR. Public callers should use
    // buildOpenRouterRequest() instead. Callback receives a result object:
    //   { success, status, prompt, full_query, gai_response, error_message }
    __sendQuery : function(fullquery, callback)
    {
        U.massert(OPENR.API_KEY != null,
            "You must set the OpenRouter API Key first (OPENR.setApiKey)");

        const xhttp = new XMLHttpRequest();
        xhttp.open("POST", OPENR.MESSAGE_ENDPOINT, true);
        xhttp.setRequestHeader("Authorization", `Bearer ${OPENR.API_KEY}`);
        xhttp.setRequestHeader("content-type", "application/json");

        const userMsg = (fullquery.messages || []).find(m => m.role === "user");
        const prompt = userMsg ? userMsg.content : null;

        xhttp.onreadystatechange = function() {

            if (this.readyState != 4) { return; }

            const result = {
                success       : false,
                status        : this.status,
                prompt        : prompt,
                full_query    : fullquery,
                gai_response  : null,
                error_message : null,
            };

            if (this.status == 200) {
                try {
                    result.gai_response = JSON.parse(this.responseText);
                    result.success = true;
                } catch (e) {
                    result.error_message = `Failed to parse OpenRouter response: ${e.message}`;
                }
            } else {
                result.error_message = OPENR.__errorMessageForStatus(this.status, this.responseText);
            }

            callback(result);
        };

        xhttp.send(JSON.stringify(fullquery));
    },

    __checkLogTableIssue : function(tablename)
    {
        if(!W.haveTable(tablename))
            { return `No logging table ${tablename} loaded, did you forget to request it?`; }


        const fieldlist = W.getFieldList(tablename);

        if(!fieldlist.includes("log_time_utc"))
            { return `Table ${tablename} must include a log_time_utc column`; }

        if(!(fieldlist.includes("response_text") || fieldlist.includes("full_response")))
            { return `Table ${tablename} must include either response_text or full_response column`; }


        return null;
    },


    // Internal: log a result to the named table and return the new record id.
    // Triggered by the request builder when its _logTable points to an existing table.
    // The table must have a log_time_utc column. Other candidate columns are
    // populated if they exist in the schema:
    //   log_time_utc (required), full_response, prompt, model, success, status,
    //   error_message, response_text
    __logResult : function(result, tablename)
    {
        OPENR.__cleanLogTable(tablename);

        const candidates = {
            log_time_utc  : exactMomentNow().asIsoLongBasic("UTC"),
            full_response : JSON.stringify(result),
            prompt        : result.prompt,
            model         : result.full_query.model,
            success       : result.success,
            status        : result.status,
            error_message : result.error_message,
            response_text : OPENR.getResponseText(result),
        };

        const record = {};
        W.getFieldList(tablename).forEach(field => {
            if (field in candidates) {
                record[field] = candidates[field];
            }
        });

        const newitem = W.buildItem(tablename, record);
        newitem.syncItem();
        return newitem.getId();
    },


    // Internal: trim the named log table to MAX_LOG_TABLE_SIZE - 1 rows so the next insert lands at MAX.
    // Requires the table to have a log_time_utc column (used as the sort key).
    __cleanLogTable : function(tablename)
    {
        const fieldList = W.getFieldList(tablename);
        U.massert(fieldList.includes("log_time_utc"),
            `Log table "${tablename}" must have a log_time_utc column`);

        const itemlist = W.getItemList(tablename).sort(U.proxySort(item => [item.getLogTimeUtc()]));

        const num2delete = itemlist.length - OPENR.MAX_LOG_TABLE_SIZE + 1;

        for(let idx = 0; idx < num2delete; idx++)
        {
            const olditem = itemlist[idx];
            olditem.deleteItem();
            console.log(`Cleaned old GAI response ${olditem.getId()}`);
        }
    },

    build : function()
    {
        return new OpenRouterRequest();
    },

    // Quick smoke test — sends a tiny prompt and logs the text to console.
    dummyRequest : function()
    {
        const logtarget = W.haveTable(OPENR.LOG_TABLE_NAME) ? OPENR.LOG_TABLE_NAME : null;


        OPENR.build()
            .setModelByCode(OPENR.HAIKU_LATEST)
            .setLogTableName(logtarget)
            .addPrompt("Please tell me the weather on a typical day in fall in Raleigh, North Carolina")
            .setCallBack(function(result) {
                const textinfo = result.success ? OPENR.getResponseText(result) : result.error_message;
                console.log(textinfo);
            })
            .send();
    },
};


// =====================================================================
// OpenRouterRequest — fluent builder for a single OpenRouter API call.
// Use build() instead of `new` for fluent style.
// =====================================================================

function OpenRouterRequest()
{
    // These are all for simple-query mode
    this._maxTokenCount = null;
    this._modelCode = null;
    this._messages = [];


    // If non-null, bypasses _modelCode/_maxTokens/_messages and sends as-is
    this._fullQuery = null;

    // Log table for this request. Inherits the OPENR default at construction time.
    // null means logging is disabled. Logging at send time also requires the table to exist.
    this._logTable = OPENR.LOG_TABLE_NAME;

    // Callback that receives the result object when send() completes. Must be set via setCallBack().
    this._myCallBack = null;
}

// Set any model by passing the OpenRouter model code directly
OpenRouterRequest.prototype.setModelByCode = function(modelcode)
{
    U.massert(this._modelCode == null, `You already set the model code to ${modelcode}`);
    U.massert(!this.isFullQueryMode(), `This request is in full-query mode, you cannt specify a model here`);

    this._modelCode = modelcode;
    return this;
}


// Override the default max_tokens for this request
OpenRouterRequest.prototype.setMaxTokenCount = function(n)
{
    U.massert(!this.isFullQueryMode(), `This request is in full-query mode, you cannt specify max-tokens`);
    this._maxTokenCount = n;
    return this;
}

// Convenience: replaces the message list with a single user message
OpenRouterRequest.prototype.addPrompt = function(prompt)
{
    return this.addMessage("user", prompt);
}

// Append a message (role: "user" | "assistant" | "system") to the request
OpenRouterRequest.prototype.addMessage = function(role, content)
{
    U.massert(!this.isFullQueryMode(), `This object is in full-query mode`);
    this._messages.push({"role": role, "content": content});
    return this;
}

// Bypass the model/maxTokens/messages builders and send a fully-composed query.
// Useful when the caller needs OpenRouter parameters this builder doesn't expose
// (e.g., temperature, tool calls, structured output).
OpenRouterRequest.prototype.setFullQuery = function(fullquery)
{
    U.massert(!this.isSimpleQueryMode(),
        `This request has been configured to run in simple-query mode by a call to setModelByCode(...), addPrompt(..) or similar`);

    U.massert(this._fullQuery == null, `You have already specified the query`);
    this._fullQuery = fullquery;
    return this;
}


OpenRouterRequest.prototype.isSimpleQueryMode = function()
{
    return this._messages.length > 0 || this._modelCode != null || this._maxTokenCount != null;
}

OpenRouterRequest.prototype.isFullQueryMode = function()
{
    return this._fullQuery != null;
}



// Set the log table for this request. Pass null to disable logging.
// The table is checked for valid structure, and an error is generated here to ensure it is compatible
OpenRouterRequest.prototype.setLogTableName = function(tablename)
{
    if(tablename != null)
    {
        const issue = OPENR.__checkLogTableIssue(tablename);
        U.massert(issue == null, `Problem with logging table: ${issue}`);
    }

    this._logTable = tablename;
    return this;
}


// Set the callback that will receive the result object when send() completes.
// Must be set before calling send().
OpenRouterRequest.prototype.setCallBack = function(callback)
{
    U.massert(this._myCallBack == null, `You already set the callback`);
    this._myCallBack = callback;
    return this;
}


// Compute the query object that will be sent. Useful for inspection/testing.
// In full mode, just returns the full query, otherwise builds the simple query
OpenRouterRequest.prototype.getOrBuildQuery = function()
{
    if (this._fullQuery != null) { return this._fullQuery; }

    U.massert(this._modelCode != null,
        "No model set. Call one of the setModelXxx methods or setModelByCode before send.");
    U.massert(this._messages.length > 0,
        "No messages. Call addPrompt or addMessage before send.");

    return {
        model      : this._modelCode,
        max_tokens : this._maxTokenCount || OPENR.DEFAULT_MAX_TOKENS,
        messages   : this._messages,
    };
}


OpenRouterRequest.prototype.__wrappedCb = function(result)
{
    if(this._logTable != null)
        { result.log_record_id = OPENR.__logResult(result, this._logTable); }

    this._myCallBack(result);
}


// Send the configured request. The previously-registered callback (setCallBack) receives the result.
// If logging was enabled, result.log_record_id is the new record id in OPENR.LOG_TABLE_NAME.
OpenRouterRequest.prototype.send = function()
{
    U.massert(this._myCallBack != null,
        "No callback set. Call setCallBack(...) before send().");

    if(this._logTable != null)
    { 
        const checkissue = OPENR.__checkLogTableIssue(this._logTable);
        U.massert(checkissue == null,
            `Log table ${this._logTable} has logging issue ${checkissue}. Call setLogTableName(null) to disable, or fix the schema.`);
    }


    const query = this.getOrBuildQuery();

    // Lots of weird stuff happening with JS object "this" binding
    OPENR.__sendQuery(query, result => this.__wrappedCb(result));
}
