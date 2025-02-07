package io.webwidgets.core; 


import java.io.*; 
import java.util.*; 
import java.sql.*; 
import java.nio.file.*;

import java.time.LocalDate;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.ArgMap;

import net.danburfoot.shared.CoreDb.QueryCollector;

import io.webwidgets.core.WidgetOrg.*;
import io.webwidgets.core.CoreUtil.MasterTable;
import io.webwidgets.core.CoreUtil.SystemPropEnum;
import io.webwidgets.core.AuthLogic.PermInfoPack;

public class GlobalIndex
{
    private static long _REFRESH_TIMESTAMP = -1L;

    // This is the contents of the MASTER user DB table
    private static Map<String, ArgMap> _MASTER_DATA;
    
    // Map of String names to WidgetUser objects
    // These are immutable and unique, you never get a WidgetUser object any way
    // Other than lookup from this map
    private static Map<String, WidgetUser> _LOOKUP_MAP;

    // System settings
    private static Map<String, String> _SYSTEM_SETTING;

    private static Map<WidgetItem, PermInfoPack> _PERMISSION_MAP;

    static synchronized Map<String, ArgMap> getMasterData()
    {
        onDemandLoadIndexes();
        return Collections.unmodifiableMap(_MASTER_DATA);
    }

    static synchronized Map<String, WidgetUser> getUserLookup()
    {
        onDemandLoadIndexes();
        return Collections.unmodifiableMap(_LOOKUP_MAP);
    }
    
    public static Optional<String> getSystemSetting(SystemPropEnum spenum)
    {
        return Optional.ofNullable(getSystemSetting().get(spenum.toString()));
    }

    public static synchronized Map<String, String> getSystemSetting()
    {
        onDemandLoadIndexes();
        return Collections.unmodifiableMap(_SYSTEM_SETTING);
    } 

    public static int getMasterSize()
    {
        return getMasterData().size();
    }
    
    public static long getMasterRefreshTime()
    {
        return _REFRESH_TIMESTAMP;
    }
    
    // Need to open this up so we can reset from the WebApp
    public static synchronized void clearUserIndexes()
    {
        _MASTER_DATA = null;
            
        _LOOKUP_MAP = null;

        _SYSTEM_SETTING = null;

        _PERMISSION_MAP = null;

        PluginCentral.clearIndex();
    }

    private static synchronized void onDemandLoadIndexes()
    {
        Util.massert((_MASTER_DATA == null) == (_LOOKUP_MAP == null), "Somehow MAster data and Lookup Map out of sync!!");

        if(_MASTER_DATA == null)
        {
            WidgetItem loadmaster = getLoadOnlyMaster();
            {
                QueryCollector qcol = CoreUtil.fullTableQuery(loadmaster, MasterTable.user_main.toString());
                _MASTER_DATA = Util.map2map(qcol.recList(), amap -> amap.getStr("username"), amap -> amap);
                
                // This is the only place where we call new WidgetUser()!!!!
                _LOOKUP_MAP = Util.map2map(_MASTER_DATA.keySet(), uname -> uname, WidgetUser::__globalIndexBuildOnly);
                Util.massert(!_LOOKUP_MAP.isEmpty(), "There must be at least 1 user to run this code");
            }

            {
                QueryCollector qcol = CoreUtil.fullTableQuery(loadmaster, MasterTable.system_setting.toString());
                _SYSTEM_SETTING = Util.map2map(qcol.recList(), amap -> amap.getStr("key_str"), amap -> amap.getStr("val_str"));
            }


            // Be careful, this has to be loaded AFTER the user info
            {
                _PERMISSION_MAP = Util.treemap();

                QueryCollector qcol = CoreUtil.fullTableQuery(WidgetItem.getMasterWidget(), AuthLogic.PERM_GRANT_TABLE);

                for(ArgMap onemap : qcol.recList())
                {
                    // This should be prevented by a config test or a FKEY constraint
                    // But if it happens here, don't blow up the whole loading process
                    Optional<WidgetUser> optown = WidgetUser.softLookup(onemap.getStr("owner"));
                    if(!optown.isPresent())
                        { continue; }


                    String widgetname = onemap.getStr("widget_name");
                    WidgetItem dbitem = new WidgetItem(optown.get(), widgetname);

                    _PERMISSION_MAP.putIfAbsent(dbitem, new PermInfoPack());
                    _PERMISSION_MAP.get(dbitem).loadFromRecMap(onemap);
                }
            }

            _REFRESH_TIMESTAMP = System.currentTimeMillis();
        }
    }

    // This is a special "back-door" that is used only to load the indexes
    // The gotcha is that WidgetItem.getMasterWidget requires a reference to WidgetUser.shared
    // But WidgetUser objects are generally only created by the GlobalIndex code
    private static WidgetItem getLoadOnlyMaster()
    { 
        WidgetUser admin = WidgetUser.buildBackDoorSharedUser();
        return new WidgetItem(admin, CoreUtil.MASTER_WIDGET_NAME);
    }

    public static void updateSystemSetting(Enum setting, Optional<String> optval)
    {
        updateSystemSetting(setting.toString(), optval);
    }

    static void updateSystemSetting(String setting, Optional<String> optval)
    {
        // Sept 2024 bug fix: this table has an integer id PKey, like all the others in the system
        // But code was previously treating it like the key_str was the PK

        WidgetItem master = WidgetItem.getMasterWidget();
        var tabname = MasterTable.system_setting.toString();


        // Always delete the old key
        CoreDb.deleteFromColMap(master, tabname, CoreDb.getRecMap(
            "key_str", setting
        ));


        // If value is present, re-insert the record
        if(optval.isPresent())
        {
            int newid = CoreUtil.getNewDbId(master, tabname);

            CoreDb.upsertFromRecMap(master, tabname, 1, CoreDb.getRecMap(
                "id", newid,
                "key_str", setting,
                "val_str", optval.get()
            ));
        }

        // TODO: why is this called "user" indexes?
        GlobalIndex.clearUserIndexes();
    }


    // After some back-and-forth, I opted for a very simple lookup here:
    // simple get with an empty value if the key is not present
    // There is a lot of potential for confusion if you get an empty record, then udpate it, but the
    // but the changes are saved in the DB, not the actual entry
    public static synchronized PermInfoPack getPermInfo4Widget(WidgetItem dbitem)
    {
        onDemandLoadIndexes();

        return _PERMISSION_MAP.getOrDefault(dbitem, new PermInfoPack());
    }


    // Users 
    public static Set<WidgetUser> getCodeFormatExemptSet()
    {
        return getCodeFormatExemptSet(false);
    }

    public static Set<WidgetUser> getCodeFormatExemptSet(boolean strict)
    {
        String exemptlist = GlobalIndex.getSystemSetting(SystemPropEnum.CODE_FORMAT_EXEMPT_LIST).orElse("").trim();
        if(exemptlist.isEmpty())
            { return Collections.emptySet(); }


        Set<WidgetUser> result = Util.treeset();
        for(String token : exemptlist.split(","))
        {
            Optional<WidgetUser> optuser = WidgetUser.softLookup(token);
            if(optuser.isPresent())
            {
                result.add(optuser.get());
                continue;
            }

            Util.massert(!strict, "Failed to find user in strict mode for token %s", token);
        }

        return result;
    }

}