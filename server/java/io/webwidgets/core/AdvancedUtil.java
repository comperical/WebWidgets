package io.webwidgets.core;

import java.io.*; 
import java.util.*;
import java.util.function.Consumer;


import net.danburfoot.shared.Util;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.CollUtil.Pair;



import io.webwidgets.core.WidgetOrg.*;
import io.webwidgets.core.CoreUtil.SystemPropEnum;
import io.webwidgets.core.MailSystem.ValidatedEmail;


// This is basically an extension of CoreUtil, but split off because it needs to refer to a few
// other packages. CoreUtil is the first code package that is compiled by the incremental compilation
public class AdvancedUtil
{ 
    // Probably need a pluging that provides extra reserved names
    public static List<String> RESERVED_WIDGET_NAMES = Arrays.asList(
        MailSystem.MAILBOX_WIDGET_NAME,
        CoreUtil.BASE_WIDGET_NAME
    );


    public static final File SHARED_CSS_ASSET_DIR = (new WidgetItem(WidgetUser.buildBackDoorSharedUser(), "css")).getWidgetBaseDir();
    public static final File SHARED_JSLIB_ASSET_DIR = (new WidgetItem(WidgetUser.buildBackDoorSharedUser(), "jslib")).getWidgetBaseDir();
    public static final File SHARED_IMAGE_ASSET_DIR = (new WidgetItem(WidgetUser.buildBackDoorSharedUser(), "image")).getWidgetBaseDir();
    public static final File SHARED_OPTJS_ASSET_DIR = (new WidgetItem(WidgetUser.buildBackDoorSharedUser(), "optjs")).getWidgetBaseDir();



    // If true, the server will allow insecure connections
    // This config is read only once at system startup
    // The file contents must be the string "true" in order to return true
    public static boolean allowInsecureConnection()
    {
        return GlobalIndex.getSystemSetting()
                                .getOrDefault(SystemPropEnum.INSECURE_ALLOW_MODE.toString(), "...")
                                .equals(true+"");
    }


    public static Optional<String> maintenanceModeInfo()
    {
        return Optional.ofNullable(GlobalIndex.getSystemSetting().get(SystemPropEnum.MAINTENANCE_MODE.toString()));
    }


    // Must be public to be accessed from JSP
    // Check that the old password matches, and then update it
    public static void updateAccessHash(WidgetUser user, Pair<String, String> oldnew)
    {
        // This should be checked elsewhere
        // This is one final check before doing the update
        Util.massert(oldnew._1.equals(user.getAccessHash()),
            "Old password does not match");
        
        hardPasswordUpdate(user, oldnew._2);
    }

    // This is accessed from the admin JSP pages
    public static void hardPasswordUpdate(WidgetUser user, String newhash)
    {
        Util.massert(newhash.length() == 64, 
            "Expected hash to be length 64, got %d, this is the HASH not the password itself!", newhash.length());

        Integer masterid = user.getMasterId();
        Util.massert(masterid != null, 
            "User entry is missing an ID, please contact administrator");
        
        CoreDb.upsertFromRecMap(WidgetItem.getMasterWidget(), "user_main", 1, CoreDb.getRecMap(
            "id", masterid,
            CoreUtil.ACCESS_HASH_COOKIE, newhash
        ));
        
        // Note: this is a bit hacky; reloading the entire user index just because one user changed password
        // However, reloading the indexes is relatively fast. 
        // This should be fine until we get to a user count where people are changing passwords every minute or so
        GlobalIndex.clearUserIndexes();
    }


    public static void addEmailAddress(WidgetUser user, ValidatedEmail email)
    {
        updateEmailSet(user, emset -> emset.add(email.emailAddr));
    }

    public static void removeEmailAddress(WidgetUser user, ValidatedEmail email)
    {
        updateEmailSet(user, emset -> emset.remove(email.emailAddr));
    }

    private static void updateEmailSet(WidgetUser user, Consumer<Set<String>> updater)
    {
        Integer masterid = user.getMasterId();
        Util.massert(masterid != null, 
            "User entry is missing an ID, please contact administrator");


        var emailset = user.getEmailSet();
        Util.pf("Email set is %s\n", emailset);
        updater.accept(emailset);
        Util.pf("Email set is now %s\n", emailset);

        
        CoreDb.upsertFromRecMap(WidgetItem.getMasterWidget(), "user_main", 1, CoreDb.getRecMap(
            "id", masterid,
            "email", emailSet2Str(emailset)
        ));
        
        // See note about hackiness above
        GlobalIndex.clearUserIndexes();
    }

    private static String emailSet2Str(Set<String> emailset)
    {
        return Util.join(emailset, ",").toLowerCase();
    }


    // Delete the given records with the ID set from the underlying DB
    // Use the standard ID column name
    // This operation uses edit control if it is run from the same JVM
    public static int genericDeleteItemSet(WidgetItem db, String tablename, Collection<Integer> idset)
    {
        return genericDeleteItemSet(db, tablename, idset, true);
    }

    public static int genericDeleteItem(WidgetItem db, String tablename, int id)
    {
        // If we're just deleting a single item, don't bother to check names, we'll just get a SQLite error instead
        return genericDeleteItemSet(db, tablename, Util.listify(id), false);
    }

    private static int genericDeleteItemSet(WidgetItem db, String tablename, Collection<Integer> idset, boolean checkname)
    {
        if(checkname)
        {
            Util.massert(CoreDb.getLiteTableNameSet(db).contains(tablename),
                "Attempt to delete items from DB %s, but table %s does not exist", db, tablename);
        }

        LinkedHashMap<String, Object> colmap = Util.linkedhashmap();

        for(Integer id : idset)
            { colmap.put(CoreUtil.STANDARD_ID_COLUMN_NAME, id); }

        var editcontrol = LiteTableInfo.getEditController(db);

        synchronized(editcontrol)
        {
            return CoreDb.deleteFromColMap(db, tablename, colmap);
        }
    }
}
