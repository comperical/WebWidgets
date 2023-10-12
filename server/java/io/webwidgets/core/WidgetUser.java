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


import io.webwidgets.core.WidgetOrg.*;


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
        return Optional.ofNullable(GlobalIndex.getUserLookup().get(s));
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
    
    public List<WidgetItem> getUserWidgetList()
    {
        File dbdir = new File(getDbDirPath());
        List<File> flist = Util.listify(dbdir.listFiles());

        List<WidgetItem> result = Util.vector();
        for(File f : flist)
        {
            String fn = f.getName();
            int suffix = fn.indexOf("_DB.sqlite");
            Util.massert(suffix != -1,
                "Bad file in database dir: %s", fn);
            
            String wname = fn.substring(0, suffix);
            Util.massert(wname.toUpperCase().equals(wname),
                "Widget DB names should be uppercase, got %s", wname);
            
            WidgetItem witem = new WidgetItem(this, wname.toLowerCase());
            result.add(witem);
        }
        
        return result;
        
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
    
    public String getEmail()
    {
        ArgMap entry = getUserEntry();
        return entry == null ? null : entry.getStr("email");    
    }
    
    public String getAccessHash()
    {
        ArgMap entry = getUserEntry();
        return entry == null ? null : entry.getStr(AuthLogic.ACCESS_HASH_COOKIE);
        
    }

    private Integer getMasterId()
    {
        ArgMap entry = getUserEntry();
        return entry == null ? null : entry.getInt("id");
    }

    public WidgetItem baseWidget()
    {
        return new WidgetItem(this, "base", true);        
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

    // Must be public to be accessed from JSP
    public void updateAccessHash(Pair<String, String> oldnew)
    {
        // This should be checked elsewhere
        // This is one final check before doing the update
        Util.massert(oldnew._1.equals(getAccessHash()),
            "Old password does not match");
        
        hardPasswordUpdate(oldnew._2);
    }

    // This is accessed from the admin JSP pages
    public void hardPasswordUpdate(String newhash)
    {
        Util.massert(newhash.length() == 64, 
            "Expected hash to be length 64, got %d, this is the HASH not the password itself!", newhash.length());

        Integer masterid = getMasterId();
        Util.massert(masterid != null, 
            "User entry is missing an ID, please contact administrator");
        
        CoreDb.upsertFromRecMap(CoreUtil.getMasterWidget(), "user_main", 1, CoreDb.getRecMap(
            "id", masterid,
            AuthLogic.ACCESS_HASH_COOKIE, newhash
        ));
        
        // TODO: Okay, this is a real hack, you need to reload entire user index
        // after updating a single user...???
        GlobalIndex.clearUserIndexes();
    }

    public WidgetItem createBlankItem(String newname)
    {
        WidgetItem witem = new WidgetItem(this, newname);
        witem.createEmptyLocalDb();
        witem.createLocalDataFile();            
        return witem;
    }
    
    public void checkAndDelete(String widget, String wreverse)
    {
        {
            String checkit = new StringBuilder(widget).reverse().toString();
            Util.massert(wreverse.equals(checkit),
                "You must enter the widget name REVERSED, got %s", wreverse);
        }
        
        Set<String> curset = Util.map2set(getUserWidgetList(), witem -> witem.theName);
        Util.massert(curset.contains(widget),
            "Unknown widget %s, options are %s", widget, curset);
        
        WidgetItem victim = new WidgetItem(this, widget);           
        File dbfile = victim.getLocalDbFile();
        if(dbfile.exists())
        { 
            dbfile.delete();    
            Util.pf("Deleted DB file %s\n", dbfile);
        }   
        
        File localdir = victim.getWidgetBaseDir();
        try 
            { FileUtils.recursiveDeleteFile(localdir); }
        catch (IOException ioex) 
            { throw new RuntimeException(ioex); }
            
        Util.pf("Deleted local dir %s\n", localdir);
    }
    
    public WidgetItem importFromTemplate(String widgetname) 
    {
        WidgetItem dstitem = new WidgetItem(this, widgetname);          
        WidgetItem srcitem = new WidgetItem(WidgetUser.lookup("rando"), widgetname);
        
        Util.massert(srcitem.getLocalDbFile().exists(),
            "Could not find the template DB for widget name %s", widgetname);
        
        Util.massert(!dstitem.getLocalDbFile().exists(),
            "Already have a Database for widget %s", dstitem);
        
        // Okay, create a List of files from the template widget.
        
        List<File> srclist = Util.vector();
        add2FileList(srclist, srcitem.getWidgetBaseDir());
        CollUtil.sortListByFunction(srclist, f -> f.getAbsolutePath().length());
        
        for(File srcfile : srclist)
        {
            File dstfile = new File(srcfile.getAbsolutePath().replaceAll(
                            srcitem.getWidgetBaseDir().getAbsolutePath(),
                            dstitem.getWidgetBaseDir().getAbsolutePath()));
            
            if(srcfile.isDirectory())
            {
                dstfile.mkdir();    
                continue;
            }
            
            try { 
                Files.copy(srcfile.toPath(), dstfile.toPath(), StandardCopyOption.REPLACE_EXISTING); 
                Util.pf("Copied to/from: \n\t%s\n\t%s\n", srcfile, dstfile);
            } catch (IOException ioex) {
                throw new RuntimeException(ioex); 
            }
        }
        
        try { 
            File srcfile = srcitem.getLocalDbFile();
            File dstfile = dstitem.getLocalDbFile();
            
            Files.copy(srcfile.toPath(), dstfile.toPath(), StandardCopyOption.REPLACE_EXISTING); 
            Util.pf("Copied to/from: \n\t%s\n\t%s\n", srcfile, dstfile);
        } catch (IOException ioex) {
            throw new RuntimeException(ioex); 
        }           
        
        // Create the JS code
        List<String> loglist = ActionJackson.createCode4Widget(dstitem);                
        for(String log : loglist)
            { Util.pf("%s", log); }         
        
        return dstitem;
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