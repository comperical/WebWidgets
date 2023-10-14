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
		mail_sender,
		admin_extend;
		
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
        public <T extends Comparable<T>> void sendMailPackage(Map<T, WidgetMail> mailmap, Consumer<T> onSuccess) throws Exception;
    

        // Is the given User allowed to send email to the given address?
        public boolean allowEmailSend(ValidatedEmail email, WidgetUser sender);

        // Return a URL that will be inserted into the footer of the email, to allow
        // the user to control email settings.
        public String getEmailControlUrl(ValidatedEmail email, WidgetUser sender);
    }

	public static IMailSender getMailPlugin()
	{
		return Util.cast(getPluginSub(PluginType.mail_sender));
	}
	
	public static interface IBlobStorage
	{
		public default void uploadLocalPath(File localpath) throws IOException
		{
			uploadLocalToTarget(localpath, localpath);
		}

		public void uploadLocalToTarget(File localpath, File remotepath) throws IOException;

		public boolean blobPathExists(File localpath) throws IOException;

		public void downloadToLocalPath(File localpath) throws IOException;

		public void deleteFromLocalPath(File localpath) throws IOException;
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
	}
	
	private static Object getPluginSub(PluginType ptype)
	{
		return getPluginSub(ptype, null);
	}
	
	private static Object getPluginSub(PluginType ptype, Class<?> defclass)
	{
		var classmap = getPluginClassMap();
		Class<?> cls = classmap.getOrDefault(ptype, defclass);
		Util.massert(cls != null,
			"No plugin is configured for type %s, and no default is available. You must configure in Plugin.props file");
		
		try { return cls.getDeclaredConstructor().newInstance(); }
		catch (Exception ex) { throw new RuntimeException(ex); }
	}

	
	public static synchronized Map<PluginType, Class> getPluginClassMap()
	{
		if(__PLUGIN_CLASS_MAP == null)
		{
			__PLUGIN_CLASS_MAP = Util.treemap();
			var props = loadPluginProps();
			
			for(PluginType ptype : PluginType.values())
			{
				String classname = props.getProperty(ptype.getPropName());
				if(classname == null || classname.strip().length() == 0)
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
		
		return __PLUGIN_CLASS_MAP;
	}
    
	private static Properties loadPluginProps()
	{
		String pluginpath = Util.sprintf("%s%sPluginConfig.props", 
			CoreUtil.WWIO_BASE_CONFIG_DIR, File.separator);
	
		Util.massert(new File(pluginpath).exists(), 
			"Missing Plugin props file, expected at %s", pluginpath);
		
		return FileUtils.getReaderUtil().setFile(pluginpath).getPropertiesE();
	}
}