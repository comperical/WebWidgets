package io.webwidgets.core; 


import java.io.*; 
import java.util.*; 
import java.sql.*; 
import java.nio.file.*;

import java.time.LocalDate;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.CollUtil;
import net.danburfoot.shared.FileUtils;
import net.danburfoot.shared.CollUtil.*;
import net.danburfoot.shared.CoreDb.QueryCollector;


import io.webwidgets.core.WidgetOrg.*;
import io.webwidgets.core.MailSystem.*;

// SRCORDER::2

public class WidgetUser implements Comparable<WidgetUser>
{
    private final String _userName;

    WidgetUser(String uname)
    {
        _userName = uname;
    }

    public static WidgetUser valueOf(String s)
    {
        return lookup(s);
    }

    public static Optional<WidgetUser> softLookup(String s)
    {
        return Optional.ofNullable(lookup(s));
    }

    public static WidgetUser lookup(String s)
    {
        return GlobalIndex.getUserLookup().get(s);
    }

    public int compareTo(WidgetUser other) 
    {
        return _userName.compareTo(other._userName);
    }

    public static Collection<WidgetUser> values() 
    {
        return GlobalIndex.getUserLookup().values();
    }

    public boolean isAdmin()
    {
        return getUserEntry().getInt("is_admin") == 1;
    }

    public String getDbDirPath()
    {
        return String.format("%s/%s", CoreUtil.WIDGET_DB_DIR, toString());
    }

    public File getDbDir()
    {
        return new File(getDbDirPath());
    }
    
    public boolean haveLocalDb()
    {
        File dbdir = new File(getDbDirPath());
        
        if(!dbdir.exists())
            { return false; }
        
        List<File> flist = Util.listify(dbdir.listFiles());
        return Util.countPred(flist, f -> f.getName().endsWith(".sqlite")) > 0;
    }

    public String toString()
    {
        return _userName;
    }

    public String getUserName()
    {
        return _userName;
    }
    
    public Set<String> getEmailSet()
    {
        ArgMap entry = getUserEntry();
        if(entry == null)
            { return Collections.emptySet(); }

        String emailstr = entry.getStr("email").trim().toLowerCase();
        return Util.listify(emailstr.split(","))
                        .stream()
                        .map(s -> s.trim())
                        .filter(s -> s.length() > 0)
                        .collect(CollUtil.toSet());
    }
    
    public String getAccessHash()
    {
        ArgMap entry = getUserEntry();
        return entry == null ? null : entry.getStr(CoreUtil.ACCESS_HASH_COOKIE);
        
    }


    // Get the group memberships for this user when accessing the given widget target
    // The groups are contained in the target DB owner's "config::group_info" table
    // We will likely need to have a caching system here
    // See docs for granular permissions
    public Set<String> lookupGroupSet4Db(WidgetItem accesstarget)
    {
        return lookupGroupSet4OwnerSpace(accesstarget.theOwner);
    }

    public Set<String> lookupGroupSet4OwnerSpace(WidgetUser owner)
    {
        var configdb = new WidgetItem(owner, CoreUtil.CONFIG_DB_NAME);

        // users are always members of their own group
        Set<String> groupset = Util.setify(String.format("I::%s", this.toString()));

        if(configdb.dbFileExists())
        {
            String paramquery = String.format("SELECT group_name FROM %s WHERE user_name = ?", GranularPerm.GROUP_INFO_TABLE);
            QueryCollector qcol = QueryCollector.buildRunPrepared(paramquery, configdb, this);
            groupset.addAll(Util.map2list(qcol.recList(), amap -> amap.getSingleStr()));
        }

        return groupset;
    }


    Integer getMasterId()
    {
        ArgMap entry = getUserEntry();
        return entry == null ? null : entry.getInt("id");
    }

        
    public boolean matchPassHash(String hashed)
    {
        Util.massert(hashed.toLowerCase().equals(hashed),
            "You must lowercase the hash string first");

        if(getAccessHash().equals(getDummyHash()))
            { return false; }
        
        return hashed.equals(getAccessHash());
    }

    public File getAutoGenJsDir()
    {
        String bdir = Util.sprintf("%s/autogenjs", getUserBaseDir().getAbsolutePath());
        return new File(bdir);
    }

    // Creates autogen dir for user if necessary.
    boolean maybeCreateAutogenJsDir()
    {
        File autodir = getAutoGenJsDir();
        if(autodir.exists())
            { return false;} 
        
        autodir.mkdirs();
        return true;
    }
            
    public File getUserBaseDir()
    {
        // TODO: make this OS-friendly
        String basedir = Util.sprintf("%s/%s", CoreUtil.getWidgetCodeDir(), toString());
        return new File(basedir);
    }

    private ArgMap getUserEntry()
    {
        return GlobalIndex.getMasterData().get(this.toString());
    }

    boolean haveUserEntry()
    {
        return getUserEntry() != null;
    }

    public Map<String, String> getUserEntryMap()
    {
        return Collections.unmodifiableMap(getUserEntry());
    }

    public Map<String, Long> getFileNameCheckMap()
    {
        Map<String, Long> ckmap = Util.treemap();
        recPopNameCheckMap(this.getUserBaseDir(), ckmap);
        return ckmap;
    }

    private  void recPopNameCheckMap(File target, Map<String, Long> ckmap)
    {
        if(target.isFile())
        {
            long cksum = CoreUtil.getFileCkSum(target);
            Util.putNoDup(ckmap, target.getAbsolutePath(), cksum);
            return;
        }

        Util.massert(target.isDirectory());

        for(File kid : target.listFiles())
            { recPopNameCheckMap(kid, ckmap); }
    }


    private static void add2FileList(List<File> addlist, File thedir)
    {
        Util.massert(thedir.exists() && thedir.isDirectory(), 
            "Problem with directory %s", thedir);
        
        addlist.add(thedir);
        
        for(File kid : thedir.listFiles())
        {   
            if(!kid.isDirectory())
            {
                addlist.add(kid);
                continue;
            }
            
            add2FileList(addlist, kid);
        }
    }

    public static String SHARED_USER_NAME = "shared";
    
    static WidgetUser buildBackDoorSharedUser()
    {
    	return new WidgetUser(SHARED_USER_NAME);
    }
    
    public static WidgetUser getSharedUser()
    {
        return valueOf(SHARED_USER_NAME);
    }

    private static String __DUMMY_HASH = null;

    static synchronized String getDummyHash()
    {
        if(__DUMMY_HASH == null)
            { __DUMMY_HASH = AuthLogic.canonicalHash(CoreUtil.DUMMY_PASSWORD); }

        return __DUMMY_HASH;
    }    
}