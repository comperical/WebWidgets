
package net.danburfoot.shared; 
import net.danburfoot.shared.CollUtil.*;

import java.io.*; 
import java.text.*; 
import java.util.*;

import java.util.stream.*;
import java.util.stream.Collectors;

import java.util.function.*;


public class CollUtil
{
	public static <T> Collector<T,?,List<T>> toList()
	{
		return Collectors.toList();	
	}
	
	public static <T> Collector<T,?,Set<T>> toSet()
	{
		return Collectors.toSet();	
	}	
	
	public static <T> Collector<T,?,T> reducing(T identity, BinaryOperator<T> op)	
	{
		return Collectors.reducing(identity, op);	
	}
	
	public static <T> Collector<T,?,Long> counting()
	{
		return Collectors.counting();	
	}
	
	public static <T,K> Collector<T,?,Map<K,List<T>>> groupingBy(Function<? super T, ? extends K> classifier)
	{
		return Collectors.groupingBy(classifier);	
	}
	
	public static <T,K,A,D> Collector<T,?,Map<K,D>> groupingBy(Function<? super T,? extends K> classifier, Collector<? super T,A,D> downstream)
	{
		return Collectors.groupingBy(classifier, downstream);
	}
	
	public static Collector<CharSequence,?,String>	joining()
	{
		return Collectors.joining();	
	}

	public static Collector<CharSequence,?,String>	joining(CharSequence delimiter)
	{
		return Collectors.joining(delimiter);	
	}
	
	
	public static <T> Collector<T,?,Integer> summingInt(ToIntFunction<? super T> mapper)
	{
		return Collectors.summingInt(mapper);
	}

	public static <T> Collector<T,?,Long> summingLong(ToLongFunction<? super T> mapper)
	{
		return Collectors.summingLong(mapper);
	}	
	
	
	public static <T> Collector<T,?,Double> summingDouble(ToDoubleFunction<? super T> mapper)
	{
		return Collectors.summingDouble(mapper);
	}	
	
	public static <T,K,U> Collector<T,?,Map<K,U>> toMap(Function<? super T,? extends K> keyMapper, Function<? super T,? extends U> valueMapper)
	{
		return Collectors.toMap(keyMapper, valueMapper);	
	}
	
	
	// Orders list so that elements that maximize the function are at the top.
	public static <T> void sortListDescending(List<T> sortme, ToIntFunction<? super T> maxfunc)
	{
		Collections.sort(sortme, (x1, x2) -> maxfunc.applyAsInt(x1) - maxfunc.applyAsInt(x2));	
	}
	
	
	
	// Orders list so that elements that maximize the function are at the top.
	public static <T, K extends Comparable<K>> void sortListByFunction(List<T> sortme, Function<T, K> sortfunc)
	{
		Collections.sort(sortme, (x1, x2) -> sortfunc.apply(x1).compareTo(sortfunc.apply(x2)));	
	}	
	
	// Dedup the collection by the specified function.
	// Preserves original order of collection
	public static <T, K extends Comparable<K>> List<T> distinctByFunction(Collection<T> dedupme, Function<T, K> dupfunc)
	{
		Set<K> prevset = Util.treeset();
		List<T> deduplist = Util.vector();		
		
		for(T item : dedupme)
		{
			K fres = dupfunc.apply(item);
			
			if(prevset.contains(fres))
				{ continue; }
			
			deduplist.add(item);
			prevset.add(fres);
		}
		
		return deduplist;
	}	
		
	
	
	// Orders list so that elements that maximize the function are at the top.
	public static <T> void inPlaceListFilter(List<T> filterme, Predicate<T> acceptfunc)
	{
		List<T> gimplist = filterme
					.stream()
					.filter(t -> acceptfunc.test(t))
					.collect(CollUtil.toList());
					
		filterme.clear();
		filterme.addAll(gimplist);
	}	
	
	// Orders list so that elements that maximize the function are at the top.
	public static <T,R> void inPlaceMapFilter(Map<T, R> filterme, Predicate<T> acceptfunc)
	{
		List<T> filterlist = new ArrayList<T>(filterme.keySet());
		
		for(T onekey  : filterlist)
		{
			if(!acceptfunc.test(onekey))
				{ filterme.remove(onekey); }	
		}
	}	

	// Orders list so that elements that maximize the function are at the top.
	public static <T> void truncateList2Size(List<T> dalist, int maxsize)
	{
		List<T> gimplist = Util.vector();
		
		for(T item : dalist)
		{
			gimplist.add(item);
			
			if(gimplist.size() >= maxsize)
				{ break; }
		}
		
		dalist.clear();
		
		dalist.addAll(gimplist);
		
	}	
	
	
	public static List<List<Integer>> allPermList(int base)
	{
		Util.massert(base <= 8,
			"This method produces a number of lists that is exponential in base argument");
		
		List<List<Integer>> permlist =  buildPermListRec(base);
		
		int listsize = factorial(base+1);

		Util.massertEqual(permlist.size(), listsize,
			"Got %d but expected listsize %d");
		
		return permlist;
	}

	private static List<List<Integer>> buildPermListRec(int nextnum)
	{
		if(nextnum == 0)
		{
			return Util.listify(Util.listify(0));
		}

		List<List<Integer>> bigsublist = buildPermListRec(nextnum-1);
		List<List<Integer>> bigreslist = Util.vector();
		
		for(int inpos = nextnum; inpos >= 0; inpos--)
		{
			for(List<Integer> sublist : bigsublist)
			{
				List<Integer> newlist = Util.vector();
				
				newlist.addAll(sublist);
				
				if(inpos < sublist.size())
					{ newlist.add(inpos, nextnum); }
				else
					{ newlist.add(nextnum); }
				
				bigreslist.add(newlist);
			}
		}
				
		return bigreslist;
	}
	
	// This is a dumb utility method for allPermList(...) method above.
	private static int factorial(int n)
	{
		if(n <= 1)
			{ return 1; }
		
		return n * factorial(n-1);
	}
	
	public static class ToStringComparator<T> implements Comparator<T>
	{
		public int compare(T a, T b)
		{
			return a.toString().compareTo(b.toString());
		}
		
		public boolean equals(T a, T b)
		{
			return a.toString().equals(b.toString());	
		}
	}
	
	
	public static double doubleSum(Collection<? extends Number> numcol)
	{
		double x = 0;
		
		for(Number n : numcol)
			{ x += n.doubleValue(); }
		
		return x;
	}
	
	public static long longSum(Collection<? extends Number> numcol)
	{
		long x = 0L;
		
		for(Number n : numcol)
			{ x += n.longValue(); }
		
		return x;
	}	
	
	public static long longMax(Collection<? extends Number> numcol)
	{
		long m = 0L;
		
		for(Number n : numcol)
			{ m = n.longValue() > m ? n.longValue() : m; }
		
		return m;
	}		
	
	public static  class IndexMap<T extends Comparable<T>>
	{
		private List<T> _directOrder = Util.vector();
		
		private Map<T, Integer> _indexMap = Util.treemap();
		
		public int addIfAbsent(T item)
		{
			Integer prevpos = _indexMap.get(item);
			
			if(prevpos != null)
				{ return prevpos; }
			
			return addItem(item);
		}
		
		public int addItem(T item)
		{
			Util.massert(!_indexMap.containsKey(item),
				"Already added item %s to the index", item);
			
			int pos = _directOrder.size();
			_indexMap.put(item, pos);
			_directOrder.add(item);
			return pos;
		}
		
		public boolean haveItem(T item)
		{
			return _indexMap.containsKey(item);
		}
		
		public T getItemAt(int i)
		{
			return _directOrder.get(i);	
		}
		
		public int getPos4Item(T item)
		{
			return _indexMap.get(item);	
		}
		
		public int size()
		{
			return _directOrder.size();	
		}
		
		public Set<T> getItemSet()
		{
			return Collections.unmodifiableSet(_indexMap.keySet());	
		}
	}
	
	public static int combineSubHash(Object... hashlist)
	{
		int curhash = 5381;
		
		for(Object onesub : hashlist)
		{	
			int hc = onesub.hashCode();
			curhash = ((curhash << 5) + curhash) ^ hc;
		}
		
		return curhash;
	}
	
	
	public static class StatPack<T extends Enum>
	{
		// {{{
		private Map<T, Double> _dataMap = Util.treemap();

		public static <R extends Enum> StatPack<R> build()
		{
			return new StatPack<R>();	
		}
		
		public void inc(T item)
		{
			inc(item, 1);
		}
		
		public void inc(T item, int x)
		{
			inc(item, (double) x);
		}
		
		public void inc(T item, double x)
		{
			Double p = _dataMap.get(item);
			
			p = (p == null ? 0D : p);
			
			_dataMap.put(item, p+x);
		}		
		
		
		public int getInt(T item)
		{
			Double x = _dataMap.get(item);
			
			if(x == null)
				{ return 0; }
			
			int r = (int) Math.round(x);
			
			Util.massert(Math.abs(x - r) < 1e-6,
				"Failed to convert value %.04f into an integer, are you sure it's not a double?", x);
			
			return r;
		}
		
		private boolean isIntOkay(T item)
		{
			Double x = _dataMap.get(item);
			
			if(x == null)
				{ return true; }
			
			int r = (int) Math.round(x);
			
			return Math.abs(x - r) < 1e-6;
		}
		
		public double getDbl(T item)
		{
			Double x = _dataMap.get(item);
			
			return (x == null ? 0D : x);
		}
		
		public void add2Me(StatPack<T> substat)
		{
			for(Map.Entry<T, Double> subent : substat._dataMap.entrySet())
			{
				inc(subent.getKey(), subent.getValue());	
			}
		}
		
		public void printInfo()
		{
			Util.pf("Have %d non-zero stat items:\n", _dataMap.size());
			
			for(T item : _dataMap.keySet())
			{
				if(isIntOkay(item))
				{
					Util.pf("\t%s\t\t%d\n", item, getInt(item));	
				}
				else 
				{
					Util.pf("\t%s\t\t%.04f\n", item, getDbl(item));
				}
			}	
		}
		
		// }}}
	}	
	
	
	public static class LazyLoad<T>
	{
		private Optional<T> _theItem = Optional.empty();
		
		private final Supplier<T> _mySupp;
		
		public LazyLoad(Supplier<T> mysupply)
		{
			_mySupp = mysupply;
		}
		
		public synchronized T get()
		{
			if(!_theItem.isPresent())
			{
				_theItem = Optional.of(_mySupp.get());
			}
			
			return _theItem.get();
		}
	}
	




	public static class Pair<A, B> implements Serializable, Comparable<Pair<A, B>>
	{

		public A _1;
		public B _2;

		public Pair(A a, B b)
		{
			_1 = a;
			_2 = b;
		}
		
		public int compareTo(Pair<A, B> that)
		{
			Comparable<A> ca = Util.cast(_1);
			
			int f = ca.compareTo(that._1);
			
			if(f != 0 || !(_2 instanceof Comparable))
				return f;

			Comparable<B> cb = Util.cast(_2);
			return cb.compareTo(that._2);
		}	

		@Override
		public int hashCode()
		{
			return CollUtil.combineSubHash(_1, _2);
		}
		
		public Pair<B, A> reversePair()
		{
			return Pair.build(_2, _1);
		}
		
		@Override
		public boolean equals(Object t)
		{
			Pair<A, B> that = Util.cast(t);
			return _1.equals(that._1) && _2.equals(that._2);
		}
		
		public String toString()
		{
			return Util.sprintf("[%s, %s]", _1, _2);
		}
		
		public static <A, B> Pair<A, B> build(A a, B b)
		{
			return new Pair<A, B>(a, b);
		}
		
		public static <A, B> Pair<A, B> build(Map.Entry<A, B> mapent)
		{
			return new Pair<A, B>(mapent.getKey(), mapent.getValue());
		}
		
		public static <A, B> List<A> getOneList(Collection<Pair<A, B>> paircol)
		{
			List<A> flist = Util.vector();
			
			for(Pair<A, B> onepair : paircol)
				{ flist.add(onepair._1); }
			
			return flist;
		}
		
		public static <A, B> List<B> getTwoList(Collection<Pair<A, B>> paircol)
		{
			List<B> flist = Util.vector();
			
			for(Pair<A, B> onepair : paircol)
				{ flist.add(onepair._2); }
			
			return flist;
		}		
	}

	public static class Triple<A, B, C> implements Serializable, Comparable<Triple<A, B, C>>
	{

		public A _1;
		public B _2;
		public C _3;
		
		public Triple(A a, B b, C c) 
		{
			_1 = a;
			_2 = b;
			_3 = c;
		}
		
		public int compareTo(Triple<A, B, C> that)
		{		
			{
				Comparable<A> ca = Util.cast(_1);
				
				int f = ca.compareTo(that._1);
				
				if(f != 0 || !(_2 instanceof Comparable))
					{ return f; }
			} {
				
				Comparable<B> cb = Util.cast(_2);
				int g = cb.compareTo(that._2);
				
				if(g != 0 || !(_3 instanceof Comparable))
					{ return g; }
			} {
				Comparable<C> cb = Util.cast(_3);
				return cb.compareTo(that._3);
			}
		}
		
		@Override
		public int hashCode()
		{
			return CollUtil.combineSubHash(_1, _2, _3);
		}
		
		public boolean equals(Object t)
		{
			Triple<A, B, C> that = Util.cast(t);
			return _1.equals(that._1) && _2.equals(that._2) && _3.equals(that._3);
		}
		
		public String toString()
		{
			return Util.sprintf("[%s, %s, %s]", _1, _2, _3);
		}
		
		public static <A, B, C> Triple<A, B, C> build(A a, B b, C c)
		{
			return new Triple<A, B, C>(a, b, c);
		}
	}		
} 
