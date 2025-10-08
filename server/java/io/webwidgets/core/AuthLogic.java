
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
import io.webwidgets.core.MailSystem.ValidatedEmail;

public class AuthLogic
{
	public static final String WIDGET_PASSWORD_SALT = "the pelagic argosy sights land";

	public static String PERM_GRANT_TABLE = "perm_grant";

	public static String PUBLIC_READ_GRANTEE = "pubread_grantee";
	

	// The ORDER of this enum is important, read < write < admin
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
		String accesshash = argmap.getStr(CoreUtil.ACCESS_HASH_COOKIE, "");
		
		boolean authokay = noauth.get().matchPassHash(accesshash);

		return authokay ? noauth : Optional.empty();
	}
	
	public static Optional<WidgetUser> getUserNoAuthCheck(HttpServletRequest request)
	{
		ArgMap argmap = WebUtil.getCookieArgMap(request);
		String username = argmap.getStr(CoreUtil.USER_NAME_COOKIE, "");
		return WidgetUser.softLookup(username);
	}

	// This is used in the LogIn page to check that the credential is correct
	// before setting the cookie
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
	
	public static void setUserCookie(HttpServletRequest request, HttpServletResponse response, String username)
	{
		Cookie mycookie = new Cookie(CoreUtil.USER_NAME_COOKIE, username);
		mycookie.setPath("/");
		
		// Make these configurable?
		mycookie.setMaxAge((int) (TimeUtil.DAY_MILLI / 10));
		response.addCookie(mycookie);
	}
	
	public static void setAuthCookie(HttpServletRequest request, HttpServletResponse response, String accesshash)
	{
		Util.massert(request.isSecure() || AdvancedUtil.allowInsecureConnection(),
			"Attempt to set AUTH cookie over insecure connection, insecure connections disallowed");
		
		Cookie mycookie = new Cookie(CoreUtil.ACCESS_HASH_COOKIE, accesshash);
		mycookie.setPath("/");

		// This was previously just TRUE, but if the request is not secure due to config, there's no point
		// in not allowing the cookie to be stored.
		mycookie.setSecure(request.isSecure());
		
		// DAY_MILLI is milliseconds; divide by 1000 and mult by 10 days = divide by 100
		mycookie.setMaxAge((int) (TimeUtil.DAY_MILLI / 100));
		response.addCookie(mycookie);
	}


	// Confirm to the system that the user has authenticated with the given email address
	// This is an entry hook to techniques like Sign in with Google
	// This implies that we need to check that a given email address is who they say they are
	public static boolean confirmExternalAuth(HttpServletRequest request, HttpServletResponse response, ValidatedEmail vemail)
	{
		List<WidgetUser> hitlist = Util.filter2list(WidgetUser.values(),
										user -> user.getEmailSet().contains(vemail.emailAddr));

		Util.massert(hitlist.size() <= 1, "Found multiple accounts with email %s", vemail.emailAddr);

		if(hitlist.isEmpty())
			{ return false; }

		WidgetUser user = hitlist.get(0);
		setUserCookie(request, response, user.getUserName());
		setAuthCookie(request, response, user.getAccessHash());
		return true;
	}
	
	public static void performLogOut(HttpServletRequest request, HttpServletResponse response)
	{
		Set<String> clearset = Util.setify(CoreUtil.ACCESS_HASH_COOKIE, CoreUtil.USER_NAME_COOKIE);

		if(request.getCookies() == null)
			{ return; }

        for(Cookie cookie : request.getCookies()) 
        {
        	if(!clearset.contains(cookie.getName()))
        		{ continue; }

			cookie.setMaxAge(0);
			cookie.setPath("/"); 
			response.addCookie(cookie);
	    }
	}


	// NB this must match the JavaScript implementation.
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


	// These methods were all previously synchronized, but I don't think there are going to be
	// simultaneous edits to the permissions, and the GlobalIndex is sync'ed
	public static void assignPermToGrantee(WidgetItem dbitem, WidgetUser grantee, PermLevel perm)
	{
		Util.massert(grantee != dbitem.theOwner, "You can't add permissions to owner, owner already has admin by default");

		// True:: ensure the record stays in _PERMISSION_MAP
		tweakPerm(dbitem, dbpack -> dbpack.assignPerm(grantee, perm));
	}

	public static void removePermFromGrantee(WidgetItem dbitem, WidgetUser grantee)
	{
		Util.massert(grantee != dbitem.theOwner, "You can't remove admin permissions from owner");

		tweakPerm(dbitem, dbpack -> dbpack.revokePerm(grantee));
	}

	public static void markPublicRead(WidgetItem dbitem, boolean read)
	{
		tweakPerm(dbitem, dbpack -> dbpack.markPublicRead(read));
	}

	private static void tweakPerm(WidgetItem dbitem, Consumer<PermInfoPack> permfunc)
	{
		PermInfoPack dbpack = GlobalIndex.getPermInfo4Widget(dbitem);
		permfunc.accept(dbpack);
		dbpack.save2Db(dbitem);

		// Need to reload indexes to pick up changes
		// Like the changes to user password, this is a bit hacky, but will be okay until we have so many users
		// that permission changes are happening often
		// Previously, was trying to be smart and use an update-and-save technique, but there was a lot of confusion
		// about ensuring that the index always had an entry
		GlobalIndex.clearUserIndexes();
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

		// Note: this argument might not actually exist on disk
		// this could be a "virtual" widget
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

			return GlobalIndex.getPermInfo4Widget(_dbItem).getPerm4Accessor(_dbItem, _optAccessor);
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

		private boolean _publicRead = false;

		PermInfoPack() 
		{
		}

		public Map<WidgetUser, PermLevel> getCorePermMap()
		{
			return Collections.unmodifiableMap(_coreMap);
		}


		public boolean isPublicRead()
		{
			return _publicRead;
		}

		public synchronized Optional<PermLevel> getPerm4Accessor(WidgetItem dbitem, Optional<WidgetUser> optaccess)
		{
			if(optaccess.isPresent())
			{
				WidgetUser accessor = optaccess.get();

				// You are admin for your own widgets
				if(dbitem.theOwner == accessor)
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

		synchronized void loadFromRecMap(ArgMap amap)
		{
			PermLevel level = amap.getEnum("perm_level", PermLevel.values());
			String grantee = amap.getStr("grantee");

			if(PUBLIC_READ_GRANTEE.equals(grantee))
			{
				Util.massert(level == PermLevel.read, "Expected PermLevel read here, found %s", level);
				_publicRead = true;
				return;
			}

			// Careful here, the FKey relationship is not enforced by the DB
			Optional<WidgetUser> optgrant = WidgetUser.softLookup(grantee);
			if(!optgrant.isPresent())
				{ return; }

			_coreMap.put(optgrant.get(), level);
		}

		private synchronized void save2Db(WidgetItem dbItem)
		{

			CoreDb.deleteFromColMap(WidgetItem.getMasterWidget(), AuthLogic.PERM_GRANT_TABLE, CoreDb.getRecMap(
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
				int id = CoreUtil.getNewDbId(WidgetItem.getMasterWidget(), AuthLogic.PERM_GRANT_TABLE);

				CoreDb.upsertFromRecMap(WidgetItem.getMasterWidget(), AuthLogic.PERM_GRANT_TABLE, 1, CoreDb.getRecMap(
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