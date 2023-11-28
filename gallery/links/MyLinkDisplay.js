function getLinkDisplay(link) {

    if(link.indexOf("youtube") > -1 && link.indexOf("watch") > -1) {
        return "YouTube";
    }

    if(link.indexOf("viki.com/tv") > -1) {
        return "Viki TV";
    }

    if(link.indexOf("chat.openai") > -1) {
        return "GPT Chat";
    }



    if(link.indexOf("docs.google.com") > -1) {

        if(link.indexOf("spreadsheet") > -1)
            { return "Google Sheet"; }


        if(link.indexOf("document") > -1)
            { return "Google Doc"; }
    }

    if(link.indexOf("drive.google.com") > -1) {

        return "Google Drive";
    }

    if(link.indexOf("crunchyroll.com") > -1) {

        return "CrunchyRoll";
    }    

    if(link.indexOf("linkedin.com") > -1) {

        if(link.indexOf("jira") > -1) 
            { return "LNKD Jira"; }

        if(link.indexOf("ingraphs") > -1) 
            { return "LNKD InGraph"; }

        if(link.indexOf("wiki") > -1) 
            { return "LNKD Wiki"; }
    }


    return link;
}
