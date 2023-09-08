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
		blob_store,
		mail_sender,
		admin_extend;
		
		public String getPropName()
		{
			return (this.toString() + "_PLUGIN").toUpperCase();	
		}
	}
	

    public interface IMailSender
    {
        public <T extends Comparable<T>> void sendMailPackage(Map<T, WidgetMail> mailmap, Consumer<T> onSuccess) throws Exception;
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
	
	
	private static Object getPluginSub(PluginType ptype)
	{
		var classmap = getPluginClassMap();
		Class<?> cls = classmap.get(ptype);
		Util.massert(cls != null,
			"No plugin is configured for type %s. You must configure in Plugin.props file");
		
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
				Util.massert(props.containsKey(ptype.getPropName()),
					"Missing entry for ptype %s, name %s, use empty strings if you don't have a plugin",
					ptype, ptype.getPropName());
				
				String classname = props.getProperty(ptype.getPropName());
				if(classname.strip().length() == 0)
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
			LifeUtil.WWIO_BASE_CONFIG_DIR, File.separator);
	
		Util.massert(new File(pluginpath).exists(), 
			"Missing Plugin props file, expected at %s", pluginpath);
		
		return FileUtils.getReaderUtil().setFile(pluginpath).getPropertiesE();
	}
}