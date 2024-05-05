

BULK = {
    getDataIngester : function() {
        return new BulkDataIngester();
    }

};

function BulkDataIngester() {

    this.parsedInputData = null;

    // Map field names of input to field names of output
    this.fieldFunction = null;

    // Ignore input fields
    this.ignoreInputSet = new Set();

    // The target Widget table that we are sending data to
    this.targetTable = null;

    // User-supplied FULL record remap function. This overrides fieldFunction and other related fields.
    // Error to supply this at the same time as other inputs.
    this.fullRecordRemap = null;

    // filter to apply to outputs of the transformation function
    this.allowOutputFilter = () => true;
}


BulkDataIngester.prototype.withFieldMap = function(fieldmap)
{
    massert(fieldmap != null && fieldmap instanceof Map, `Expected field map argument to be a JavaScript Map object`);
    return withFieldFunction(x => fieldmap.get(x));
}

BulkDataIngester.prototype.withFieldHash = function(fieldhash)
{
    massert(fieldhash != null && typeof(fieldhash) == 'object', `Expected field hash to be a regular JS hash`);
    return withFieldFunction(x => fieldhash[x]);
}



BulkDataIngester.prototype.withFieldFunction = function(fieldfunc)
{
    massert(fieldfunc != null && typeof(fieldfunc) == 'function', `Expected field function argument to be a function`);
    massert(fullRecordRemap == null, `Full Record Remap function is already set; you cannot use both the fullRecordRemap and field function arguments`);
    this.fieldFunction = fieldfunc;
    return this;

}


BulkDataIngester.prototype.withFullRecordRemap = function(remapper)
{
    massert(remapper != null && typeof(remapper) == 'function', `Expected full remap argument to be a function`);
    massert(this.fieldFunction == null, `Field function is already set; you cannot use both the fullRecordRemap and field function arguments`);


    this.fullRecordRemap = remapper;
    return this;
}


BulkDataIngester.prototype.withInputData = function(inputdata)
{
    massert(inputdata.length > 0, `Input data has 0-length. Caller must check for this condition`);
    this.parsedInputData = inputdata;
    return this;
}

BulkDataIngester.prototype.withSkipNullOutput = function()
{
    return this.withOutputFilter(x => x != null);
}


BulkDataIngester.prototype.withOutputFilter = function(allower)
{
    massert(allower != null && typeof(allower) == 'function', `Expected allow-output argument to be a function`);
    this.allowOutputFilter = allower;
    return this;
}

BulkDataIngester.prototype.withTargetTable = function(tablename)
{
    massert(tablename != null && typeof(tablename) == 'string', `Expected table name to be a string`);
    massert(W.haveTable(tablename), `Unknown widget table name ${tablename}`)
    this.targetTable = tablename;
    return this;
}


BulkDataIngester.prototype.transformDatum = function(datum)
{
    if(this.fullRecordRemap != null)
        { return this.fullRecordRemap(datum); }

    const result = {};

    Object.keys(datum).forEach(function(k) {
        if(this.ignoreInputSet.has(k))
            { return; }

        const newkey = this.fieldFunction(k);
        massert(newkey != null, `Field function returned null for field input ${k}, use ignoreInputList(...) if you want to skip fields`);
        result[newkey] = datum[k];
    });

    return result;
}



BulkDataIngester.prototype.getRecordList = function()
{
    massert(this.fieldFunction != null || this.fullRecordRemap != null, 
        `You must set either the field function or the full record remap before calling. Use withEmptyFieldFunc for identity map`);
    massert(this.parsedInputData != null, `You must set the input data before calling this method`);


    // Lots of efforts here to get this to work as a collection operation.
    // The problem is that when you run a closure, the _this_ keyword no longer refers ot the BDI object!
    // Instead it refers to the locale scope of the closure, arrghh!!
    const rlist = [];
    for(let idx = 0; idx < this.parsedInputData.length; idx++)
    {
        const input = this.parsedInputData[idx];
        const output = this.transformDatum(input);

        if(!this.allowOutputFilter(output))
            { continue; }

        massert(output != null, 
            `Transformation function returned null for input ${input} and this was not skipped. If you want to skip nulls, call with withSkipNullOutput`);
        
        rlist.push(output);
    }

    return rlist;
}


BulkDataIngester.prototype.runBulkUpdate = function(cbfunc)
{
    massert(cbfunc == null || typeof(cbfunc) == 'function', `Callback argument should be null or a function, found ${cbfunc}`);

    const cb = function(tablename, idlist, _)
    {
        if(cbfunc != null)
        {
            cbfunc(tablename, idlist, _);
            return;
        }

        alert(`Updated ${idlist.length} records for table name ${tablename} successfully, reloading page`);
        window.location.reload();
    }


    const idlist = [];
    const ttable = this.targetTable;

    this.getRecordList().forEach(function(r) {
        const item = W.buildItem(ttable, r);
        idlist.push(item.getId());
    });

    W.bulkUpdate(this.targetTable, idlist, { callback : cb });
}



