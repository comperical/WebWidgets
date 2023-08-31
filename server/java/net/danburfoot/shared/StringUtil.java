
package net.danburfoot.shared;

import java.util.*;
import java.io.*;
import java.nio.charset.StandardCharsets;

import java.util.function.*;

import net.danburfoot.shared.CollUtil.*;
import net.danburfoot.shared.FileUtils.*;

public class StringUtil
{
	public static final String ALPHABET_LOWER = "abcdefghijklmnopqrstuvwxyz";
	
	private static final Set<Character> _BASIC_VOWEL = Util.setify('a', 'e', 'i', 'o', 'u');
	
	public static String commify(long x)
	{
		if(x < 0)
			{ return "-" + commify(-x); }
		
		if(x < 1000)
			{ return ""+x;}
		
		long div = x/1000;
		long rem = x%1000;
		
		return commify(div) + "," + StringUtil.padLeadingZeros(rem+"", 3);
	}	
	
	public static String commify(Iterator i)
	{ 
		StringBuffer sb = new StringBuffer(); 
		while(i.hasNext())
		{ 
			sb.append(i.next()); 
			sb.append(i.hasNext() ? "," : "\n"); 
		}
		return sb.toString();  
	} 
		
	public static boolean isCapitalized(String word)
	{
		return Character.isUpperCase(word.charAt(0));		
	}
	
	public static String capitalizeFirst(String word)
	{
		if(word.isEmpty())
			{ return word; }
		
		char c = word.charAt(0);
		return (""+c).toUpperCase() + word.substring(1);
	}
	
	public static String uncapitalizeFirst(String word)
	{
		char c = word.charAt(0);
		return (""+c).toLowerCase() + word.substring(1);
	}
	
	public static String getAcronym(String fullstr)
	{
		StringBuilder sb = new StringBuilder();
		
		for(int i : Util.range(fullstr.length()))
		{
			char c = fullstr.charAt(i);
			if(Character.isUpperCase(c))
				{ sb.append(c); }
		}
		
		return sb.toString();
	}
	
	public static String uncapitalizeTail(String word)
	{
		// ROBERT --> Robert
		return word.charAt(0) + word.substring(1).toLowerCase();
	}	
	
	public static String getTabIndent(int numtab)
	{
		StringBuffer sb = new StringBuffer();
		
		for(int i : Util.range(numtab))
			{ sb.append("\t"); }
		
		return sb.toString();		
	}
	
	public static int getCharCount(List<String> wordlist)
	{
		int t = 0;
		for(String word : wordlist)
			{ t += word.length(); }
		return t;
	}	
	
	// Mixed case means things like "McCain" where the multicaps happens in the 
	// middle of the string.
	public static boolean isMixedCase(String word)
	{
		int cc = capitalCount(word);
		
		if(cc == 0 || cc == word.length())
			{ return false; }
		
		if(isCapitalized(word) && cc == 1)
			{ return false; }
		
		return true;
	}
	
	public static boolean isFullUpperCase(String word)
	{
		return capitalCount(word) == word.length();	
	}
	
	public static int capitalCount(String word)
	{
		int cc = 0;
		
		for(int i = 0; i < word.length(); i++)
		{
			if(Character.isUpperCase(word.charAt(i)))
				{ cc++; }
		}
		
		return cc;
	}
	
	public static String queryStringForm(Map<String, ? extends Object> datamap)
	{
		int jcount = 0;
		StringBuilder sb = new StringBuilder();
		
		for(Map.Entry<String, ? extends Object> me : datamap.entrySet())
		{
			sb.append(me.getKey());
			sb.append("=");
			sb.append(me.getValue());
			
			if(jcount < datamap.size() - 1)
				{ sb.append("&"); }
			
			jcount++;
		}
		
		return sb.toString();
	}
	
	public static String peelBookEndPunc(String collstr)
	{
		return collstr.substring(1, collstr.length()-1);	
	}

	
	// True if c is a basic vowel, 'aeiou'.
	public static boolean isBasicVowel(char c)
	{
		boolean b;
		
		synchronized (_BASIC_VOWEL) 
		{
			b = _BASIC_VOWEL.contains(c);	
		}
		
		return b;
	}	
	
	public static String fastConcat(Object... olist)
	{
		StringBuilder sb = new StringBuilder();
		
		for(Object o : olist)
			{ sb.append(o.toString()); }
		
		return sb.toString();
	}
	
	public static List<String> splitOrEmpty(String orig, String delim)
	{
		return orig.isEmpty() ? 
				Collections.emptyList() :
				Util.listify(orig.split(delim));
	}
	
        public static String peelPrefix(String original, String prefix)
        {
        	Util.massert(original.startsWith(prefix),
        		"Prefix logic error: attempt to peel prefix %s from original string %s", prefix, original);
        	
        	return original.substring(prefix.length());
        }	
	
	
        public static String peelSuffix(String original, String suffix)
        {
        	Util.massert(original.endsWith(suffix),
        		"Suffix logic error: attempt to peel suffix %s from original string %s", suffix, original);
        	
        	
        	return original.substring(0, original.length()-suffix.length());
        }	
	
        public static String lastToken(String full, String spliton)
        {
                String[] toks = full.split(spliton);
                return toks[toks.length-1];
        }
        
        public static String firstToken(String full)
        {
                return firstToken(full, "\t");        
        }
        
        public static String firstToken(String full, String spliton)
        {
                int pos = full.indexOf(spliton);
                return full.substring(0, pos);
        }        
        
	// This should go somewhere else
	public static String latexEscape(String s)
	{
		StringBuilder sb = new StringBuilder();
		
		for(int i = 0; i < s.length(); i++)
		{
			char c = s.charAt(i);
			
			if(c == '$')
				{ sb.append("\\$"); }
			else 
				{ sb.append(c); }
		}
		
		return sb.toString();
	}        
	
	public static boolean hasNonBasicLetter(String s)
	{
		for(int i = 0; i < s.length(); i++)
		{
			int x = (int) s.charAt(i);
			
			boolean basic = ((65 <= x && x <= 90) || (97 <= x && x <= 122));

			if(!basic)
				return true;
		}
		return false;			
		
	}
	
	public static boolean isBasicLetter(char c)
	{
		int x = (int) c;
		
		return (65 <= x && x <= 90) || (97 <= x && x <= 122);
	}
	
	public static boolean hasNonBasicLetterDigit(String s)
	{
		for(int i = 0; i < s.length(); i++)
		{
			int x = (int) s.charAt(i);
			
			boolean basic = ((48 <= x && x <= 57) || (65 <= x && x <= 90) || (97 <= x && x <= 122));

			if(!basic)
				return true;
		}
		return false;			
		
	}	
	
		
	public static boolean hasNonBasicAscii(String s)
	{
		for(int i = 0; i < s.length(); i++)
		{
			int x = (int) s.charAt(i);
			
			if(x >= 128)
				{ return true; }
		}
		return false;	
	}	
	
	public static String basicAsciiVersion(String s)
	{
		StringBuffer sb = new StringBuffer();
		
		for(int i = 0; i < s.length(); i++)
		{
			int x = (int) s.charAt(i);
			
			if(x >= 128)
				{ continue; }			
			
			sb.append(s.charAt(i));
		}
		
		return sb.toString();
	}			
	
	public static String base64Encode(String s)
	{
		Util.massert(!hasNonBasicAscii(s),
			"Found non-basic ASCII in argument string %s, this method is not suitable", s);
		
		try {
			ByteArrayOutputStream baos = new ByteArrayOutputStream();
			OutputStream b64os = Base64.getEncoder().wrap(baos);
			
			b64os.write(s.getBytes(CharSetEnum.USASCII.getCharsetName()));
			
			b64os.close();
			
			return  baos.toString(CharSetEnum.USASCII.getCharsetName());
			
		} catch (IOException ioex) {
			// Should almost never happen
			throw new RuntimeException(ioex);
		}
	}
	
	public static String base64Decode(String base64)
	{
		Util.massert(!hasNonBasicAscii(base64),
			"Found non-basic ASCII in argument string %s, this method is not suitable", base64);
		
		byte[] decoded = Base64.getDecoder().decode(base64);
		return new String(decoded, StandardCharsets.UTF_8);
	}
	
	// Yeah!!
	public static <T> List<Pair<Double, T>> getBigramSortList(Collection<T> targcol, Function<T, String> stringfunc, String targstr)
	{
		List<Pair<Double, T>> rlist = Util.vector(); 
		
		Set<Pair<String, Integer>> baseset = getBigramCharSet(targstr);
		
		// Util.pf("BaseSEt is %s\n", baseset);
		
		for(T onet : targcol)
		{
			Set<Pair<String, Integer>> subset = getBigramCharSet(stringfunc.apply(onet));
			
			// Util.pf("subset for %s is %s\n", stringfunc.apply(onet), subset);
			
			int subsize = subset.size();
			
			subset.retainAll(baseset);
			
			double overlap = subset.size();
			overlap /= (baseset.size() > subsize ? baseset.size() : subsize);
			
			rlist.add(Pair.build(overlap, onet));
		}
		
		CollUtil.sortListByFunction(rlist, xpair -> -xpair._1);
		
		return rlist;
		
	}
        
	
	public static Set<Pair<String, Integer>> getBigramCharSet(String targstr)
	{
		Set<Pair<String, Integer>> baseset = Util.treeset();
		
		for(int i : Util.range(1, targstr.length()))
		{
			String substr = targstr.substring(i-1, i+1).toLowerCase();
			
			baseset.add(Util.range(20)
					.stream()
					.map(x -> Pair.build(substr, x))
					.filter(xpair -> !baseset.contains(xpair))
					.findFirst()
					.get());
		}
		
		return baseset;
	}
	
	public static String multiPadWhite(List<Integer> padlist, Object... varglist)
	{
		List<Object> printlist = Util.listify(varglist);
		
		Util.massertEqual(printlist.size(), padlist.size(),
			"Got 2print size %d but pad size %d");
		
		StringBuffer sb = new StringBuffer();
		
		for(int i : Util.range(printlist))
		{
			String topad = printlist.get(i).toString();
			int trglen = padlist.get(i);
			
			int extrawhite = trglen - topad.length();
			
			sb.append(topad);
		
			for(int w : Util.range(extrawhite))
				{ sb.append(" "); }
		}
		return sb.toString();
	}	
	
	
	public static String padWhiteSpace(String topad, int trglen)
	{
		StringBuffer sb = new StringBuffer();
		sb.append(topad);
		
		while(sb.length() < trglen)
			{ sb.append(" "); }
		
		return sb.toString();
	}
	
	public static String padLeadingZeros(String topad, int reqlen)
	{
		String x = topad;
		
		while(x.length() < reqlen)
			{ x = "0" + x; }
		
		return x;
	}	
	
	public static String trunc2len(String s, int len)
	{
		if(s == null)
			{ return null; }
		
		return s.length() > len ? s.substring(0, len) : s;	
	}
	
	public static String fastcat(Object... olist)
	{
		StringBuilder sb = new StringBuilder();
		
		for(Object o : olist)
			{ sb.append(o.toString()); }
		
		return sb.toString();
	}
	
        public static List<Integer> getUnicodeIntList(String s)
        {
        	List<Integer> ilist = Util.vector();
        	for(int i : Util.range(s.length()))
        	{
        		ilist.add((int) s.charAt(i));
        	}
        	return ilist;
        }

        public static List<String> getUnicodeHexIntList(String s)
        {
        	List<String> ilist = Util.vector();
        	for(int i : Util.range(s.length()))
        	{
        		int c = (int) s.charAt(i);
        		ilist.add(Integer.toHexString(c));
        	}
        	return ilist;
        }	
        
        // This is the standard invocation for transforming Java Enum names 
        // into AWS valid strings. 
        // AWS doesn't allow underscores, Java doesn't allow hyphens, because they look like subtraction
        public static String under2Hyphen(String s)
        {
        	return s.replaceAll("_", "-");	
        }

	
	// lex_id => LexId
	public static String snake2CamelCase(String snakestr)
	{
		return Util.listify(snakestr.split("_"))
				.stream()
				.map(s -> StringUtil.capitalizeFirst(s))
				.collect(CollUtil.joining());
	}
	
	public static String camel2SnakeCase(String camelstr)
	{
		String[] toks = camelstr.split("(?=\\p{javaUpperCase})");
		
		return Util.listify(toks)
				.stream()
				.map(s -> s.toLowerCase())
				.collect(CollUtil.joining("_"));
	}		
	
	public static String camel2Acro(String camelstr)
	{
		String[] toks = camelstr.split("(?=\\p{javaUpperCase})");
		
		return Util.listify(toks)
				.stream()
				.map(s -> s.charAt(0) + "")
				.collect(CollUtil.joining(""));
	}			
	


	// http://stackoverflow.com/questions/607176/java-equivalent-to-javascripts-encodeuricomponent-that-produces-identical-outpu		
	// NB: this method may have performance implications when used excessively.
	public static String encodeURIComponent(String s)
	{
		String result = null;
		
		try
		{
			// Okay, Java's URL Encoder is different from the JS encodeURIComponent
			// in that a couple of things aren't escaped: !
			
			result = java.net.URLEncoder.encode(s, "UTF-8")
							.replaceAll("\\+", "%20")
							.replaceAll("\\%21", "!")
							.replaceAll("\\%27", "'")
							.replaceAll("\\%28", "(")
							.replaceAll("\\%29", ")")
							.replaceAll("\\%7E", "~");
		}
		
		// This exception should never occur.
		catch (UnsupportedEncodingException e)
		{
			result = s;
		}
		
		return result;
	}  
	
	// http://stackoverflow.com/questions/2632175/java-decoding-uri-query-string
	public static String decodeURIComponent(String s)
	{
		try
		{
			return java.net.URLDecoder.decode(s.replace("+", "%2B"), "UTF-8").replace("%2B", "+");
		}
		// This exception should never occur.
		catch (UnsupportedEncodingException unenx)
		{
			throw new RuntimeException(unenx);	
		}
	}
	
	public static String md5Hash(String s)
	{
		try {
			byte[] bytesOfMessage = s.getBytes("UTF-8");
			java.security.MessageDigest md = java.security.MessageDigest.getInstance("MD5");
			byte[] thedigest = md.digest(bytesOfMessage);	
			
			java.math.BigInteger bi = new java.math.BigInteger(1, thedigest);
			return String.format("%0" + (thedigest.length << 1) + "X", bi);
			
		} catch (Exception ex) {
			throw new RuntimeException(ex);	
		}
	}	
}
