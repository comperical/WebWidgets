
package io.webwidgets.core; 

import java.util.*;
import java.util.function.*;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.FileUtils;
import net.danburfoot.shared.TimeUtil.*;
import net.danburfoot.shared.CollUtil.*;
import net.danburfoot.shared.CoreDb.QueryCollector;

import io.webwidgets.core.CoreUtil.*;
import io.webwidgets.core.WidgetOrg.*;
import io.webwidgets.core.PluginCentral.*;


public class MailSystem {

    public static final String MAILBOX_WIDGET_NAME = "mailbox";

    public static final String MAILBOX_DB_TABLE = "outgoing";

    public static final int MINUTES_BETWEEN_SEND = 15;

    public static final int MAX_EMAIL_PER_USER_BLOCK = 5;
    
    public static final String WWIO_FOOTER_TAG = "WWIO_FOOTER_HERE";
    
    public static final String MAILBOX_CREATE_SQL = 
        "CREATE TABLE " + MAILBOX_DB_TABLE + " (id int, sent_at_utc varchar(19), send_target_utc varchar(19), recipient varchar(100), \n" + 
        " subject varchar(100), email_content varchar(1000), is_text smallint, primary key(id))";


    public static Optional<String> checkForEmailError(LiteTableInfo tableInfo, ArgMap argmap)
    {
        // It's not a mail box widget, skip it
        if(!tableInfo.dbTabPair._1.theName.equals(MAILBOX_WIDGET_NAME))
            { return Optional.empty(); }

        if(!tableInfo.dbTabPair._2.equals(MAILBOX_DB_TABLE))
            { return Optional.empty(); }

        String ajaxop = argmap.getStr("ajaxop");
        if(!ajaxop.equals("upsert"))
            { return Optional.empty(); }

        String recipient = argmap.getStr("recipient");
        if(!basicEmailFormatCheck(recipient))
            { return Optional.of("Invalid email addres: " + recipient); }

        String content = argmap.getStr("email_content");
        if(!content.contains(WWIO_FOOTER_TAG))
        { 
            return Optional.of("You must include the special footer tag " + WWIO_FOOTER_TAG + " in the content of your email");
        }

        ValidatedEmail valid = ValidatedEmail.from(recipient);

        // Skip the check for this user.
        // In the future, this should be some kind of global configuration setting.
        // Feb 2025: special WWIO-hosting specific email allowance goes in the plugin, not here
        boolean sendokay = PluginCentral.getMailPlugin().allowEmailSend(valid, tableInfo.dbTabPair._1.theOwner);
        if(!sendokay)
        {
            return Optional.of("This recipient has not elected to receive email from you. Please send a confirmation email " + recipient);
        }

        return Optional.empty();
    }

    public static String composeUnsubFooter(WidgetUser sender, ValidatedEmail email)
    {
        // Does this need to be the entire footer...?
        // If someone has setup their own open-core version, 
        // then they probably don't want it to be listed as from WebWidgets.io
        String controlpage = PluginCentral.getMailPlugin().getEmailControlUrl(email, sender);
        String s = String.format("<p>This message was sent from WebWidgets.IO on behalf of user %s. ", sender);
        s += String.format("To unsubscribe, click <a href=\"%s\">here</a>.</p>", controlpage);
        s += "<p>This email address is not monitored; please do not reply</p>";

        return s;

    }

    public static class WidgetMail
    {
        public final WidgetUser theOwner;

        public ValidatedEmail recipEmail;

        public String emailContent;

        public String emailSubject;

        public boolean isText = false;

        private WidgetMail(WidgetUser user) {
            theOwner = user;
        }

        public static WidgetMail build(WidgetUser user) {
            return new WidgetMail(user);
        }

        public static WidgetMail fromDbRecord(WidgetUser user, ArgMap dbrec)
        {
            return build(user)
                    .setContent(dbrec.getStr("email_content"))
                    .setSubject(dbrec.getStr("subject"))
                    .setRecipEmail(dbrec.getStr("recipient"))
                    .setIsText(dbrec.getBit("is_text"));
        }


        public WidgetMail setSubject(String subj) 
        {
            Util.massert(emailSubject == null, "Already have an email subject, this object is not reusable");
            emailSubject = subj;
            return this;
        }

        public WidgetMail setContent(String content)
        {
            Util.massert(emailContent == null,
                "The mail content was already sent, this object is not reusable");

            emailContent = content;
            return this;
        }

        public String getContentWithFooter()
        {
            String footer = composeUnsubFooter(theOwner, recipEmail);
            return emailContent.replaceAll(WWIO_FOOTER_TAG, footer);
        }

        public WidgetMail setIsText(boolean istext)
        {
            isText = istext;
            return this;
        }

        public WidgetMail setRecipEmail(String addr)
        {
            Util.massert(recipEmail == null, "Already set the recipient email");
            recipEmail = ValidatedEmail.from(addr);
            return this;
        }

        public String getFromName()
        {
            return String.format("%s's WebWidgets", theOwner);
        }

        public String getFromAddress()
        {
            return String.format("%s@webwidgets.io", theOwner);

        }

        public boolean checkSendOkay()
        {
            return PluginCentral.getMailPlugin().allowEmailSend(recipEmail, theOwner);
        }
    }

    public static String composeReadyMailQuery(Optional<Integer> limit)
    {
        String limcls = limit.isPresent() ? String.format(" LIMIT %d ", limit.get()) : "";
        String timenow = ExactMoment.build().asLongBasicTs(TimeZoneEnum.UTC);        
        return String.format("SELECT * FROM %s WHERE sent_at_utc = '' AND send_target_utc < '%s' ORDER BY send_target_utc %s ", 
                                    MAILBOX_DB_TABLE, timenow, limcls);
    }

    public static String composeReadyMailQuery()
    {
        return composeReadyMailQuery(Optional.of(1));
    }

    public static void markMailSentAt(Pair<WidgetUser, Integer> fullid)
    {
        markMailSentAt(fullid._1, fullid._2);
    }

    public static void markMailSentAt(WidgetUser user, int mailitemid)
    {
        WidgetItem mailbox = new WidgetItem(user, MAILBOX_WIDGET_NAME);
        String timenow = ExactMoment.build().asLongBasicTs(TimeZoneEnum.UTC);        

        CoreDb.upsertFromRecMap(mailbox, MAILBOX_DB_TABLE, 1, CoreDb.getRecMap(
            "id", mailitemid,
            "sent_at_utc", timenow
        ));
    }


    public static boolean userHasMailBox(WidgetUser user)
    {
        WidgetItem mailbox = new WidgetItem(user, MAILBOX_WIDGET_NAME);
        return mailbox.getLocalDbFile().exists();
    }

    public static Map<Integer, WidgetMail> loadReadyMailForUser(WidgetUser user)
    {
        return loadReadyMailForUser(user, Optional.empty());
    }


    public static Map<Integer, WidgetMail> loadReadyMailForUser(WidgetUser user, Optional<Integer> limit)
    {
        if(!userHasMailBox(user))
            { return Collections.emptyMap(); }

        WidgetItem mailbox = new WidgetItem(user, MAILBOX_WIDGET_NAME);
        QueryCollector qcol = QueryCollector.buildAndRun(composeReadyMailQuery(limit), mailbox);
        
        Map<Integer, WidgetMail> result = Util.linkedhashmap();
        for(ArgMap amap : qcol.recList()) 
            { result.put(amap.getInt("id"), WidgetMail.fromDbRecord(user, amap)); }
        return result;
    }

    public static List<ArgMap> directMailQuery(WidgetUser user, Optional<Integer> limit)
    {
        if(!userHasMailBox(user))
            { return Collections.emptyList(); }

        WidgetItem mailbox = new WidgetItem(user, MAILBOX_WIDGET_NAME);
        String limcls = limit.isPresent() ? " LIMIT " + limit.get() : " ";
        String query = String.format("SELECT * FROM %s ORDER BY id DESC %s ", MAILBOX_DB_TABLE, limcls);
        return QueryCollector.buildAndRun(query, mailbox).recList();
    }

    public static List<String> sendSingleReadyMailForUser(WidgetUser user)
    {
        TreeMap<Integer, WidgetMail> mymap = new TreeMap<>(loadReadyMailForUser(user, Optional.of(1)));
        if(mymap.isEmpty())
            { return Util.listify("No ready mail available for user " + user); }

        Util.massert(mymap.size() == 1, "Expected exactly one item here, otherwise the LIMIT statement isn't working properly");
        // MailerUtil<Integer> mailutil = new MailerUtil<Integer>(mid -> markMailSentAt(user, mid));
        IMailSender sender = PluginCentral.getMailPlugin();

        try {
            sender.sendMailPackage(mymap, mid -> markMailSentAt(user, mid));

            String mssg = String.format("Mail ID %d, subject %s sent successfully", 
                mymap.firstEntry().getKey(), mymap.firstEntry().getValue().emailSubject);
            return Arrays.asList(mssg);
        } catch (Exception ex) {
            ex.printStackTrace();
            return Arrays.asList("Mail attempt failed with message: " + ex.getMessage());
        }
    }

    public static boolean haveMailBox4User(WidgetUser wuser)
    {
        Set<String> existset = Util.map2set(WidgetItem.getUserWidgetList(wuser), witem -> witem.theName);
        return existset.contains(MAILBOX_WIDGET_NAME);

    }


    public static void createMailBox4User(WidgetUser wuser)
    {
        Util.massert(!haveMailBox4User(wuser), "Already have mailbox DB for this user");
        
        WidgetItem mailbox = WidgetItem.createBlankItem(wuser, "mailbox");

        CoreDb.execSqlUpdate(MAILBOX_CREATE_SQL, mailbox);

        mailbox.createJsCode();
    }


    // Very important, this needs to guard against SQL injection issues
    public static boolean basicEmailFormatCheck(String emailAddr)
    {
        boolean basic = emailAddr != null && emailAddr.toLowerCase().equals(emailAddr) && emailAddr.split("@").length == 2;

        if (!basic)
            { return false; }

        // Is this good prevention vs SQL injection...?
        return emailAddr.replaceAll(" ", "").equals(emailAddr);
    }

    public static class ValidatedEmail implements ProxyCompare<String>
    {

        public final String emailAddr;

        private ValidatedEmail(String em)
        {
            Util.massert(basicEmailFormatCheck(em), 
                "Bad email %s, You must check the basic format of the email before constructing", em);

            emailAddr = em;
        }

        public static ValidatedEmail from(String s)
        {
            return new ValidatedEmail(s);
        }

        public String toString()
        {
            return String.format("V:%s", emailAddr);
        }


        public String getProxy()
        {
            return emailAddr;
        }
    }
}
