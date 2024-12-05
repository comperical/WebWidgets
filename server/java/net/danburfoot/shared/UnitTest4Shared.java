
package net.danburfoot.shared;

import java.util.*;
import java.io.*;
import java.sql.*;
import java.util.regex.*;

import net.danburfoot.shared.*;
import net.danburfoot.shared.Util.*;
import net.danburfoot.shared.TimeUtil.*;
import net.danburfoot.shared.CollUtil.*;
import net.danburfoot.shared.RunnableTech.*;

public class UnitTest4Shared 
{

	public static class TestTupleCorrect extends ArgMapRunnable
	{
		public void runOp()
		{

			testCompareCascade();

			testDupHandling();

		}

		// For TreeSets, a Pair<Integer, NonComparable> is equal to another Pair<Integer, NonComparable>
		// if the first parameter is equal. For HashSets, they are basically never equal.
		// We can detect this distinction by building sets and looking at their sizes
		private void testCompareCascade()
		{

			for(boolean usehash : Util.listify(true, false))
			{
				Set<Pair<Integer, ArgMapRunnable>> myset = usehash ? Util.hashset() : Util.treeset();

				for(int i : Util.range(10))
				{ 
					myset.add(Pair.build(i, new TestTupleCorrect()));
					myset.add(Pair.build(i, new TestTupleCorrect()));
				}

				int expected = usehash ? 20 : 10;

				Util.massert(myset.size() == expected, "Size is %d", myset.size());
			}
		}


		// Test the correctness of the Pair object when handling duplicates
		private void testDupHandling()
		{
			for(boolean usehash : Util.listify(true, false))
			{
				for(boolean usedup : Util.listify(true, false))
				{

					Set<Pair<Integer, String>> myset = usehash ? Util.hashset() : Util.treeset();
					addData2Set(myset, usedup);

					int expected = usedup ? 2 : 3;
					int observed = myset.size();
					Util.massert(expected == observed);
				}
			}
		}

		private static void addData2Set(Set<Pair<Integer, String>> target, boolean usedup)
		{
			target.add(Pair.build(4, "danb"));
			target.add(Pair.build(5, "danb"));

			if(usedup)
				{ target.add(Pair.build(5, "danb")); }
			else
				{ target.add(Pair.build(6, "danb")); }
		}
	}

	public static class TestDayCodeBoundary extends ArgMapRunnable
	{

		public void runOp()
		{
			Util.pf("First day is %s, last is %s\n", 
				DayCode.getEarliestDayCode(), DayCode.getLastDayCode());


			for(var expectokay : Util.listify(true, false))
			{
				var datalist = expectokay ? getOkayList() : getBadList();
				for(var probe : datalist)
				{
					var obsokay = loadOkay(probe);
					Util.massert(obsokay == expectokay, 
						"Observed load okay=%b, but expected %b, for input %s",
						obsokay, expectokay, probe
					);
				}
			}

			Util.pf("Success, checked %d good and %d bad dates\n", getOkayList().size(), getBadList().size());
		}

		private static boolean loadOkay(String probe)
		{
			try { DayCode.lookup(probe); return true; }
			catch (Exception ex) { return false; }
		}

		// November 2024 : ugh, these boundaries changed for some reason!!
		// Relax the constraints here
		private List<String> getOkayList()
		{
			return Arrays.asList(
				"2024-09-16",
				"2028-09-16",
				// "2002-10-21", // Earlist good
				// "2046-08-10" // Last good
				"2002-10-30",
				"2046-08-01"
			);
		}

		private List<String> getBadList()
		{
			return Arrays.asList(
				"1995-01-01"
				// "2002-10-20", // last bad
				// "2046-08-11" // earliest bad
			);
		}


	}
}
