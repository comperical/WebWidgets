
package net.danburfoot.shared; 
import net.danburfoot.shared.CollUtil.*;

import java.text.*; 
import java.util.*; 
import java.util.regex.*; 
import java.io.*; 
import java.util.concurrent.*;
import java.util.function.*;

import java.net.InetAddress;

// This file should be height-0, ie, no dependence on any libraries or other DCB code!!

public class Util
{ 
	public static final String ALL_CODE = "ALL";
	
	// Use dbpf(...), will only print when this is true.
	public static boolean DEBUGPF = false;
	
	public static boolean OKAY_SPRINTF = true;
	
	public static boolean READY_2_CHECK = false;
	
	public static boolean SYSCALL_OKAY = true;
	
	public static LinkedList<Integer> CHECK_OKAY_LIST = Util.linkedlistify();	
	
	public static String DUMB_SEP = "____";

	/**
	 * Print information about the amount of memory available to the virtual machine. 
	 */ 
	public static void showMemoryInfo()
	{ 
		Runtime rt = Runtime.getRuntime(); 
		pf("Maxx : \t %d Kb\n", rt.maxMemory() / 1024); 
		pf("Free : \t %d Kb\n", rt.freeMemory() / 1024); 
		pf("Totl : \t %d Kb\n", rt.totalMemory() / 1024); 
		pf("Used : \t %d Kb\n", (rt.totalMemory()-rt.freeMemory()) / 1024); 
	} 
	
	public static long getUsedMemory()
	{
		Runtime rt = Runtime.getRuntime();
		return rt.totalMemory()-rt.freeMemory();
	}
	

	public static long getFileLengthBits(String path)
	{
		File f = new File(path); 
		return f.length() * 8; 
	} 
	
	public static String sprintf(String formatCode, Object... args)
	{
		if(!OKAY_SPRINTF)
			{ throw new RuntimeException("Called sprintf in high-performance mode!!"); }
		
		ByteArrayOutputStream baos = new ByteArrayOutputStream();
		(new PrintStream(baos)).printf(formatCode, args);
		// baos.close(); Java API docs sez: closing ByteArrayOutputStream has no effect
		return baos.toString();
	}
	
	public static void debugpf(String x, Object... vargs)
	{
		if(DEBUGPF)
			{ pf(x, vargs); }
	}
	
	public static void pferr(String x, Object... vargs)
	{
		System.err.printf(x, vargs);	
	}
	
	public static void pf(String x, Object... vargs)
	{
		System.out.printf(x, vargs);
	}
	
	public static void maybepf(boolean dopf, String x, Object... vargs)
	{
		if(dopf)
			{ pf(x, vargs); }
	}

	public static void massertEq(double a, double b, double tolerate)
	{
		massert(Math.abs(a - b) < tolerate, "1st arg=%.04f, 2nd arg=%.04f", a, b);
		
	}
	
	public static void massertEq(int a, int b)
	{
		massert(a == b, "1st arg=%d, 2nd arg=%d", a, b);
	}
	
	public static void massertSmall(double x, double tol)
	{
		massert(Math.abs(x) < tol, "Value is too large: %.03f", x);
	}
	
	public static void massertLess(double a, double b)
	{
		massert(a < b, "Error, A=%.03f > B=%.03f", a, b);
		
	}
	
	public static <T> void massertFunc(T item, Predicate<T> mustbetrue, String pfmessg, Object... pfargs)
	{
		massert(mustbetrue.test(item), pfmessg, item, pfargs);
	}
	
	// This puts the two objects compared into the varargs so you don't have to retype them.
	public static void massertEqual(Object a, Object b, String pfmessg, Object... pfargs)
	{
		if(!a.equals(b))
		{
			Object[] vargar = new Object[pfargs.length+2];
			
			vargar[0] = a; 
			vargar[1] = b;
			
			for(int i : Util.range(pfargs.length))
				{ vargar[i+2] = pfargs[i]; }
			
			throw new RuntimeException("\nEquality Assertion failed: " + sprintf(pfmessg, vargar));			
		}
	}
	
	public static void massert(boolean t)
	{
		massert(t, "Generic Assertion");
	}
	
	public static void massert(boolean t, String pfmessg, Object... pfargs)
	{
		if(!t)	
		{
			// System.out.printf("\n\n");	
			throw new RuntimeException("\nassertion failed: " + sprintf(pfmessg, pfargs));
		}		
	}
	
	public static <T> List<T> sublist(List<T> mainlist, int startpos)
	{
		return sublist(mainlist, startpos, mainlist.size());	
	}
	
	
	public static <T> List<T> sublist(List<T> mainlist, int startpos, int endpos)
	{
		List<T> slist = Util.vector();
		
		for(int i = startpos; i < endpos; i++)
		{
			slist.add(mainlist.get(i));	
		}
		
		return slist;
	}
	
	public static <T> T optOrB(Optional<T> opt, T defval)
	{
		return opt.isPresent() ? opt.get() : defval;	
	}
	
	public static <T> T ifANullThenB(T first, T defval)
	{
		return (first == null ? defval : first);	
	}
	
	public static <T> T xIfTestElseY(T x, Predicate<T> pred, T y)
	{
		return pred.test(x) ? x : y;
	}	
	
	// If a is null, return null, else return result of applying func to a.
	public static <A,B> B passThruNull(A a, Function<A, B> myfunc)
	{
		return (a == null ? null : myfunc.apply(a));
	}		
	
		
	public static <T> T randomElement(List<T> mylist)
	{
		int rid = (int) (mylist.size() * Math.random());
		return mylist.get(rid);
	}
	
	public static <A, B> ConcurrentHashMap<A, B> conchashmap()
	{
		return new ConcurrentHashMap<A, B>();
	}
	
	public static <A, B> TreeMap<A,B> treemap()
	{
		return new TreeMap<A,B>();
	}
	
	public static <A, B> TreeMap<A,B> treemap(Function<A, String> sortfunc)
	{
		Comparator<A> sortcomp = new Comparator<A>() {
			
			public int compare(A arg1, A arg2)
			{
				String s1 = sortfunc.apply(arg1);
				String s2 = sortfunc.apply(arg2);
				
				return s1.compareTo(s2);
			}
		};
		
		return new TreeMap<A,B>(sortcomp);
	}	
	
	
	public static <A, B> TreeMap<A,B> treemap(Map<A, B> initmap)
	{
		return new TreeMap<A,B>(initmap);
	}	
	
	
	public static <A, B> LinkedHashMap<A,B> linkedhashmap()
	{
		return new LinkedHashMap<A,B>();
	}
	
	public static <A, B> HashMap<A, B> hashmap()
	{
		return new HashMap<A, B>();
	}
	
	public static <A extends Enum<A>, B> EnumMap<A, B> enummap(Class<A> enumclass)
	{
		return new EnumMap<A, B>(enumclass);
		
	}

	public static <A, B> boolean setdefault(Map<A, B> themap, A a, B b)
	{
		if(themap.containsKey(a))
			{ return false; }
		
		themap.put(a, b);
		return true;
	}
	
	public static <A> void addNoDup(Set<A> theset, A a)
	{
		Util.massert(!theset.contains(a), "Object %s already present in set", a);	
		theset.add(a);
	}
	
	public static <A> void putNoDup(Set<A> theset, A a)
	{
		Util.massert(!theset.contains(a), "Element %s already present in set", a);
		theset.add(a);
	}
	
	public static <A, B> void putNoDup(Map<A, B> themap, A a, B b)
	{
		Util.massert(!themap.containsKey(a), "Key %s already present in map", a);
		themap.put(a, b);
	}
	
	public static <A, B> B getNoNull(Map<A, B> themap, A a)
	{
		B theval = themap.get(a);
		
		massert(theval != null,
				"Key %s not found in Map, keyset is %s", a, themap.keySet());
		
		return theval;
	}
	
	
	@SuppressWarnings("unchecked")	
	public static <A> A cast(Object o)
	{
		return (A) o;
	}

	
	public static <A> TreeSet<A> treeset()
	{
		return new TreeSet<A>();
	}
	
	public static <A> TreeSet<A> treeset(Collection<A> prevcol)
	{
		return new TreeSet<A>(prevcol);
	}	
	
	public static <A> HashSet<A> hashset()
	{
		return new HashSet<A>();
	}

	public static <A> ArrayList<A> arraylist()
	{
		return new ArrayList<A>();
	}

	public static <A> ArrayList<A> arraylist(Collection<A> fromcol)
	{
		return new ArrayList<A>(fromcol);
	}	
	
	public static <A> Vector<A> vector()
	{
		return new Vector<A>();
	}
	
	public static <A> Vector<A> vector(Collection<A> fromcol)
	{
		return new Vector<A>(fromcol);
	}	
	
	public static <A> LinkedList<A> linkedlist()
	{
		return new LinkedList<A>();
	}
	
	@SafeVarargs
	public static <A> List<A> hardlist(A... optcol)
	{
		ArrayList<A> al = arraylist();
		
		for(A a : optcol)
			{ al.add(a); }
		
		return Collections.unmodifiableList(al);
	}	
	
	
	public static <A> LinkedList<A> linkedlistify(Collection<A> fromcol)
	{
		LinkedList<A> ll = linkedlist();
		for(A a : fromcol)
			{ ll.add(a); }
		return ll;
	}
	
	@SafeVarargs
	public static <A> LinkedList<A> linkedlistify(A... elems)
	{
		LinkedList<A> ll = linkedlist();
		for(A a : elems)
			{ ll.add(a); }
		return ll;
	}
		
	
	@SafeVarargs
	public static <A> Vector<A> listify(A... elems)
	{
		Vector<A> mv = vector();
		for(A a : elems)
			{ mv.add(a); }
		return mv;
	}
	
	@SafeVarargs
	public static <A extends Comparable<A>> TreeSet<A> setify(A... elems)
	{
		TreeSet<A> mv = treeset();
		for(A a : elems)
			{ mv.add(a); }
		return mv;
	}
	
	@SafeVarargs
	public static <A extends Comparable<A>> Set<A> hardset(A... elems)
	{
		return Collections.unmodifiableSet(setify(elems));		
	}
		
	@SafeVarargs
	public static <A extends Enum<A>> Set<A> hardenumset(A... elems)
	{
		// If Elems is empty, you actually CANNOT get the type.
		// It might be that the correct thing to do here is throw an exception
		if(elems.length == 0)
		{
			return Collections.emptySet();	
		}
		
		EnumSet<A> eset = EnumSet.of(elems[0]);
		
		for(int i = 1; i < elems.length; i++)
			{ eset.add(elems[i]); }
		
		return Collections.unmodifiableSet(eset);
	}	
	
	public static boolean AimpliesB(boolean a, boolean b)
	{
		return !a || b;
	}
	
	public static <T> void incHitMap(Map<T, Double> relmap, T k, double toadd)
	{
		double c = relmap.containsKey(k) ? relmap.get(k) : 0;
		relmap.put(k, c+toadd);
	}	
	
	
	public static <T> int incHitMap(Map<T, Integer> relmap, T k)
	{
		return incHitMap(relmap, k, 1);	
	}
	
	public static <T> int incHitMap(Map<T, Integer> relmap, T k, int toadd)
	{
		Util.massert(CHECK_OKAY_LIST.size() <= 1, 
			"Attempt to incHitMap but check flag is activated");
		
		int c = relmap.containsKey(k) ? relmap.get(k) : 0;
		relmap.put(k, c+toadd);
		return c;
	}
	
	public static <T> int lookupHitMap(Map<T, Integer> relmap, T k)
	{
		Integer result = relmap.get(k);
		return (result == null ? 0 : result);
	}
	
	public static <T> SortedMap<T, Integer> getCountMap(Collection<T> itemcol)
	{
		SortedMap<T, Integer> hitmap = Util.treemap();
		
		for(T oneitem : itemcol)
		{
			incHitMap(hitmap, oneitem);	
		}
		
		return hitmap;
	}


	public static <T> T getLast(List<T> x)
	{
		return x.get(x.size()-1);
	}
	
	public static <T> T getLast(T[] x)
	{
		return x[x.length-1];
	}	

	@SuppressWarnings("unchecked")	
	public static String join(Collection data, String glue)
    {
		return join(data.toArray(new Object[]{}), glue);
    }
        
	@SuppressWarnings("unchecked")	
	public static String join(String[] data, String glue)
    {
		return join(Arrays.asList(data), glue);
    }        
        
	@SuppressWarnings("unchecked")	        
    public static String join(Object[] data, String glue)
    {
		return joinSub(data, glue, 0);
    }
        
	@SuppressWarnings("unchecked")	        
    public static String varjoin(String glue, Object... varargs)
    {
		return joinSub(varargs, glue, 0);
    }        
        
        
    public static String joinButFirst(Object[] data, String glue)
    {
		return joinSub(data, glue, 1);
    }
    
        private static String joinSub(Object[] data, String glue, int offset)
        {
                StringBuilder sb = new StringBuilder();
                
                // StringBuffer sb = new StringBuffer();
                
                for(int i = offset; i < data.length; i++)
                {
                        sb.append(data[i].toString());
                        
                        if(i < data.length-1)
                                sb.append(glue);
                }
                return sb.toString();
        }
        
        public static double curtime()
        {
        	return System.currentTimeMillis();	
        }
        
        public static void sleepEat(long millis)
        {
        	
        	try { Thread.sleep(millis); }
        	catch (InterruptedException intex) { throw new RuntimeException(intex); }
        }
        
        public static void sleep4Sec(int numsec)
        {
        	try { Thread.sleep(numsec * 1000L); }
        	catch (InterruptedException intex) { throw new RuntimeException(intex); }
        }
        
        public static List<Pair<Integer, Integer>> getCrossProductRange(int Imax, int Jmax)
        {
        	List<Pair<Integer, Integer>> pairlist = Util.vector();
        	
        	for(int i = 0; i < Imax; i++)
        	{
        		for(int j = 0; j < Jmax; j++)
        			{ pairlist.add(Pair.build(i, j)); }	
        	}
        	
        	return pairlist;        	
        	
        }
        
    public static List<Pair<Integer, Integer>> getArrayPairRange(Object[][] twoD)
    {
		return getCrossProductRange(twoD.length, twoD[0].length);
    }
        
    public static List<Integer> range(int s, int n)
    {
		List<Integer> x = vector();
		
		for(int i = s; i < n; i++)
			{ x.add(i); }
		
		return x;        	
    }
        
	public static List<Integer> range(int n)
	{
		return range(0, n);
	}
	
	public static Iterable<Integer> xrange(int n)
	{
		return xrange(0, n);	
	}
	
	public static Iterable<Integer> xrange(int s, int n)
	{
		Iterator<Integer> myit = new Iterator<Integer>()
		{
			int curpos = s;
			int maxval = n;
			
			public Integer next()
			{
				int cp = curpos;
				curpos++;
				return cp;
			}
			
			public boolean hasNext()
			{
				return curpos < maxval;	
			}
			
		};
		
		return new Iterable<Integer>()
		{
			public Iterator<Integer> iterator() { return myit; }
		};
	}	
	
	
	public static List<Integer> range(Collection c)
	{
		return range(c.size());	
	}
	
	public static boolean checkOkay(String promptMssg)
	{
		System.out.printf("\n%s ? [yes/NO] ", promptMssg);			
		
		Scanner sc = new Scanner(System.in);
		String input = sc.nextLine();
		sc.close();
		
		return "yes".equals(input.trim());
	}
	
	
	public static boolean checkOkay(Scanner sc, String promptMssg)
	{
		System.out.printf("\n%s ? [yes/NO] ", promptMssg);			
		
		String input = sc.nextLine();
		
		return "yes".equals(input.trim());
	}	
	
	
	public static String getUserInput()
	{
		Scanner sc = new Scanner(System.in);
		String input = sc.nextLine();
		sc.close();
		
		return input;
	}
	

	
	public static String shrink(String s, int maxlen)
	{
		int n = s.length() < maxlen ? s.length() : maxlen;
		
		return s.substring(0, n);
	}
	
	// Here the new phase must be absolutely greater than the old phase.	
	public static <T extends Comparable<T>> void assertAdvanceHard(SortedSet<T> phaseset, T newphase)
	{
		massert(phaseset.isEmpty() || newphase.compareTo(phaseset.last()) > 0,
				"Phase %s added out of order, phaseset is %s",
				newphase, phaseset);
		
		phaseset.add(newphase);
	}
		
	// Here the newphase can be repeated
	public static <T extends Comparable<T>> void  assertAdvanceSoft(SortedSet<T> phaseset, T newphase)
	{
		massert(phaseset.isEmpty() || newphase.compareTo(phaseset.last()) >= 0,
			"Phase %s added out of order, phaseset is %s",
			newphase, phaseset);
		
		phaseset.add(newphase);
	}	
	
	public static <A> List<A> spanSlice(List<A> biglist, int S, int W)
	{
		return slice(biglist, Pair.build(S, S+W));
	}
	
	
	public static <A> List<A> slice(List<A> biglist, Pair<Integer, Integer> minmax)
	{
		List<A> sublist = Util.vector();
		
		for(int i : Util.range(minmax._1, minmax._2))
		{
			sublist.add(biglist.get(i));	
		}
		
		return sublist;
	}
	
	public static <A, B> void apply2Val(Map<A, B> themap, A thekey, Function<B, B> thefunc)
	{
		B oldval = themap.get(thekey);
		
		B newval = thefunc.apply(oldval);
		
		themap.put(thekey, newval);
			
	}
	
	public static <A> Pair<A, A> swapIfTrue(A left, A rght, boolean condition)
	{
		return condition ? Pair.build(rght, left) : Pair.build(left, rght);
	}

	
	public static <A> int countPred(Collection<A> mycol, Predicate<A> mypred)
	{	
		return mycol
			.stream()
			.filter(mypred)
			.collect(CollUtil.summingInt(x -> 1));
	}
	
	public static <A> boolean all(Collection<A> mycol, Predicate<A> mypred)
	{
		return !any(mycol, mypred.negate());
	}
	
	public static <A> boolean any(Collection<A> mycol, Predicate<A> mypred)
	{
		for(A item : mycol)
		{
			if(mypred.test(item))
				{ return true; }
		}
		
		return false;
	}	
	
	
	public static <A> List<A>  filter2list(A[] mycol, Predicate<A> mypred)
	{
		
		return filter2list(Util.listify(mycol), mypred);
	}	
	
	public static <A> List<A>  filter2list(Collection<A> mycol, Predicate<A> mypred)
	{
		// Util.massert(FILTER_OKAY_LIST.size() <= 1, "Attempt to use slow filter2list in hotspot region");
		
		return mycol.stream()
				.filter(mypred)
				.collect(CollUtil.toList());
	}		
	
	public static <A> Set<A>  filter2set(A[] mycol, Predicate<A> mypred)
	{
		return filter2set(Util.listify(mycol), mypred);
	}
	
	public static <A> Set<A>  filter2set(Collection<A> mycol, Predicate<A> mypred)
	{
		Set<A> subset = Util.treeset();
		
		for(A myitem : mycol)
		{
			if(mypred.test(myitem))
				{ subset.add(myitem); }
		}
		
		return subset;
	}	
	
	
	public static <A, B> B reduce(Collection<A> mycol, B initval, Function<Pair<B, A>, B> myfunc)
	{	
		B myval = initval;
		
		for(A item : mycol)
		{
			myval = myfunc.apply(Pair.build(myval, item));
		}
		
		return myval;
	}
	
	public static <A, B> B a2b(A item, Function<A, B> myfunc)
	{
		return myfunc.apply(item);
	}			
	
	public static <A, B, C> SortedMap<B, C>  map2map(A[] mycol, Function<A, B> keyfunc, Function<A, C> valfunc)
	{
		return map2map(Util.listify(mycol), keyfunc, valfunc);
	}		
	
	
	public static <A, B, C> SortedMap<B, C>  map2map(Collection<A> mycol, Function<A, B> keyfunc, Function<A, C> valfunc)
	{
		SortedMap<B, C> mymap = Util.treemap();
		
		for(A item : mycol)
			{ mymap.put(keyfunc.apply(item), valfunc.apply(item)); }
		
		return mymap;
	}	
	
	public static <A, B extends Comparable<B>> B min(Collection<A> mycol, Function<A, B> func)
	{
		return minzip(mycol, func)._2;
	}
	
	public static <A, B extends Comparable<B>> Pair<A, B> minzip(Collection<A> mycol, Function<A, B> func)
	{
		Util.massert(!mycol.isEmpty(), "Attempt to take min of empty list");
				
		A curitm = mycol.iterator().next();
		B curmin = func.apply(curitm);
		
		for(A oneitem : mycol)
		{
			B nextval = func.apply(oneitem);
			
			if(nextval.compareTo(curmin) < 0)
			{ 
				curmin = nextval; 
				curitm = oneitem;	
			}
		}
		
		return Pair.build(curitm, curmin);
	}
	
	
	public static <A> void foreach(A[] mycol, Consumer<A> func)
	{
		foreach(Util.listify(mycol), func);
	}

	public static <A> void foreach(Collection<A> mycol, Consumer<A> func)
	{
		for(A item : mycol)
		{
			func.accept(item);
		}
	}

	public static <A, B> List<B>  map2list(A[] mycol, Function<A, B> func)
	{
		return map2list(listify(mycol), func);
	}
	
	public static <A, B> List<B>  map2list(Collection<A> mycol, Function<A, B> func)
	{
		return mycol
			.stream()
			.map(a -> func.apply(a))
			.collect(CollUtil.toList());
	}
	
	public static <A,B> Set<B>  map2set(Collection<A> mycol, Function<A, B> func)
	{
		Set<B> bset = Util.treeset();
		
		for(A myitem : mycol)
		{
			bset.add(func.apply(myitem));
		}
		
		return bset;
	}	
	
	
	public static <A> A  filter2Single(Collection<A> mycol, Predicate<A> mypred)
	{
		List<A> onelist = filter2list(mycol, mypred);
		
		Util.massertEqual(onelist.size(), 1,
			"Expected single element but got %d", onelist.size());
		
		return onelist.get(0);
	}	
	
	public static <A> A  filter2Single(A[] mycol, Predicate<A> mypred)
	{
		return filter2Single(Util.listify(mycol), mypred);
	}		
	
	public static <A, B> Optional<B> opt2opt(Optional<A> myopt, Function<A, B> func)
	{
		return myopt.isPresent() ? 
				Optional.of(func.apply(myopt.get())) :
				Optional.empty();
	}
	
	public static <A> A optOrDef(Optional<A> myopt, A def)
	{
		return myopt.isPresent() ? myopt.get() : def;
	}
		
	public static <A> List<A> flatten(Collection<? extends Collection<A>> colcol)
	{
		List<A> flatlist = vector();
		
		for(Collection<A> onecol : colcol)
			{ flatlist.addAll(onecol); }
		
		return flatlist;
	}	
	
	

	
	
	@SuppressWarnings("unchecked")	        
	public static <T> void runOnCast(Object o, Class<T> targ, Consumer<T> func)
	{
		try {	
			T t = (T) o;
			func.accept(t);
			
		} catch (ClassCastException ccex) { } 
	}
	
	
	@SuppressWarnings("unchecked")	        
	public static <A, B> Optional<B> optCastRun(Object o, Class<A> targ, Function<A, B> func)
	{
		try {	
			A a = (A) o;
			B b = func.apply(a);
			
			return Optional.of(b);
			
		} catch (ClassCastException ccex) { 
		
			return Optional.empty();
		} 
	}
		
	
	public static <A, B> B applyOrNull(A item, Function<A, B> func)
	{
		return item == null ? null : func.apply(item);	
	}
	
	public static boolean aIsAllOrB(Object a, Object b)
	{
		return a.toString().equals(ALL_CODE) || a.toString().equals(b.toString());
	}

	// TODO: should be in InspectUtil

	
	@Deprecated
	public static <A>  A getFromListPair(List<A> leftlist, List<A> rghtlist, int pos)
	{
		if(pos < leftlist.size())
			{ return leftlist.get(pos); }
		
		pos -= leftlist.size();
		
		if(pos < rghtlist.size())
			{ return rghtlist.get(pos); }
		
		Util.massert(false,
			"Attempt to dereference position %d with leftsize=%d, rghtsize=%d",
			pos+leftlist.size(), leftlist.size(), rghtlist.size());
		
		return null;
	}
	
        public static <T> List<T> enum2list(Enumeration<T> myenum)
        {
                List<T> mylist = Util.vector();
                
                while(myenum.hasMoreElements())
                {
                        mylist.add(myenum.nextElement());
                }
                
                return mylist;
        }
        
        public static List<String> loadClassNameListFromDir(File directory)
        {
        	LinkedList<String> prefixes = linkedlist();
        	List<String> result = Util.vector();
        	analyzeClassNameDir(directory, result, prefixes);
        	return result;
        }

        private static void analyzeClassNameDir(File mydir, List<String> result, LinkedList<String> toklist)
        {

		Util.massert(mydir.exists() && mydir.isDirectory(),
			"Bad directory file %s", mydir.getAbsolutePath());
		
		for(File subfile : mydir.listFiles())
		{
			if(subfile.isDirectory())
			{	
				toklist.addLast(subfile.getName());
				analyzeClassNameDir(subfile, result, toklist);
				toklist.pollLast();
				continue;
			}
			
			if(!subfile.getAbsolutePath().endsWith(".class"))
				{ continue; }
			
			String subname = subfile.getName().substring(0, subfile.getName().length()-".class".length());
			
			String fqclass = Util.sprintf("%s.%s", Util.join(toklist, "."), subname);
			
			// Util.pf("Found class file %s with toklist %s\n", subfile, toklist);
			//Util.pf("FQ path is %s\n", fqclass);
			result.add(fqclass);
		}
        }

        public static class SyscallWrapper
        {
                String _commLine;
                
                private List<String> _outList = Util.vector();
                private List<String> _errList = Util.vector();
                
                private List<String> _innList = Util.vector();
                
                private boolean _doPrint = false;
                
                public SyscallWrapper(String cline)
                {
                        _commLine = cline;
                }
                
                public static SyscallWrapper build(String cline)
                {
                	return new SyscallWrapper(cline);	
                }
                
                // This should probably be an iterator or something.
                public SyscallWrapper setInputList(List<String> inlist)
                {
                	_innList = inlist;	
                	return this;
                }
                
                public SyscallWrapper setPrint(boolean dp)
                {
                	_doPrint = dp;	
                	return this;
                }
                
                public SyscallWrapper exec(boolean dp) throws IOException
                {
                	setPrint(dp);
                	return exec();
                }
                
                public SyscallWrapper exec() throws IOException
                {
                	Util.massert(SYSCALL_OKAY, "Attempt to run syscall %s in no-syscall mode", _commLine);                	
                	
                    syscall(_commLine, _innList, _outList, _errList, _doPrint);
                    
                    return this;                	
                }
                
                public SyscallWrapper execE()
                {
                	try { return exec(); }
                	catch(IOException ioex) { throw new RuntimeException(ioex); }
                }
                
                public boolean hasErrorInfo()
                {
                        return !_errList.isEmpty();
                }
                
                public List<String> getErrList()
                {
                	return Collections.unmodifiableList(_errList);	
                }
                
                public List<String> getOutList()
                {
                	return Collections.unmodifiableList(_outList);	
                }                
                
        } 
        
        public static Throwable getRootException(Exception ex)
        {
        	Throwable g = ex;
        	
        	for(int i : Util.range(40))
        	{
        		if(g.getCause() == null)
        			{ return g;}
        		
        		g = g.getCause();
        	}
        	
        	throw new RuntimeException("failure");
        	
        }
        
        
        public static boolean syscall(String comm, List<String> inlist, List<String> outlist, List<String> errlist, boolean printfast)
        throws IOException
        {
                boolean hadErr = false;
                
                // using the Runtime exec method:
                Process p = Runtime.getRuntime().exec(comm);

                // Maybe inlist is empty, in that case we open stdin, send nothing, and then close it                
                {
                        PrintWriter pwrite = new PrintWriter(p.getOutputStream());
                        for(String inline : inlist)
                        {
                                pwrite.write(inline);
                                pwrite.write("\n");
                        }
                        pwrite.close();
                }
                
                
                BufferedReader stdInput = new BufferedReader(new InputStreamReader(p.getInputStream()));
                BufferedReader stdError = new BufferedReader(new InputStreamReader(p.getErrorStream()));
                
                String s = null;
                
                // read the output from the command
                //System.out.println("Here is the standard output of the command:\n");
                while ((s = stdInput.readLine()) != null) {
                        //System.out.println(s);
                        outlist.add(s);
                        
                        if(printfast)
                        	{ Util.pf("%s\n", s); }
                }
                
                // read any errors from the attempted command
                // System.out.println("Here is the standard error of the command (if any):\n");
                while ((s = stdError.readLine()) != null) {
                        errlist.add(s);
                        hadErr = true;
                        
                        if(printfast)
                        	{ Util.pferr("%s\n", s); }
                }
                
                // Okay this was probably causing a lot of bugs
                stdInput.close();
                stdError.close();
                
                return hadErr;
        }

        public static <A, B> SortedMap<A, B> pairlist2Map(List<Pair<A, B>> pairlist)
        {
        	SortedMap<A, B> pairmap = Util.treemap();
        	
        	for(Pair<A, B> onepair : pairlist)
        		{ pairmap.put(onepair._1, onepair._2); }
        	
        	return pairmap;
        }
        
        
        public static <T> List<T> getRange(List<T> masterlist, int frominc, int toexc)
        {
        	Vector<T> sublist = vector();
        	
        	for(int i = frominc; i < toexc; i++)
        		{ sublist.add(masterlist.get(i)); }
        	
        	return sublist;
        }
} 
