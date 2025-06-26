
package net.danburfoot.shared; 

import java.text.*; 
import java.util.*; 
import java.io.*; 

import org.w3c.dom.*;

import net.danburfoot.shared.Util.*;
import net.danburfoot.shared.CollUtil.*;

public class ArgMap extends TreeMap<String, String>
{
	// T/F if the object can be modified
	private boolean _mutableMode = true;
	
	protected String subGetStr(String pname, List<? extends Object> deflist)
	{
		Util.massert(deflist.size() <= 1, "Too many optargs: %s", deflist);
		
		if(!containsKey(pname))
		{
			Util.massert(deflist.size() == 1,
				"ArgMap key %s not found and no default value provided", pname);
			
			// Default can be null
			Object defobj = deflist.get(0);
			
			return (defobj == null ? null : defobj.toString());
		}
		
		String mresult = get(pname);
		
		return mresult;
	}
	
	// No-default getters throw exceptions if the key is not in the map
	public String getStr(String pname)
	{
		return subGetStr(pname, Util.listify());
	}
	
	public Optional<String> optGetStr(String pname)
	{
		return containsKey(pname) ? Optional.of(getStr(pname)) : Optional.empty();	
	}	
		
	// Using an Object default argument here allows you to pass enums
	// without doing the annoying myenum.toString()
	public String getStr(String pname, String defvalue)
	{
		// return containsKey(pname) ? get(pname) : (defvalue == null ? null : defvalue.toString());
		return subGetStr(pname, Util.listify(defvalue));
	}	
	
	// This is useful when you only have a single column in the ArgMap.
	// Eg SQL queries with one column, don't want to repeat yourself about column name.
	public String getSingleStr()
	{
		Util.massert(size() == 1, 
			"Attempt to get single record but have size=%d", size());
		
		return getStr(keySet().iterator().next());
	}
	
	public int getSingleInt()
	{
		return Integer.valueOf(getSingleStr());	
	}
	
	public double getSingleDbl()
	{
		return Double.valueOf(getSingleStr());	
	}
	
	public Integer getInt(String pname)
	{
		return integerOrNull(subGetStr(pname, Util.listify()));
	}
	
	public Optional<Integer> optGetInt(String pname)
	{
		return containsKey(pname) ? Optional.of(getInt(pname)) : Optional.empty();
	}
	
	public Integer getInt(String pname, Integer defval)
	{
		String sgs = subGetStr(pname, Util.listify(defval));
		return integerOrNull(sgs);
	}
	
	public Long getLong(String pname)
	{
		return longOrNull(subGetStr(pname, Util.listify()));
	}
	
	public Long getLong(String pname, Long defval)
	{
		String sgs = subGetStr(pname, Util.listify(defval));
		return longOrNull(sgs);
	}
	
	public Double getDbl(String pname)
	{
		return doubleOrNull(subGetStr(pname, Util.listify()));
	}
	
	public Double getDbl(String pname, Double defval)
	{
		String sgs = subGetStr(pname, Util.listify(defval));
		return doubleOrNull(sgs);
	}
	
	public Boolean getBit(String pname)
	{
		return booleanOrNull(subGetStr(pname, Util.listify()));
	}
	
	public Boolean getBit(String pname, Boolean defval)
	{
		String sgs = subGetStr(pname, Util.listify(defval));
		return booleanOrNull(sgs);
	}
	
	// Required to be present, Assume string name is lowercase version of enum name
	public <T> T getEnum(T[] options)
	{
		String ename = options[0].getClass().getSimpleName().toLowerCase();
		return getEnum(ename, options);
	}
	
	// Assume string name is lowercase version of enum name
	public <T> T getEnum(T[] options, T defval)
	{
		String ename = options[0].getClass().getSimpleName().toLowerCase();
		return getEnum(ename, options, defval);	
	}
	
	// Required to be present.
	public <T> T getEnum(String ename, T[] options)
	{
		return dumbEnumLookup(subGetStr(ename, Util.listify()), options);
	}
	
	// Error if we have a key present, but it doesn't match any of the 
	public <T> T getEnum(String ename, T[] options, T defval)
	{
		return dumbEnumLookup(subGetStr(ename, Util.listify(defval)), options);
	}	

	public <T> Optional<T> optGetEnum(T[] options)
	{
		String ename = options[0].getClass().getSimpleName().toLowerCase();
		return optGetEnum(ename, options);			
	}
	
	
	public <T> Optional<T> optGetEnum(String ename, T[] options)
	{
		return Optional.ofNullable(dumbEnumLookup(get(ename), options));
	}
	
	private <T> T dumbEnumLookup(String enumstr, T[] options)
	{
		if(enumstr == null)
			{ return null; }
		
		// This is basically just a spelled-out version of Enum.valueOf(s)
		for(T oneopt : options)
		{	
			if(oneopt.toString().equals(enumstr))
				{ return oneopt; }
		}
		
		Util.massert(false, 
			"Found no enum matching value string '%s', options are %s", enumstr, Util.listify(options));
		
		return null;		
	}
	
	public <T> List<T> getEnumOrAll(String ename, T[] options, Object defval)
	{
		String substr = subGetStr(ename, Util.listify(defval));
		
		if(substr.equals("all"))
			{ return Util.listify(options); }
		
		return Util.listify(dumbEnumLookup(substr, options));
	}
	
	public void transferField(String oldname, String newname)
	{
		Util.massert(containsKey(oldname),
			"Attempt to transfer field named %s, but it doesn't exist", oldname);
		
		put(newname, get(oldname));
		
		remove(oldname);
	}
	

	
	public void showInfo()
	{
		for(String onekey : keySet())
		{
			Util.pf("%s --> %s\n",
				onekey, get(onekey));
		}
	}
	
	public static ArgMap getFromXmlAtt(Element xmlel)
	{
		ArgMap argmap = new ArgMap();
		
		NamedNodeMap nnmap = xmlel.getAttributes();
		
		Util.range(nnmap.getLength())
			.stream()
			.map(i -> nnmap.item(i))
			.forEach(node -> argmap.put(node.getNodeName(), node.getNodeValue()));
		
		return argmap;
	}
	
	public static ArgMap buildFromMap(Map<String, ? extends Object> omap)
	{
		ArgMap themap = new ArgMap();
		
		for(String k : omap.keySet())
			{ themap.put(k, omap.get(k).toString()); }
		
		return themap;
	}
		
	
	public static ArgMap buildFromQueryString(String qstr)
	{
		return buildFromQueryString(qstr, false);
	}
	
	
	

	public static ArgMap buildFromQueryString(String qstr, boolean dupokay)
	{
		Util.massert(qstr.startsWith("?"), "by convention QueryString starts with ?");
		ArgMap themap = new ArgMap();
		
		if(qstr.length() == 1)
			{ return themap; }
		
		String[] pairs = qstr.substring(1).split("&");
		
		for(String onepair : pairs)
		{
			String[] kv = onepair.split("=");
			
			
			Util.massert(dupokay || !themap.containsKey(kv[0]),
				"Duplicate key in query string %s", kv[0]);
			
			Util.putNoDup(themap, kv[0], kv[1]);
		}
		
		return themap;
	}
	
	public static ArgMap getClArgMap(String[] args)
	{
		return getFromLineList(Util.listify(args));
	}
	
	public static ArgMap getFromLineList(List<String> arglist)
	{
		ArgMap amap = new ArgMap();
		
		for(String onearg : arglist)
		{
			// This can happen in resource files, not so much elsewhere
			if(onearg.trim().startsWith("//"))
				{ continue; }
			
			if(onearg.indexOf("=") == -1)
				{ continue; }
			
			String[] toks = onearg.split("=");
			Util.massert(toks.length == 2, "Improperly formatted vararg %s", onearg);
			Util.massert(!amap.containsKey(toks[0]), "Token %s already in Map", toks[0]);
			
			amap.put(toks[0], toks[1]);
		}		
		
		return amap;	
	}
	
	public String flatStringForm()
	{
		List<String> pairlist = Util.map2list(this.entrySet(), me -> Util.sprintf("%s=%s", me.getKey(), me.getValue()));	
		return Util.join(pairlist, " ");
	}
	
	public static ArgMap getFromMap(Map<String, String> copyfrom)
	{
		ArgMap amap = new ArgMap();
		amap.putAll(copyfrom);
		return amap;
	}
	
	public ArgMap copyRemove(Collection<String> remcol)
	{
		return copyRemove(remcol, false);	
	}
	
	
	public ArgMap copyRemove(Collection<String> remcol, boolean missokay)
	{
		for(String s : remcol)
		{
			Util.massert(missokay || containsKey(s), 
				"Attempt to remove key %s that is not present in map", s);
		}
		
		ArgMap copy = getFromMap(this);
		
		for(String r : remcol)
			{ copy.remove(r); }
	
		return copy;
	}
	
	public void setStr(String pname, String val)
	{
		Util.massert(_mutableMode, "This ArgMap is not mutable");
		
		put(pname, val);
	}
	
	
	public void setEnumDefault(Enum def)
	{
		setdefault(def.getClass().getSimpleName().toLowerCase(), def.toString());	
	}
	
	public void setdefault(String key, String val)
	{
		if(!containsKey(key))
		{ 
			Util.massert(_mutableMode, "This ArgMap is not mutable");
			put(key, val); 
		}
	}
	
	public void setdefault(String key, Integer val)
	{
		setdefault(key, ""+val);
	}
	
	// Logging ArgMap overrides to return true.
	public boolean isLogMode()
	{
		return false;
	}
	

	private static Boolean booleanOrNull(String s)
	{ return parseOrNull(s, Boolean::valueOf); }

	private static Integer integerOrNull(String s)
	{ return parseOrNull(s, Integer::valueOf); }

	private static Long longOrNull(String s)
	{ return parseOrNull(s, Long::valueOf); }

	private static Double doubleOrNull(String s)
	{ return parseOrNull(s, Double::valueOf); }

	private static <T> T parseOrNull(String s, java.util.function.Function<String, T> parser) 
	{
		return (s == null) ? null : parser.apply(s);
	}



	
	public static class LoggingArgMap extends ArgMap
	{
		private Map<String, Class> _reqdAccessMap = Util.linkedhashmap();
		
		private Map<String, Pair<Class, Object>> _optAccessMap = Util.linkedhashmap();
		
		private boolean logAccessReqd(String keyname, Class targclass)
		{
			_reqdAccessMap.put(keyname, targclass); 
			
			return containsKey(keyname);
		}
		
		private void logAccessDefault(String keyname, Object defval)
		{
			_optAccessMap.put(keyname, Pair.build(defval.getClass(), defval)); 
		}
		
		public Map<String, Class> getReqdArgMap()
		{ return Collections.unmodifiableMap(_reqdAccessMap); }
		
		public Map<String, Pair<Class, Object>> getOptArgMap()
		{ return Collections.unmodifiableMap(_optAccessMap); }
		
		@Override
		protected String subGetStr(String pname, List<? extends Object> deflist)
		{
			if(deflist.size() == 1)
			{
				// Util.pf("Have default list for %s : %s\n", pname, deflist);
				
				Util.massert(deflist.get(0) != null,
					"Found null default for key %s, LogModeRunnable cannot use null default", pname);
				
				logAccessDefault(pname, deflist.get(0));	
			}
			
			return super.subGetStr(pname, deflist);
		}	
		
		
		// No-default getters throw exceptions if the key is not in the map
		@Override
		public String getStr(String pname)
		{
			if(!logAccessReqd(pname, String.class))
				{ return null; }
			
			return super.getStr(pname);
		}
		
		@Override
		public <T> T getEnum(String ename, T[] options)
		{
			if(!logAccessReqd(ename, options[0].getClass()))
				{ return null; }
			
			return super.getEnum(ename, options);
		}	
		
		
		@Override
		public Integer getInt(String pname)
		{
			if(!logAccessReqd(pname, Integer.class))
				{ return null; }

			return super.getInt(pname);
		}
		
		@Override
		public Long getLong(String pname)
		{
			if(!logAccessReqd(pname, Long.class))
				{ return null; }	
			
			return super.getLong(pname);
		}		
		
		@Override
		public Double getDbl(String pname)
		{
			if(!logAccessReqd(pname, Double.class))
				{ return null; }
			
			return super.getDbl(pname);
		}		
		
		@Override
		public Boolean getBit(String pname)
		{
			if(!logAccessReqd(pname, Boolean.class))
				{ return null; }
			
			return super.getBit(pname);
		}	
		
		@Override 
		public boolean isLogMode()
		{
			return true;	
		}
	}
} 
