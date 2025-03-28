package io.webwidgets.core; 

import java.io.*;
import java.util.*;
import java.util.function.*;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.FileUtils;

import io.webwidgets.core.MailSystem.*;

public class PluginCentral 
{
	private static Map<PluginType, Class> __PLUGIN_CLASS_MAP;
	
	public enum PluginType
	{
		general,
		blob_store,
		mail_sender;
		
		// This is the name of the key_str in the system_setting table
		// Note there might be other system settings in addition to plugins, in the table
		public String getPropName()
		{
			return (this.toString() + "_PLUGIN").toUpperCase();
		}
	}
	

	// Get extensions to the Admin sidebar
	public static interface IAdminExtension
	{
		public String getExtendedSideBar(Optional<WidgetUser> user);
	}

    public interface IMailSender
    {
    	// Send the given package of mail objects, each with a Key T
    	// Report the T item back to the caller on success
        public <T extends Comparable<T>> void sendMailPackage(Map<T, WidgetMail> mailmap, Consumer<T> onSuccess) throws Exception;
    
        // Is the given User allowed to send email to the given address?
        public boolean allowEmailSend(ValidatedEmail email, WidgetUser sender);

        // Return a URL that will be inserted into the footer of the email, to allow
        // the user to control email settings.
        public String getEmailControlUrl(ValidatedEmail email, WidgetUser sender);
    }

    /**
     * The WWIO system requires the Blob Storage plugins to implement a very simple mapping
     * from Local filesystem paths to remote Blob storage paths.
     * This can be achieved by doing a simple string replace from the local path to the blob path
     * In cases where only one File argument is supplied, the storage plugin should perform the standard
     * local/remote mapping and then use the result to perform the remote operation
     */
	public static interface IBlobStorage
	{
		public default void uploadLocalPath(File localpath) throws IOException
		{
			uploadLocalToTarget(localpath, localpath);
		}

		// Here, you transform the remote into a Blob storage location, then upload local to it
		public void uploadLocalToTarget(File localpath, File remotepath) throws IOException;

		public boolean blobPathExists(File localpath) throws IOException;

		// Plausibly it seems like we should rationally want to have a downloadToLocal that
		// has a separate argument
		// Transform local to remote, download remote to local
		public void downloadToLocalPath(File localpath) throws IOException;

		// Transform localpath to remote path, and delete remote
		public void deleteFromLocalPath(File localpath) throws IOException;
	}

	/**
	 * Catchall plugin for all of the odds and ends, small custom features
	 * that do not fit cleanly into other areas
	 */
	public static class GeneralPlugin
	{
		// Get a special login page for the requested URL
		// This is for customized installations which require a different login method
		public Optional<String> getSpecialLoginUrl(String requesturl)
		{
			return Optional.empty();
		}

		public IAdminExtension getAdminExtensionTool()
		{
			return s -> "";
		}

		// If you return a valid Google Client ID here, the LogIn page will give users the option
		// of signing in with Google Sign On
		public Optional<String> getGoogleClientId()
		{
			return Optional.empty();
		}

		public Map<String, String> getUserUploadRemap(WidgetUser user)
		{
			return Collections.emptyMap();
		}
	}

	public static IMailSender getMailPlugin()
	{
		return Util.cast(getPluginSub(PluginType.mail_sender));
	}
	
	public static IBlobStorage getStorageTool()
	{
		return Util.cast(getPluginSub(PluginType.blob_store));
	}
	
	public static GeneralPlugin getGeneralPlugin()
	{
		return Util.cast(getPluginSub(PluginType.general, GeneralPlugin.class));
	}

	public static IAdminExtension getAdminExtensionTool()
	{
		return getGeneralPlugin().getAdminExtensionTool();
	}

	public static boolean havePlugin(PluginType ptype)
	{
		return getPluginClassMap().containsKey(ptype);
	}
	
	static Object getPluginSub(PluginType ptype)
	{
		return getPluginSub(ptype, null);
	}
	
	private static Object getPluginSub(PluginType ptype, Class<?> defclass)
	{
		var classmap = getPluginClassMap();
		Class<?> cls = classmap.getOrDefault(ptype, defclass);
		Util.massert(cls != null,
			"No plugin is configured for type %s, and no default is available. You must configure in the system_settings table");
		
		try { return cls.getDeclaredConstructor().newInstance(); }
		catch (Exception ex) { throw new RuntimeException(ex); }
	}

	static synchronized void clearIndex()
	{
		__PLUGIN_CLASS_MAP = null;
	}

	public static synchronized Map<PluginType, Class> getPluginClassMap()
	{
		if(__PLUGIN_CLASS_MAP == null)
		{
			__PLUGIN_CLASS_MAP = Util.treemap();
			
			for(PluginType ptype : PluginType.values())
			{
				String classname = GlobalIndex.getSystemSetting().get(ptype.getPropName());
				if(classname == null)
					{ continue; }
				
				try {
					Class<?> cls = Class.forName(classname);
					Object probe = cls.getDeclaredConstructor().newInstance();
					__PLUGIN_CLASS_MAP.put(ptype, cls);
				} catch (Exception ex) {
					throw new RuntimeException(ex);
				}
			}
		}
		
		return Collections.unmodifiableMap(__PLUGIN_CLASS_MAP);
	}
}