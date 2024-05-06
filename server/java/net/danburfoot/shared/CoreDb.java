
package net.danburfoot.shared;

import java.io.*;
import java.util.*;
import java.util.regex.*;
import java.sql.*;

import org.sqlite.JDBC;
import org.sqlite.SQLiteConfig;

import net.danburfoot.shared.Util.*;
import net.danburfoot.shared.TimeUtil.*;

public class CoreDb
{

	private static Set<String> _CLASS_INIT_SET = Util.treeset();

	private static SQLiteConfig __SQLITE_CONFIG;

	public static interface ConnectionSource
	{
		public abstract Connection createConnection() throws SQLException;
	}

	public static class QueryCollector
	{
		// {{{
		
		private LinkedHashMap<String, Vector<String>> _resultData = new LinkedHashMap<String, Vector<String>>();

		private boolean _incHeader = false;

		private String delim = "\t";
		
		private String _sqlQuery;
		
		private List<Object> _prepList = null;
		
		public QueryCollector(String sql)
		{
			_sqlQuery = sql;
		}
		
		public QueryCollector setVargList(Object... varglist)
		{
			_prepList = Util.listify(varglist);
			return this;
		}
		
		public static QueryCollector buildFromResultSet(ResultSet rset) throws SQLException
		{
			QueryCollector qcol = new QueryCollector("???");
			qcol.grabData(rset);
			return qcol;
		}


		public static QueryCollector buildRunPrepared(String prepsql, ConnectionSource csource, Object... vargs)
		{
			QueryCollector qcol = new QueryCollector(prepsql);

			try (var conn = csource.createConnection()) {

				PreparedStatement pstmt = conn.prepareStatement(prepsql);
				for(int i : Util.range(vargs.length)) 
					{ pstmt.setObject(i+1, vargs[i]); }

				ResultSet rset = pstmt.executeQuery();
				qcol.grabData(rset);
				return qcol;

			} catch(Exception ex) {

				throw new RuntimeException(ex); 

			}

		}
		
		public static QueryCollector buildAndRun(String sql, ConnectionSource csource)
		{
			return (new QueryCollector(sql)).doQuery(csource);	
		}		

		public static QueryCollector buildAndRun(String sql, Connection conn) throws SQLException
		{
			return (new QueryCollector(sql)).doQuery(conn);	
		}				
		
		
		public QueryCollector doQuery(ConnectionSource csource)
		{
			grabData(csource);
			return this;
		}
		
		public QueryCollector doQuery(Connection conn) throws SQLException
		{
			grabData(conn);
			return this;
		}
		
		public Set<String> getOrderedColSet() 
		{
			return _resultData.keySet();	
		}

		public List<String> getColumnList()
		{
			Util.massert(!_resultData.isEmpty(), "Must call grabData(...) first");
			return new Vector<String>(_resultData.keySet());
		}

		private void grabData(ConnectionSource csource)
		{
			try {
				Connection conn  = csource.createConnection();
				grabData(conn);
				conn.close();
			} catch (SQLException sqlex) {
				throw new RuntimeException(sqlex);	
			}
		}				

		private void grabData(Connection conn) throws SQLException
		{
			ResultSet rset;
			
			if(_prepList == null)
			{
				Statement stmt = conn.createStatement();
				rset = stmt.executeQuery(_sqlQuery);				
			} else {
				
				// Here the SQL is a prepared form query.
				rset = CoreDb.execSqlQueryPrepared(conn, _sqlQuery, _prepList);
			}

			grabData(rset);			
		}

		private void grabData(ResultSet rset) throws SQLException
		{
			Util.massert(_resultData.isEmpty(),
				"You cannot reuse these objects, already have result data with %d columns", _resultData.size());

			int rcount = 0;
			ResultSetMetaData rsmd = rset.getMetaData();

			for(int i = 1; i <= rsmd.getColumnCount(); i++)
			{
				String c_label = rsmd.getColumnLabel(i);
				_resultData.put(c_label, new Vector<String>());
			}				

			while(rset.next())
			{
				for(String colname : _resultData.keySet())
					{ _resultData.get(colname).add(rset.getString(colname)); }

				rcount++;
			}		

			// Util.pf("QueryCollector: grabbed %d records\n", rcount);
		}

		public QueryCollector  setIncHeader(boolean ih)
		{
			_incHeader = ih;
			return this;
		}

		public String getTableItem(String colname, int rowid)
		{
			return _resultData.get(colname).get(rowid);
		}

		public List<ArgMap> getArgMapList()
		{
			List<ArgMap> arglist = Util.vector();
			
			for(int recid : Util.range(getNumRec()))
				{ arglist.add(getRowArgMap(recid)); }
			
			return arglist;
		}
		
		public List<ArgMap> recList()
		{
			return getArgMapList();
		}
		
		
		public ArgMap getSingleArgMap()
		{
			Util.massertEqual(getNumRec(), 1, "Attempt to get %d records, but have %d records");
			
			return getRowArgMap(0);
		}
		
		public ArgMap getRowArgMap(int rowid)
		{
			Util.massert(0 <= rowid && rowid < getNumRec(),
				"Attempt to access row ID %d, but collector has only %d records", rowid, getNumRec());

			ArgMap amap = new ArgMap();

			for(String onecol : _resultData.keySet())
				{ amap.put(onecol, _resultData.get(onecol).get(rowid)); }	

			return amap;
		}

		public List<String> getRow(int i)
		{
			if(i == -1)
				{ return getColumnList(); }
			
			List<String> rowlist = Util.vector();

			for(Vector<String> coldata : _resultData.values())
				{ rowlist.add(coldata.get(i)); }

			return rowlist;
		}
		
		
		public LinkedHashMap<String, String> getOrigOrderMap(int recid) 
		{
			
			LinkedHashMap<String, String> omap = Util.linkedhashmap();
			
			for(String k : _resultData.keySet()) {
				omap.put(k, _resultData.get(k).get(recid));	
			}
			
			return omap;
			
		}
		
		
		public List<String> getFormatRow(List<Boolean> doquote, int recid)
		{
			List<String> reslist = Util.vector();
			List<String> rowlist = getRow(recid);
			
			Util.massert(rowlist.size() == doquote.size(),
				"Format list must be the same size as row list, found %d vs %d", rowlist.size(), doquote.size());
			
			for(int r : Util.range(rowlist.size()))
			{
				String record = rowlist.get(r);
				
				if(doquote.get(r))
					{ record = "'" + record + "'"; }
				
				reslist.add(record);	
			}
			
			return reslist;
		}
		

		public int getNumRec()
		{
			for(Vector<String> onevec : _resultData.values())
				{ return onevec.size(); }

			throw new RuntimeException("Result DAta is empty, must call grabData(..) first");
		}

		public void writeResult(BufferedWriter bwrite) throws IOException
		{
			if(_incHeader)
			{
				String s = Util.join(_resultData.keySet(), delim);
				bwrite.write(s + "\n");
			}		

			int nr = getNumRec();

			for(int i = 0; i < nr; i++)
			{
				String s = Util.join(getRow(i), delim);
				bwrite.write(s + "\n");

			}
		}

		public void writeResultE(BufferedWriter bwrite)
		{
			try { writeResult(bwrite); }
			catch (IOException ioex) { throw new RuntimeException(ioex); }	
		}

		public void writeResult(File onefile) throws IOException
		{
			BufferedWriter bwrite = FileUtils.getWriterUtil().setFile(onefile.getAbsolutePath()).getWriter();
			writeResult(bwrite);
			bwrite.close();
		}
		
		public void writeResult(String path) throws IOException
		{
			writeResult(new File(path));
		}		
	
		public void writeResultE(File targfile)
		{
			try { writeResult(targfile); }
			catch (IOException ioex) { throw new RuntimeException(ioex); }	
		}		

		public void setDelimeter(String d)
		{
			delim = d;
		}
		
		// }}}
	}  

	public static synchronized void maybeLoadDbClassInfo(String myclass)
	{
		if(_CLASS_INIT_SET.contains(myclass))
			{ return; }
		
		try {
			Class.forName(myclass);
			_CLASS_INIT_SET.add(myclass);

		} catch (Exception ex )  {
			
			throw new RuntimeException(ex);	
		}
	}	       		
	
	public static <A> List<A> execSqlQuery(String sql, ConnectionSource csource)
	{
		try { 
			Connection conn = csource.createConnection();	
			List<A> rlist = execSqlQuery(sql, conn);
			conn.close();
			return rlist;
		} catch (SQLException sqlex) {
			throw new RuntimeException(sqlex);	
		}
	}

	
	public static <A> List<A> execSqlQuery(String sql, Connection conn) throws SQLException
	{
		List<A> reslist = Util.vector();
		PreparedStatement pstmt = conn.prepareStatement(sql);
		ResultSet rset = pstmt.executeQuery();
		
		while(rset.next())
		{
			A a = Util.cast(rset.getObject(1));
			reslist.add(a);
		}
		
		return reslist;
	}		

	public static int getNewId(ConnectionSource litedb, String tablename, String idcol)
	{
		String sql = Util.sprintf("SELECT %s FROM %s ORDER BY %s DESC LIMIT 1", idcol, tablename, idcol);
		
		QueryCollector qcol = QueryCollector.buildAndRun(sql, litedb);

		if(qcol.getNumRec() == 0)
			{ return 0; }
		
		return qcol.getArgMapList().get(0).getInt(idcol) + 1;
	}		


	// Okay, interesting - these methods actually work.
	// You can have a ResultSet even though the underlying Connection has been closed.
	public static ResultSet execSqlQueryPrepared(ConnectionSource csrc, String formsql,Object... vargs)
	{
		return 	execSqlQueryPrepared(csrc, formsql, Util.listify(vargs));
	}
	
	public static ResultSet execSqlQueryPrepared(ConnectionSource csrc, String formsql, List<Object> varglist) 
	{
		try {
			Connection conn = csrc.createConnection();
			ResultSet rset = execSqlQueryPrepared(conn, formsql, varglist);
			conn.close();
			return rset;
			
		} catch (SQLException sqlex) {
			throw new RuntimeException(sqlex);	
		}		
	}		
	 
	public static ResultSet execSqlQueryPrepared(Connection conn, String formsql, Object... vargs) throws SQLException
	{
		return execSqlQueryPrepared(conn, formsql, Util.listify(vargs));
	}	
	
	public static ResultSet execSqlQueryPrepared(Connection conn, String formsql, List<Object> varglist) throws SQLException
	{
		PreparedStatement pstmt = conn.prepareStatement(formsql);
		
		for(int i = 0; i < varglist.size(); i++)
			{ setPrepStatementInfo(pstmt, i+1, varglist.get(i)); }
		
		ResultSet rset = pstmt.executeQuery();
		
		return rset;
	}	
	

	private static void setPrepStatementInfo(PreparedStatement pstmt, int position, Object toset) throws SQLException
	{
		// Okay, we don't trust Java JDBC setObject(..) method, do this on our own.
		
		if(toset == null)
			{ pstmt.setString(position, null); }
		else if(toset instanceof Integer)
			{ pstmt.setInt(position, (Integer) toset); }
		else if(toset instanceof Long)
			{ pstmt.setLong(position, (Long) toset); }
		else if(toset instanceof Short)
			{ pstmt.setLong(position, (Short) toset); }		
		else if(toset instanceof Double)
			{ pstmt.setDouble(position, (Double) toset); }	
		else if(toset instanceof String)
			{ pstmt.setString(position, (String) toset); }
		else if(toset instanceof Enum)
			{ pstmt.setString(position, toset.toString()); }	
		
		else if(toset instanceof Boolean)
			{ pstmt.setInt(position, ((Boolean) toset ? 1 : 0)); }			
		else if(toset instanceof Calendar)
		{ 
			Calendar mycal = (Calendar) toset;	
			pstmt.setTimestamp(position, new java.sql.Timestamp(mycal.getTimeInMillis()), mycal); 
		}
		else 
			{ Util.massert(false, "unknown type %s for varg to PrepStatement value=%s", toset.getClass(), toset); }
	}	

	// {{{
	

	public static int execSqlUpdate(String sql, ConnectionSource csource)
	{
		try { 
			Connection conn = csource.createConnection();
			int numhit = execSqlUpdate(sql, conn);
			conn.close();
			return numhit;
		} catch (SQLException sqlex) {
			throw new RuntimeException(sqlex);
		}
	}

	public static int execSqlUpdate(String sql, Connection conn) throws SQLException
	{
		PreparedStatement pstmt = conn.prepareStatement(sql);
		int result = pstmt.executeUpdate();
		return result;
	}


	public static int execSqlUpdatePrepared(ConnectionSource csrc, String formsql, Object... vargs)
	{
		try {
			Connection conn = csrc.createConnection();
			int nrows = execSqlUpdatePrepared(conn, formsql, vargs);
			conn.close();
			return nrows;
			
		} catch (SQLException sqlex) {
			throw new RuntimeException(sqlex);	
		}
	}
	
	public static int execSqlUpdatePrepared(Connection conn, String formsql, Object... vargs) throws SQLException
	{
		return execSqlUpdatePrepared(conn, formsql, Util.listify(vargs));
	}	
	
	public static int execSqlUpdatePrepared(Connection conn, String formsql, List<Object> varglist) throws SQLException
	{
		PreparedStatement pstmt = conn.prepareStatement(formsql);
		
		for(int i = 0; i < varglist.size(); i++)
			{ setPrepStatementInfo(pstmt, i+1, varglist.get(i)); }
		
		return pstmt.executeUpdate();
	}	
	
	public static void vargPrep(PreparedStatement pstmt, Object... vargs) throws SQLException
	{
		for(int i = 0; i < vargs.length; i++)
			{ setPrepStatementInfo(pstmt, i+1, vargs[i]); }
	}	

	
	public static LinkedHashMap<String, Object> getRecMap(Object... vargs)
	{
		LinkedList<Object> vlist = Util.linkedlistify(vargs);
		LinkedHashMap<String, Object> pkeymap = Util.linkedhashmap();
		
		while(!vlist.isEmpty())
		{
			Object pkeystr = vlist.poll();
			
			Util.massert(pkeystr instanceof String, 
				"Found non-string value %s where we expected a PKey column name", pkeystr);
			
			Util.massert(!vlist.isEmpty(), 
				"Found odd number of vargs, expected a value corresponding to pkey %s", pkeystr);
			
			
			pkeymap.put((String) pkeystr, vlist.poll());						
		}
		
		return pkeymap;
		
	}

	public static boolean upsertFromRecMap(ConnectionSource csrc, String fulltabname, int pkeycolcount, LinkedHashMap<String, Object> recmap)
	{
		try {
			Connection conn = csrc.createConnection();	
			boolean result = upsertFromRecMap(conn, fulltabname, pkeycolcount, recmap);
			conn.close();
			return result;
			
		} catch (SQLException sqlex) {
			throw new RuntimeException(sqlex);
		}
	}		
	
	public static boolean upsertFromRecMap(Connection conn, String tabname, int pkeycolcount, LinkedHashMap<String, Object> recmap) throws SQLException
	{

		LinkedHashMap<String, Object> pkeycolmap = Util.linkedhashmap();
		
		for(Map.Entry<String, Object> recent : recmap.entrySet())
		{
			pkeycolmap.put(recent.getKey(), recent.getValue());
			
			if(pkeycolmap.size() == pkeycolcount)
				{ break; }
		}
		
		int prevcount = countFromColMap(conn, tabname, pkeycolmap);
		
		Util.massert(prevcount == 1 || prevcount == 0, 
			"Expected exactly 0/1, got %d for pkeymap %s, pkey col count %d, are you sure you have the pkey info correct?", prevcount, pkeycolmap, pkeycolcount);
		
		if(prevcount == 0)
			{ insertFromRecMap(conn, tabname, recmap); }			
		// Gotcha: the number of pkeys is equal to the recmap size, meaning that the pkey is the entire record, there's no update.
		else if(pkeycolcount < recmap.size())
			{ updateFromRecMap(conn, tabname, pkeycolcount, recmap); }	
		
		return true;
	}	

	public static int insertFromRecMap(ConnectionSource csrc, String tabname, LinkedHashMap<String, Object> recmap)
	{
		try {
			Connection conn = csrc.createConnection();
			int incount = insertFromRecMap(conn, tabname, recmap);
			conn.close();
			return incount;
			
		} catch (SQLException sqlex) {
			
			throw new RuntimeException(sqlex);	
		}
		
		
	}
	
	public static int insertFromRecMap(Connection conn, String tabname, LinkedHashMap<String, Object> recmap) throws SQLException
	{
		String formsql = Util.sprintf("INSERT INTO %s ( %s ) VALUES ( %s ) ", 
			tabname, Util.join(recmap.keySet(), " , "), nQuestionMarkStr(recmap.size()));
		
		
		// Util.pf("INSERT: %s\n", formsql);
		
		int upcount = CoreDb.execSqlUpdatePrepared(conn, formsql, new Vector<Object>(recmap.values()));
		
		Util.massert(upcount == 1, "Expected exactly 1 update result, got %d", upcount);
		
		return upcount;
	}		

	public static int deleteFromColMap(ConnectionSource csrc, String tabname, LinkedHashMap<String, Object> colmap)
	{
		try { 
			Connection conn = csrc.createConnection();
			int delrow = deleteFromColMap(conn, tabname, colmap);
			conn.close();
			return delrow;
		} catch (SQLException sqlex) {
			
			throw new RuntimeException(sqlex);	
		}
	}

	
	public static int deleteFromColMap(Connection conn, String tabname, LinkedHashMap<String, Object> colmap) throws SQLException
	{
		String formsql = Util.sprintf("DELETE FROM %s WHERE ", tabname);
		
		formsql += Util.join(colEqualQmarkList(colmap.keySet()), " AND ");
		
		// Util.pf("DELETE-SQL %s\n", formsql);
		
		int killrow = CoreDb.execSqlUpdatePrepared(conn, formsql, new Vector<Object>(colmap.values()));
		
		return killrow;
	}	

	public static int countFromColMap(Connection conn, String tabname, LinkedHashMap<String, Object> colmap) throws SQLException
	{
		String formsql = Util.sprintf("SELECT count(*) FROM %s WHERE ", tabname);
		
		formsql += Util.join(colEqualQmarkList(colmap.keySet()), " AND ");
		
		// Util.pf("COUNT-QUERY %s\n", formsql);
		
		ResultSet rset = CoreDb.execSqlQueryPrepared(conn, formsql, new Vector<Object>(colmap.values()));
		
		Util.massert(rset.next());
		
		return rset.getInt(1);
	}

	public static int updateFromRecMap(ConnectionSource csrc, String tabname, int numpkey, LinkedHashMap<String, Object> recmap)
	{
		try {
			Connection conn = csrc.createConnection();	
			int numup = updateFromRecMap(conn, tabname, numpkey, recmap);
			conn.close();
			return numup;
			
		} catch (SQLException sqlex) {
			throw new RuntimeException(sqlex);
		}
		
		
	}
	
	public static int updateFromRecMap(Connection conn, String tabname, int numpkey, LinkedHashMap<String, Object> recmap) throws SQLException
	{
		LinkedHashMap<String, Object> pkeymap = Util.linkedhashmap();
		LinkedHashMap<String, Object> loadmap = Util.linkedhashmap();
		
		for(Map.Entry<String, Object> recent : recmap.entrySet())
		{
			Map<String, Object> relmap = (pkeymap.size() < numpkey ? pkeymap : loadmap);
			
			relmap.put(recent.getKey(), recent.getValue());
		}		
		
		String formsql = Util.sprintf("UPDATE %s SET  %s WHERE  %s ", tabname, 
						Util.join(colEqualQmarkList(loadmap.keySet()), " , "), 
						Util.join(colEqualQmarkList(pkeymap.keySet()), " AND ")); 
		
		
		// Util.pf("UPDATE: %s\n", formsql);
		
		Vector<Object> preplist = new Vector<Object>(loadmap.values());
		preplist.addAll(pkeymap.values());
		
		int upcount = CoreDb.execSqlUpdatePrepared(conn, formsql, preplist);
		
		Util.massert(upcount == 1, "Expected exactly 1 update result, got %d", upcount);
		
		return upcount;
	}	

	// Useful for JDBC prepared statements with Where clauses
	public static List<String> colEqualQmarkList(Collection<String> collist)
	{
		return collist.stream().map(k -> Util.sprintf(" %s = ? ", k)).collect(CollUtil.toList());
	}	


	// Useful for JDBC prepared statements
	public static String nQuestionMarkStr(int n)
	{
		List<String> qlist = Util.vector();
		
		while(qlist.size() < n)
			{ qlist.add(" ? "); }
		
		return Util.join(qlist, ",");
	}			


	// This is going to fail if the connection is not actually a Sqlite connector
	public static Set<String> getLiteTableNameSet(ConnectionSource litedb)
	{
		String sql = "SELECT name FROM sqlite_master WHERE type='table'";
		
		return Util.map2set(QueryCollector.buildAndRun(sql, litedb).recList(), amap -> amap.getSingleStr());

	}		


	// Map of index name to underlying table name for all the indexes in the DB
	// This will include indexes that are auto-generated by SQLite, for example sqlite_autoindex_my_test_1
	public static Map<String, String> getLiteIndexMap(ConnectionSource litedb)
	{
		String sql = "SELECT name, tbl_name FROM sqlite_master WHERE type='index'";
		
		return Util.map2map(
				QueryCollector.buildAndRun(sql, litedb).recList(), 
				amap -> amap.getStr("name"),
				amap -> amap.getStr("tbl_name")
			);
	}

	public static List<String> getIndexColumnList(ConnectionSource litedb, String indexname)
	{
		String query = Util.sprintf("SELECT name FROM pragma_index_info('%s') ORDER BY seqno", indexname);

		return Util.map2list(QueryCollector.buildAndRun(query, litedb).recList(), amap -> amap.getSingleStr());
	}



	public static Set<String> getLiteViewNameSet(ConnectionSource litedb)
	{
		String sql = "SELECT name FROM sqlite_master WHERE type='view'";		
		return Util.map2set(QueryCollector.buildAndRun(sql, litedb).recList(), amap -> amap.getSingleStr());
	}			
	

	public static synchronized Properties getSqliteConfigProps()
	{
		if(__SQLITE_CONFIG == null)
		{
			__SQLITE_CONFIG = new org.sqlite.SQLiteConfig();
			__SQLITE_CONFIG.enforceForeignKeys(true);  
		}
		
		return __SQLITE_CONFIG.toProperties();
	}

	// SQLite DB in a file. This is mostly used for testing, more "controlled" DBs have their own classes
	public static class ScrapDb implements ConnectionSource
	{
		public final File theFile; 
		
		public ScrapDb(File thefile, boolean mustexist)
		{
			theFile = thefile;
			
			if(mustexist)
			{ 
				Util.massert(theFile.exists(), 
					"File %s does not exist, you must create before using", theFile.getAbsolutePath());
			}
			else 
			{
				Util.massert(!theFile.exists(),
					"File %s already exists", theFile);
			}
		}
		
		public ScrapDb(File thefile)
		{
			this(thefile, true);
		}	
		
		public String toString()
		{
			return Util.sprintf("%s::%s", 
				this.getClass().getSimpleName(), theFile.getAbsolutePath());
		}
		
		public Connection createConnection() throws SQLException
		{
			maybeLoadDbClassInfo(JDBC.class.getName());		
					
			return DriverManager.getConnection(geJdbcUrl(), getSqliteConfigProps());
		}
		
		private String geJdbcUrl()
		{
			return Util.sprintf("jdbc:sqlite:%s", getSqlDbPath());
		}
		
		private String getSqlDbPath()
		{
			return theFile.getAbsolutePath();
		}
		
		public QueryCollector runQuery(String sql)
		{
			return (new QueryCollector(sql)).doQuery(this);
		}
	}	

	// }}}	

}
