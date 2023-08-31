
package net.danburfoot.shared; 

import java.util.*;
import java.io.*;
import java.sql.*;
import java.net.*;
import java.text.SimpleDateFormat;
import java.util.regex.*;

import org.w3c.dom.*;

import net.danburfoot.shared.Util.*;
import net.danburfoot.shared.CoreDb.*;
import net.danburfoot.shared.TimeUtil.*;
import net.danburfoot.shared.FileUtils.*;
import net.danburfoot.shared.RunnableTech.*;

public class RegTest4Shared
{
	static String getMiscDirPropName()
	{
		return Util.sprintf("%s.misc_dir", RegTest4Shared.class.getPackageName());
	}

	static File getMiscDataDir()
	{	
		String miscdirstr = System.getProperty(getMiscDirPropName());
		Util.massert(miscdirstr != null, "Failed to find expected system property %s", getMiscDirPropName());

		File miscdir = new File(miscdirstr);
		Util.massert(miscdir.exists() && miscdir.isDirectory(), "Directory %s either does not exist, or is not a directory", miscdir);
		return miscdir;
	}

	private static File getChildFile(File parent, String kidname)
	{
		Util.massert(parent.exists() && parent.isDirectory(), "Problem with parent directory %s", parent);
		String newpath = Util.sprintf("%s%s%s", parent.getAbsolutePath(), File.separator, kidname);
		return new File(newpath);
	}

	private static File getTempDataDir()
	{
		File tempdir = getChildFile(getMiscDataDir(), "tempshared");
		if(!tempdir.exists())
			{ tempdir.mkdirs(); }

		return tempdir;
	}


	public static class TestReadWriteUtil extends ArgMapRunnable
	{
		public void runOp()
		{
			File miscdir = getTempDataDir();


			Random r = new Random();
			List<Long> datalist = Util.vector();
			for(int i : Util.range(1_000_000))
				{ datalist.add(r.nextLong()); }


			File tempfile = getChildFile(getTempDataDir(), "big_read.txt");
			FileUtils.getWriterUtil().setFile(tempfile).writeLineListE(datalist);

			List<Long> result = Util.map2list(
				FileUtils.getReaderUtil().setFile(tempfile).readLineListE(),
				s -> Long.valueOf(s)
			);

			Util.massert(datalist.equals(result));
			Util.pf("Success, checked read/write for %d records\n", datalist.size());
		}
	}

	public static class TestGzipWrite extends ArgMapRunnable
	{
		public void runOp() throws IOException
		{
			File miscdir = getTempDataDir();

			String dumbline = "aaaaaaaa";
			List<String> datalist = Util.vector();
			for(int i : Util.range(1_000_000))
				{ datalist.add(dumbline); }


			for(boolean isgz : Util.listify(true, false))
			{
				File tempfile = getChildFile(getTempDataDir(), getFileName(isgz));
				FileUtils.getWriterUtil().setFile(tempfile).setGzip(isgz).writeLineListE(datalist);

				long filelen = tempfile.length();
				Util.pf("Got length=%d for file %s\n", filelen, tempfile.getName());

				if(isgz)
					{ Util.massert(filelen < 20_000); }
				else
					{ Util.massert(filelen == datalist.size() * (dumbline.length() + 1)); }

			}

			for(boolean isgz : Util.listify(true, false))
			{
				File tempfile = getChildFile(getTempDataDir(), getFileName(isgz));
				ReaderUtil rutil = FileUtils.getReaderUtil().setFile(tempfile).setGzip(isgz);
				List<String> reload = rutil.readLineListE();
				Util.massert(reload.equals(datalist));
				Util.pf("Success, checked %d lines for GZ=%s\n", reload.size(), isgz);
			}
		}

		private static String getFileName(boolean isgz)
		{
			return TestGzipWrite.class.getSimpleName() + (isgz ? ".mgz" : ".txt");
		}
	}	

	public static class TestBasicLiteDb extends ArgMapRunnable
	{
		ScrapDb _dbItem;

		public void runOp()
		{

			File dbfile = getChildFile(getTempDataDir(), TestBasicLiteDb.class.getSimpleName()+".db");
			if(dbfile.exists())
				{ dbfile.delete(); }

			_dbItem = new ScrapDb(dbfile, false);

			setupTable();
			insertData();
			totalIdTest();	
			newIdTest();	
			fullQueryTest();	
			badInsertTest();
		}

		private void setupTable()
		{
			String create = "CREATE TABLE test_info (id int, message varchar(20), primary key(id))";
			CoreDb.execSqlUpdate(create, _dbItem);
			Util.pf("Created DB table okay\n");
		}

		private void insertData()
		{
			int numinsert = 1_000;

			for(int i : Util.range(numinsert))
			{
				CoreDb.upsertFromRecMap(_dbItem, "test_info", 1, CoreDb.getRecMap(
					"id", i,
					"message", "MessageIdx"+i
				));
			}

			Util.pf("Inserted %d records okay\n", numinsert);
		}		

		private void newIdTest()
		{
			int newid = CoreDb.getNewId(_dbItem, "test_info", "id");
			Util.massert(newid == 1000);
			Util.pf("Got newId=%d as expected\n", newid);
		}

		private void fullQueryTest()
		{
			String sql = "SELECT * FROM test_info ORDER BY id";
			QueryCollector qcol = QueryCollector.buildAndRun(sql, _dbItem);
			List<Integer> observed = Util.map2list(qcol.recList(), amr -> amr.getInt("id"));
			List<Integer> expected = Util.range(1_000);
			Util.massert(observed.equals(expected));
			Util.pf("Full query test worked as expected\n");
		}



		private void badInsertTest()
		{
			for(boolean isbad : Util.listify(true, false))
			{
				boolean hiterror;
				int testid = isbad ? 5 : 50_000;

				try {
					CoreDb.insertFromRecMap(_dbItem, "test_info", CoreDb.getRecMap(
						"id", testid,
						"message", "BadInsertTest"
					));
					hiterror = false;
				} catch (Exception ex) {
					hiterror = true;
				}

				Util.massert(hiterror == isbad, "Have error=%b but isbad=%b", hiterror, isbad);
			}

			Util.pf("Insert test worked as expected\n");
		}

		private void totalIdTest()
		{
			String query = "SELECT count(*) as numrec, sum(id) as idtotal FROM test_info";
			QueryCollector qcol = QueryCollector.buildAndRun(query, _dbItem);
			int idtotal = qcol.getSingleArgMap().getInt("idtotal");
			int numrec = qcol.getSingleArgMap().getInt("numrec");
			Util.massert(numrec == 1000);
			Util.massert(idtotal == 999 * 500, "ID total is %d, expected %d", idtotal, 999*500);
			Util.pf("Basic query check ran okay\n");
		}
	}
}
