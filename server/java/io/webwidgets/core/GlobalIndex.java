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
                _LOOKUP_MAP = Util.map2map(_MASTER_DATA.keySet(), uname -> uname, uname -> new WidgetUser(uname));
                Util.massert(!_LOOKUP_MAP.isEmpty(), "There must be at least 1 user to run this code");
            }

            {
                QueryCollector qcol = CoreUtil.fullTableQuery(loadmaster, MasterTable.system_setting.toString());
                _SYSTEM_SETTING = Util.map2map(qcol.recList(), amap -> amap.getStr("key_str"), amap -> amap.getStr("val_str"));
            }

            _REFRESH_TIMESTAMP = System.currentTimeMillis();
        }
    }

    // This is a special "back-door" that is used only to load the indexes
    // The gotcha is that CoreUtil.getMasterWidget requires a reference to WidgetUser.shared
    // But WidgetUser objects are generally only created by the GlobalIndex code
    private static WidgetItem getLoadOnlyMaster()
    { 
        // TODO: this can used the back-door shared user method
        WidgetUser admin = new WidgetUser(WidgetUser.SHARED_USER_NAME);
        return new WidgetItem(admin, CoreUtil.MASTER_WIDGET_NAME);
    }

    public static void updateSystemSetting(Enum setting, Optional<String> optval)
    {
        updateSystemSetting(setting.toString(), optval);

    }

    static void updateSystemSetting(String setting, Optional<String> optval)
    {

        if(!optval.isPresent())
        {
            CoreDb.deleteFromColMap(CoreUtil.getMasterWidget(), MasterTable.system_setting.toString(), CoreDb.getRecMap(
                "key_str", setting
            ));

            return;
        }

        CoreDb.upsertFromRecMap(CoreUtil.getMasterWidget(), MasterTable.system_setting.toString(), 1, CoreDb.getRecMap(
            "key_str", setting, 
            "val_str", optval.get()
        ));


    }


}