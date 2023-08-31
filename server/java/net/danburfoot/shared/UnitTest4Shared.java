
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
}	
