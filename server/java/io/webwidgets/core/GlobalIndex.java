package io.webwidgets.core; 


import java.io.*; 
import java.util.*; 
import java.sql.*; 
import java.nio.file.*;

import java.time.LocalDate;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.CoreDb.QueryCollector;

import io.webwidgets.core.WidgetOrg.*;


public class GlobalIndex
{
    private static long _REFRESH_TIMESTAMP = -1L;

    // This is the contents of the MASTER user DB table
    private static Map<String, ArgMap> _MASTER_DATA;
    
    // Map of String names to WidgetUser objects
    // These are immutable and unique, you never get a WidgetUser object any way
    // Other than lookup from this map
    private static Map<String, WidgetUser> _LOOKUP_MAP;

    
    static synchronized Map<String, ArgMap> getMasterData()
    {
        onDemandLoadIndexes();
        return _MASTER_DATA;
    }

    static synchronized Map<String, WidgetUser> getUserLookup()
    {
        onDemandLoadIndexes();
        return _LOOKUP_MAP;
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
    }

    private static synchronized void onDemandLoadIndexes()
    {
        Util.massert((_MASTER_DATA == null) == (_LOOKUP_MAP == null), "Somehow MAster data and Lookup Map out of sync!!");

        if(_MASTER_DATA == null)
        {
            WidgetItem loadmaster = getLoadOnlyMaster();
            QueryCollector qcol = QueryCollector.buildAndRun("SELECT * FROM user_main", loadmaster);
            _MASTER_DATA = Util.map2map(qcol.recList(), amap -> amap.getStr("username"), amap -> amap);
            
            // This is the only place where we call new WidgetUser()!!!!
            _LOOKUP_MAP = Util.map2map(_MASTER_DATA.keySet(), uname -> uname, uname -> new WidgetUser(uname));

            _REFRESH_TIMESTAMP = System.currentTimeMillis();

            Util.massert(!_LOOKUP_MAP.isEmpty(), "There must be at least 1 user to run this code");
        }
    }

    // This is a special "back-door" that is used only to load the indexes
    // The gotcha is that LifeUtil.getMasterWidget requires a reference to WidgetUser.dburfoot
    // But WidgetUser objects are generally only created by the GlobalIndex code
    private static WidgetItem getLoadOnlyMaster()
    { 
        WidgetUser admin = new WidgetUser(WidgetUser.DBURFOOT_USER_NAME);
        return new WidgetItem(admin, LifeUtil.MASTER_WIDGET_NAME);
    }
}