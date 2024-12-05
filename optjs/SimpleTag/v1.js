

// Simple approach to handling tags
// Tags are compiled into a simple string via basic string join operation

TAG = {

    TAG_SEPARATOR : ";;;",

    // If you are not using this name for the tag column, you must set this field in your code before using this library
    // TAG.TAG_FIELD_NAME = YOUR_TAG_NAME;
    TAG_FIELD_NAME : "tag_set",

    getCompleteTagSet : function(itemlist)
    {
        const tagset = new Set([]);

        itemlist.forEach(function(item) {
            const tagstr = item.getField(TAG.TAG_FIELD_NAME);
            tagstr.split(TAG_SEPARATOR).filter(tkn => tkn.trim().length > 0).forEach(tag => tagset.add(tag));
        });

        return tagset;
    },

    setItemTagSet : function(item, tagset)
    {
        const tagstr = [... tagset].join(TAG.TAG_SEPARATOR);
        item.setField(TAG.TAG_FIELD_NAME, tagstr);
    },

    addNewTag2Item : function(item, newtag)
    {
        const tagset = TAG.getItemTagSet(item);
        tagset.add(newtag);
        TAG.setItemTagSet(item, tagset);
    },


    promptAddTag2Item : function(tablename, itemid)
    {
        massert(W.haveItem(tablename, itemid), `No item found for ${tablename}::${itemid}`);
        const item = W.lookupItem(tablename, itemid);

        const novtag = prompt("Please enter a new tag:");

        if(novtag)
        {
            TAG.addNewTag2Item(item, novtag);
            item.syncItem();
            redisplay();
        }
    },

    getItemTagSet : function(item)
    {
        const tagstr = item.getField(TAG.TAG_FIELD_NAME);
        const tags = tagstr.split(TAG_SEPARATOR).filter(tkn => tkn.trim().length > 0);
        return new Set(tags);
    },

    removeTagFromItem : function(item, killtag)
    {
        const prevtags = TAG.getItemTagSet(item);
        prevtags.delete(killtag);
        TAG.setItemTagSet(item, prevtags);
    },

    // Get the tag set and join it using the given delimeter, something like " / "
    getTagSetDisplay : function(item, delim)
    {
        const tagset = TAG.getItemTagSet(item);
        return [... tagset].join(delim);
    }

};

