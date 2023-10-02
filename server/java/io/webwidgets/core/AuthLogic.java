
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 
import java.util.function.Consumer;

import javax.servlet.*;
import javax.servlet.http.*;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.CoreDb;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.TimeUtil;
import net.danburfoot.shared.CollUtil.*;
import net.danburfoot.shared.CoreDb.QueryCollector;

import io.webwidgets.core.CoreUtil.*;
import io.webwidgets.core.WidgetOrg.*;

public class AuthLogic
{
	public static final String WIDGET_PASSWORD_SALT = "the pelagic argosy sights land";
	
	public static String ACCESS_HASH_COOKIE = "accesshash";

	public static String PERM_GRANT_TABLE = "perm_grant";

	public static String PUBLIC_READ_GRANTEE = "pubread_grantee";
	
	public enum PermLevel
	{
		// load data
		read,
		
		// crud data
		write,
		
		// Modify widget files, change database schema
		admin;
	}
	
	public static Optional<WidgetUser> getLoggedInUser(HttpServletRequest request)
	{
		Optional<WidgetUser> noauth = getUserNoAuthCheck(request);
		if(!noauth.isPresent())
			{ return Optional.empty(); }
				
		ArgMap argmap = WebUtil.getCookieArgMap(request);		
		String accesshash = argmap.getStr(ACCESS_HASH_COOKIE, "");		
		
		boolean authokay = noauth.get().matchPassHash(accesshash);

		return authokay ? noauth : Optional.empty();
	}
	
	public static Optional<WidgetUser> getUserNoAuthCheck(HttpServletRequest request)
	{
		ArgMap argmap = WebUtil.getCookieArgMap(request);
		String username = argmap.getStr("username", "");
		return WidgetUser.softLookup(username);
	}
	
	// TODO: maybe remove this?
	public static boolean checkCredential(String username, String accesshash)
	{
		Optional<WidgetUser> optuser = WidgetUser.softLookup(username);
		return optuser.isPresent() && optuser.get().matchPassHash(accesshash);
	}
	
	public static boolean allowAdminAccess(HttpServletRequest req)
	{
		Optional<WidgetUser> optuser = getLoggedInUser(req);
		return optuser.isPresent() && optuser.get().isAdmin();
	}
	
	// TODO: this can be more beautiful
	public static void setUserCookie(HttpServletRequest request, HttpServletResponse response, String username)
	{
		Util.massert(request.isSecure(),
			"Attempt to set AUTH cookie over insecure connection");
		
		Cookie mycookie = new Cookie("username", username);
		mycookie.setPath("/");
		
		// User name cookie is NOT secure
		// mycookie.setSecure(true);
		
		mycookie.setMaxAge((int) (TimeUtil.DAY_MILLI / 10));
		response.addCookie(mycookie);
	}
	
	public static void setAuthCookie(HttpServletRequest request, HttpServletResponse response, String accesshash)
	{
		Util.massert(request.isSecure(),
			"Attempt to set AUTH cookie over insecure connection");
		
		Cookie mycookie = new Cookie(ACCESS_HASH_COOKIE, accesshash);
		mycookie.setPath("/");
		mycookie.setSecure(true);
		
		// DAY_MILLI is milliseconds; divide by 1000 and mult by 10 days = divide by 100
		mycookie.setMaxAge((int) (TimeUtil.DAY_MILLI / 100));
		response.addCookie(mycookie);
	}
	
	// NB this must match the JavaScript implementation.
	// This is NEVER used except when setting up new users accounts!!!
	public static String canonicalHash(String input) 
	{
		return standardShaHash(WIDGET_PASSWORD_SALT + input);
	}

	public static String standardShaHash(String saltedInput) 
	{		
		try {
			byte[] bytesOfMessage = saltedInput.getBytes("UTF-8");
			java.security.MessageDigest md = java.security.MessageDigest.getInstance("SHA-256");
			byte[] hash = md.digest(bytesOfMessage);	
			
			java.math.BigInteger bi = new java.math.BigInteger(1, hash);
			return String.format("%0" + (hash.length << 1) + "X", bi).toLowerCase();
			
		} catch (Exception ex) {
			throw new RuntimeException(ex);	
		}		
	}


	private static final Map<WidgetItem, PermInfoPack> _PERMISSION_MAP = Util.treemap();

	public static synchronized PermInfoPack getPermInfo4Widget(WidgetItem dbitem)
	{
		return getPermInfoSub(dbitem, false);
	}

	private static synchronized PermInfoPack getPermInfoSub(WidgetItem dbitem, boolean ensure)
	{
		odLoadPermTable();

		if(ensure && !_PERMISSION_MAP.containsKey(dbitem))
			{ _PERMISSION_MAP.put(dbitem, new PermInfoPack(dbitem)); }

		return _PERMISSION_MAP.getOrDefault(dbitem, new PermInfoPack(dbitem));
	}

	private static void odLoadPermTable()
	{
		if(_PERMISSION_MAP.isEmpty())
			{ reloadPermTable(); }
	}

	static synchronized void reloadPermTable()
	{
		_PERMISSION_MAP.clear();
		QueryCollector qcol = CoreUtil.fullTableQuery(CoreUtil.getMasterWidget(), PERM_GRANT_TABLE);

		for(ArgMap onemap : qcol.recList())
		{
			WidgetUser owner = WidgetUser.valueOf(onemap.getStr("owner"));
			String widgetname = onemap.getStr("widget_name");
			WidgetItem dbitem = new WidgetItem(owner, widgetname);

			_PERMISSION_MAP.putIfAbsent(dbitem, new PermInfoPack(dbitem));
			_PERMISSION_MAP.get(dbitem).loadFromRecMap(onemap);
		}

		Util.massert(!_PERMISSION_MAP.isEmpty(), "We need to have at least one perm entry!!");

	}

	public static synchronized void assignPermToGrantee(WidgetItem dbitem, WidgetUser grantee, PermLevel perm)
	{
		Util.massert(grantee != dbitem.theOwner, "You can't add permissions to owner, owner already has admin by default");

		// True:: ensure the record stays in _PERMISSION_MAP
		tweakPerm(dbitem, dbpack -> dbpack.assignPerm(grantee, perm), true);
	}

	public static synchronized void removePermFromGrantee(WidgetItem dbitem, WidgetUser grantee)
	{
		Util.massert(grantee != dbitem.theOwner, "You can't remove admin permissions from owner");

		tweakPerm(dbitem, dbpack -> dbpack.revokePerm(grantee), false);
	}

	public static synchronized void markPublicRead(WidgetItem dbitem, boolean read)
	{
		tweakPerm(dbitem, dbpack -> dbpack.markPublicRead(read), true);
	}

	private static synchronized void tweakPerm(WidgetItem dbitem, Consumer<PermInfoPack> permfunc, boolean ensure)
	{
		PermInfoPack dbpack = getPermInfoSub(dbitem, ensure);
		permfunc.accept(dbpack);
		dbpack.save2Db();
	}

	public static class AuthChecker
	{
		private WidgetItem _dbItem;

		private Optional<WidgetUser> _optAccessor;

		private AuthChecker() {}

		public static AuthChecker build() {
			return new AuthChecker();
		}


		public AuthChecker userFromRequest(HttpServletRequest request)
		{
			Util.massert(_optAccessor == null, "Accessor has already been set");
			_optAccessor = AuthLogic.getLoggedInUser(request);
			return this;
		}

		public AuthChecker directSetAccessor(WidgetUser accessor)
		{
			return directSetAccessor(Optional.of(accessor));
		}

		public AuthChecker directSetAccessor(Optional<WidgetUser> optacc)
		{
			Util.massert(_optAccessor == null, "Accessor has already been set");
			_optAccessor = optacc;
			return this;
		}

		public AuthChecker widgetFromRequestUrl(HttpServletRequest request)
		{
			return widgetFromUrl(request.getRequestURL().toString());
		}

		public AuthChecker widgetFromUrl(String pageurl)
		{
			return directDbWidget(WebUtil.getWidgetFromUrl(pageurl));
		}

		public AuthChecker directDbWidget(WidgetItem item)
		{
			Util.massert(_dbItem == null, "Widget has already been set");
			_dbItem = item;
			return this;
		}

		public Optional<PermLevel> getPermLevel() 
		{
			Util.massert(_optAccessor != null, "You must set the accessor");
			Util.massert(_dbItem != null, "You must set the Widget DB Item");

			return getPermInfo4Widget(_dbItem).getPerm4Accessor(_optAccessor);
		}

		public boolean allowRead()
		{
			return allowOperation(PermLevel.read);
		}

		public boolean allowWrite()
		{
			return allowOperation(PermLevel.write);
		}

		public boolean allowAdmin()
		{
			return allowOperation(PermLevel.admin);
		}

		public boolean allowOperation(PermLevel required)
		{
			Optional<PermLevel> perm = getPermLevel();
			return perm.isPresent() && perm.get().ordinal() >= required.ordinal();
		}

	}

	public static class PermInfoPack
	{
		private final Map<WidgetUser, PermLevel> _coreMap = Util.treemap();

		public final WidgetItem dbItem;

		private boolean _publicRead = false;

		PermInfoPack(WidgetItem item) 
		{
			dbItem = item;
		}

		public Map<WidgetUser, PermLevel> getCorePermMap()
		{
			return Collections.unmodifiableMap(_coreMap);
		}


		public boolean isPublicRead()
		{
			return _publicRead;
		}

		public synchronized Optional<PermLevel> getPerm4Accessor(Optional<WidgetUser> optaccess)
		{
			if(optaccess.isPresent())
			{

				WidgetUser accessor = optaccess.get();

				// You are admin for your own widgets
				if(dbItem.theOwner == accessor)
					{ return Optional.of(PermLevel.admin); }

				// Admins can do anything
				if(accessor.isAdmin()) 
					{ return Optional.of(PermLevel.admin); }

				Optional<PermLevel> core = Optional.ofNullable(_coreMap.get(accessor));
				if(core.isPresent())
					{ return core; }
			}


			return _publicRead ? Optional.of(PermLevel.read) : Optional.empty();
		}

		private synchronized void markPublicRead(boolean read)
		{
			_publicRead = read;
		}

		private synchronized void assignPerm(WidgetUser grantee, PermLevel perm)
		{
			_coreMap.put(grantee, perm);
		}

		private synchronized void revokePerm(WidgetUser grantee)
		{
			_coreMap.remove(grantee);
		}

		private synchronized void loadFromRecMap(ArgMap amap)
		{
			PermLevel level = amap.getEnum("perm_level", PermLevel.values());
			String grantee = amap.getStr("grantee");

			if(PUBLIC_READ_GRANTEE.equals(grantee))
			{
				Util.massert(level == PermLevel.read, "Expected PermLevel read here, found %s", level);
				_publicRead = true;
				return;
			}

			_coreMap.put(WidgetUser.lookup(grantee), level);
		}

		private synchronized void save2Db()
		{

			CoreDb.deleteFromColMap(CoreUtil.getMasterWidget(), AuthLogic.PERM_GRANT_TABLE, CoreDb.getRecMap(
				"owner", dbItem.theOwner.toString(),
				"widget_name", dbItem.theName
			));


			List<Pair<String, PermLevel>> updates = Util.vector();

			for(WidgetUser grantee : _coreMap.keySet())
			{
				PermLevel perm = _coreMap.get(grantee);
				updates.add(Pair.build(grantee.toString(), perm));
			}

			if(_publicRead)
				{ updates.add(Pair.build(PUBLIC_READ_GRANTEE, PermLevel.read));}

			for(Pair<String, PermLevel> permpair : updates)
			{
				int id = CoreUtil.getNewDbId(CoreUtil.getMasterWidget(), AuthLogic.PERM_GRANT_TABLE);

				CoreDb.upsertFromRecMap(CoreUtil.getMasterWidget(), AuthLogic.PERM_GRANT_TABLE, 1, CoreDb.getRecMap(
					"id", id,
					"owner", dbItem.theOwner.toString(),
					"widget_name", dbItem.theName,
					"grantee", permpair._1.toString(),
					"perm_level", permpair._2.toString()
				));
			}
		}
	}
}