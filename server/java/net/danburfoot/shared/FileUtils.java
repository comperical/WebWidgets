
package net.danburfoot.shared; 

import java.io.*; 
import java.util.*; 
import java.util.zip.*;
import java.util.function.*;

import java.nio.charset.Charset;

public class FileUtils
{ 
	public enum CharSetEnum { 
		UTF8("UTF-8"),
		ISO88591("ISO-8859-1"),
		USASCII("US-ASCII");
		
		private String _csName;
		
		CharSetEnum(String s)
		{
			_csName = s;
		}
		
		String getCharsetName()
		{
			return _csName;	
			
		}
	};
	
	
	public static void readFileAsByteList(List<Byte> a, String path) throws IOException 
	{ 
		FileInputStream fia = new FileInputStream(path);
		
		for(int x = fia.read(); x != -1; x = fia.read())
			a.add((byte) x);
		
		fia.close(); 
	} 
	
	public static String md5checksum(String path) throws Exception
	{
		FileInputStream fis = new FileInputStream(path);
		String cs = md5checksum(fis);
		fis.close();
		return cs;
	}
	
	public static String md5checksum(InputStream is) throws Exception
	{
		java.security.MessageDigest digAlg = java.security.MessageDigest.getInstance("MD5");
		
		for(int x = is.read(); x != -1; x = is.read())
			digAlg.update((byte) x);
		
		byte[] digest = digAlg.digest();
		
		//System.out.printf("\nSize of digest is %d", digest.length);
		
		StringBuffer sb = new StringBuffer();
		for(int i = 0; i < digest.length; i++)
		{
			int cval = (digest[i] < 0 ? digest[i]+256 : digest[i]);
			String s = Integer.toHexString(cval);
			sb.append(s.length() < 2 ? "0" + s : s);
		}
		
		return sb.toString();
	}
	
	
	public static void compareFiles(String pa, String pb)
	throws IOException 
	{ 	
		List<Byte> a = new Vector<Byte>();
		List<Byte> b = new Vector<Byte>();
		
		readFileAsByteList(a, pa); 
		readFileAsByteList(b, pb); 
		
		if(a.size() != b.size())
		{ 
			System.out.printf("\nFiles are of different size %d, %d", a.size(), b.size());
			return; 
		} 
		
		boolean ident = true; 
		for(int i = 0; i < a.size() && ident; i++)
		{ 
			if(a.get(i).byteValue() != b.get(i).byteValue())
			{ 
				System.out.printf("\nFiles differ on byte index %d", i);
				System.out.printf("\nFile A has %d, file B has %d", a.get(i).intValue(), b.get(i).intValue());
				ident = false; 
			} 	
		} 
		
		if(ident)
			System.out.printf("\nFiles are identical."); 
	} 
	
	public static void serializeEat(Serializable trg, String path)
	{
		try { serialize(trg, path); } 
		catch (Exception ex) { throw new RuntimeException(ex); }
	}
	
	public static void serialize(Serializable trg, String path) throws Exception
	{
		serialize(trg, new FileOutputStream(path));
	}
	
	public static void serialize(Serializable trg, OutputStream os) throws Exception
	{
		ObjectOutputStream outStream = null;
		
		try {
			outStream = new ObjectOutputStream(os); 
			// serialize and write obj2DeepCopy to byteOut
			outStream.writeObject(trg); 
			//always flush your stream
			outStream.flush();
		} catch(Exception e) {
			throw(e);
		} finally {
			if(outStream != null) outStream.close();
		}
	}
	
	// Eat the exception
	@SuppressWarnings("unchecked")
	public static <T> T unserializeEat(String path)
	{
		try { return (T) unserialize(path); }
		catch (Exception ex) { throw new RuntimeException(ex); }
	}
	
	public static Object unserialize(String path) throws Exception
	{
		return unserialize(new FileInputStream(path));
	}
	
	public static Object unserialize(InputStream base) throws Exception
	{
		ObjectInputStream inStream = null;		
		try {
			inStream = new ObjectInputStream(base);
			return inStream.readObject(); 
		} catch(Exception e) {
			throw(e);
		} finally {
			if(inStream != null) inStream.close();
		}
	}
	
	public static void createDirForPath(String path)
	{
		File dirfile = (new File(path)).getParentFile();
		
		if(!dirfile.exists())
			{ dirfile.mkdirs(); }
	
	}
	
	public static void deleteIfExists(String filepath)
	{	
		File myfile = new File(filepath);
		
		if(myfile.exists())
			{ myfile.delete(); }		
	}
	
	public static void recursiveDeleteFile(File f) throws IOException
	{
		if (f.isDirectory()) {
			for (File c : f.listFiles()) 
				{ recursiveDeleteFile(c); }
		}
		if (!f.delete())
			throw new FileNotFoundException("Failed to delete file: " + f);
	}	
	
	// Read the data into memory	
	public static InputStream getInMemStream(InputStream basestream) throws IOException
	{
		// This is probably just superstition, but I want to make sure
		// that the memory doesn't get doubly allocated.
		byte[] buf;
		{
			ByteArrayOutputStream baos = new ByteArrayOutputStream();
			in2out(basestream, baos);
			buf = baos.toByteArray();			
		}

		return new ByteArrayInputStream(buf);		
	}

	public static void in2out(InputStream in, OutputStream out) throws IOException
	{
		byte[] buffer = new byte[1024];

		int len = in.read(buffer);
		while (len != -1) {
			out.write(buffer, 0, len);
			len = in.read(buffer);
		}

		// Whoa, need to remember this one!!
		in.close();
		out.close();
	}	
		
	public static <K,V> SortedMap<K, V> readSimpleDataMap(String thepath, Function<String, K> keyfunc, Function<String, V> valfunc)
	{
		List<String> mylist = getReaderUtil()
						.setFile(thepath)
						.readLineListE();
						
	
		SortedMap<K, V> mymap = Util.treemap();
		
		for(String oneline : mylist)
		{
			if(oneline.startsWith("//"))
				{ continue; }
			
			if(oneline.trim().isEmpty())
				{ continue; }
			
			String[] kvstr = oneline.split(",");
			
			mymap.put(keyfunc.apply(kvstr[0].trim()), valfunc.apply(kvstr[1].trim()));
		}
		
		return Collections.unmodifiableSortedMap(mymap);
	}
	
	
	public static InputStream getResourceStream(String respath)
	{
        return FileUtils.class.getResourceAsStream(respath);
	}	
	
	public static WriterUtil getWriterUtil()
	{
		return new WriterUtil();		
	}
	
	public static class WriterUtil 
	{
		String _pOut;
		CharSetEnum _cSE = CharSetEnum.UTF8;
		
		OutputStream _outStream = null;
		
		// If true, check for existence of parent dir and create if missing.
		private boolean _checkCreateParentDir = false;
		
		private boolean _isGzip = false;
		
		private boolean _writeStarted = false;
		
		// Can't make this work without some hacky things to remember 
		// about the path info
		// private boolean _doPrintInfo = false;
		
		private WriterUtil() {} 
		
		public WriterUtil setFile(File f)
		{
			return setFile(f.getAbsolutePath());	
		}
		
		public WriterUtil setCheckCreateParentDir(boolean ccpd)
		{
			Util.massert(_outStream == null, 
				"Must call this BEFORE setting output stream");
			
			_checkCreateParentDir = ccpd;	
			return this;
		}
		
		public WriterUtil setBase64()
		{
			Util.massert(_outStream != null,
				"Must call this method AFTER setting the output stream");
		
			assertWriteNotStarted();
			
			_outStream = Base64.getEncoder().wrap(_outStream);
			
			return this;
		}

		
		private void assertWriteNotStarted()
		{
			Util.massert(_writeStarted == false,
				"Output stream configuration method called AFTER starting write");
			
		}
		
		public WriterUtil setFile(String path)
		{
			assertWriteNotStarted();
			
        		Util.massert(_outStream == null, "IO Stream already set, this object not reusable");
        		
        		if(_checkCreateParentDir)
        		{
        			File parentdir = (new File(path)).getParentFile();
        			
        			if(!parentdir.exists())
        			{
        				Util.pf("Creating parent directory %s\n", parentdir.getAbsolutePath());
        				parentdir.mkdirs(); 
        			}
        		}
        		
        		try { _outStream = new FileOutputStream(path); }
        		catch (IOException ioex) { throw new RuntimeException(ioex); }
        		
        		if(path.endsWith(".Z") || path.endsWith(".gz"))
        			{ setGzip(true); }
        		
        		return this;
		}
		
		public WriterUtil setGzip(boolean isgzip) 
		{
			assertWriteNotStarted();
			
			if(isgzip)
			{
				Util.massert(!_isGzip, "This writer is already set to GZip, maybe by setFile(..), do not call twice");
				Util.massert(_outStream != null, "Must set output stream before converting to GZip");
				
				// This exception probably never happens
				try { _outStream = new GZIPOutputStream(_outStream); }
				catch (IOException ioex) { throw new RuntimeException(ioex); }
				
				_isGzip = true;
			}
			
			return this;
		}
		
		public WriterUtil setGzip()
		{
			return setGzip(true);	
		}
		
		public WriterUtil setStream(OutputStream out)
		{
			assertWriteNotStarted();			
			
        		Util.massert(_outStream == null, "Output Stream already set, this object not reusable");
        		_outStream = out;
        		return this;
		}
		
		public WriterUtil setCharSet(String cset)
		{
			assertWriteNotStarted();			
			
			for(CharSetEnum cse : CharSetEnum.values())
			{
				if(cse.getCharsetName().equals(cset))
				{ 
					_cSE = cse;
					return this;
				}
			}
			
			Util.massert(false, "Unknown char set %s", cset);
			return null;
		}
		
		public void writeLineList(Collection<? extends Object> data) throws IOException
		{
			_writeStarted = true;
			
			BufferedWriter bwrite = new BufferedWriter(new OutputStreamWriter(_outStream, _cSE.getCharsetName()));
			
			for(Object o : data)
			{
				bwrite.write(o.toString());
				bwrite.write("\n");
			}
			
			bwrite.close();				
		}
		
		public void writeBytes(byte[] buffer) throws IOException
		{
			_outStream.write(buffer);
			
			_outStream.close();
		}
		
		public BufferedWriter getWriter() throws IOException
		{
			_writeStarted = true;
			
			return new BufferedWriter(new OutputStreamWriter(_outStream, _cSE.getCharsetName()));
		}
		
		public void writeLineListE(Collection<? extends Object> data)
		{
			try { writeLineList(data); }
			catch (IOException ioex) { throw new RuntimeException(ioex); }
		}
	}	
	
	
	public static ReaderUtil getReaderUtil()
	{
		return new ReaderUtil();	
	}
        
    public static class ReaderUtil 
    {
    	private String _charEncoding = "UTF-8";
    	
    	private InputStream _inStream;

    	private boolean _skipEmpty = false;

    	private boolean _doTrim = true;
    	
    	private boolean _doSkipComment = false;
    	
    	private int _maxReadLine = Integer.MAX_VALUE;
    	
    	private boolean _useLinkedList = false;
    	
    	public ReaderUtil setFile(File f)
    	{
    		return setFile(f.getAbsolutePath());	
    	}
    	
    	public ReaderUtil setFile(String path)
    	{
    		Util.massert(_inStream == null, "IO Stream already set, this object not reusable");
    		try { 
    			_inStream = new FileInputStream(path); 
    			if(path.endsWith(".Z") || path.endsWith(".gz"))
    				{ setGzip(); }
    		}
    		catch (IOException ioex) { throw new RuntimeException(ioex); }
    		
    		return this;
    	}
    	
    	public ReaderUtil setStream(InputStream in)
    	{
    		Util.massert(_inStream == null, "IO Stream already set, this object not reusable");
    		_inStream = in;
    		return this;
    	}
    	
    	public ReaderUtil setEncoding(String enc)
    	{
    		_charEncoding = enc;	
    		return this;
    	}
    	
    	public ReaderUtil useLinkedList(boolean usell)
    	{
    		_useLinkedList = usell;	
    		return this;
    	}

    	// Trim the lines as we read them in. 
    	// Only used for readLineList(..), not getReader!!
    	public ReaderUtil setTrim(boolean dotrim)
    	{
    		_doTrim = dotrim;
    		return this;
    	}
    	        	
    	
    	// Skip comment lines
    	public ReaderUtil setSkipComment(boolean skip)
    	{
    		_doSkipComment = skip;
    		return this;
    	}        	
    	
    	
    	// Skip empty lines in readLineList()
    	public ReaderUtil setSkipEmpty(boolean skipempty)
    	{
    		_skipEmpty = skipempty;
    		return this;
    	}

    	// Set a maximum number of lines to read.
    	public ReaderUtil setMaxLineRead(int maxread)
    	{
    		_maxReadLine = maxread;
    		return this;
    	}
    	

    	public ReaderUtil setGzip()
    	{
    		return setGzip(true);
    	}
    	
    	public ReaderUtil setGzip(boolean isgz)
    	{
    		Util.massert(_inStream != null, "Must set input stream first");
    		if(isgz)
    		{
    			try { _inStream = new GZIPInputStream(_inStream); }
    			catch (IOException ioex) { throw new RuntimeException(ioex); }
    		}
    		return this;
    	}
    	
    	public Properties getPropertiesE()
    	{
    		try { return getProperties(); }
    		catch (IOException ioex) { throw new RuntimeException(ioex); }
    	}
    	
    	public Properties getProperties() throws IOException
    	{
    		try (BufferedReader bread = getReader()) {
    			Properties result = new Properties();
    			result.load(bread);
    			return result;
    		}
    	}    	

    	public BufferedReader getReader() throws IOException
    	{
    		Util.massert(_inStream != null, "Must set input stream first");		
    		return new BufferedReader(new InputStreamReader(_inStream, _charEncoding));        		
    	}
    	
    	public byte[] readBytes() throws IOException
    	{
    		Util.massert(_inStream != null, "Must set input stream first");		
    		ByteArrayOutputStream buffer = new ByteArrayOutputStream();
    		
    		int nRead;
    		byte[] data = new byte[16384];
    		
    		while ((nRead = _inStream.read(data, 0, data.length)) != -1) {
    			buffer.write(data, 0, nRead);
    		}
    		
    		return buffer.toByteArray();
    	}
    	
    	public List<String> readLineList() throws IOException
    	{
    		int linecount = 0;
    		
    		List<String> llist = (_useLinkedList ? Util.linkedlist() : Util.vector());
    		BufferedReader bread = getReader();
    		
    		for(String oneline = bread.readLine(); oneline != null && linecount < _maxReadLine; oneline = bread.readLine())
    		{
    			if(_doTrim)
    				{ oneline = oneline.trim(); }

    			if(oneline.isEmpty() && _skipEmpty)
    				{ continue; }
    			
    			if(_doSkipComment && oneline.trim().startsWith("//"))
    				{ continue; }

    			llist.add(oneline);	
    			
    			linecount++;
    		}
    		bread.close();
    		
    		return llist;
    		
    	}
    	
    	public LinkedList<String> readLinkedList() throws IOException
    	{
    		return new LinkedList<String>(readLineList());	
    	}
    	
    	public LinkedList<String> readLinkedListE()
    	{
    		return new LinkedList<String>(readLineListE());	

    	}        	
    	
    	
    	public List<String> readLineListE()
    	{
    		try { return readLineList(); }
    		catch (IOException ioex) { throw new RuntimeException(ioex); }
    	}
    	
    	public LinkedList<String> readLinkedLineListE()
    	{
    		try { return Util.linkedlistify(readLineList()); }
    		catch (IOException ioex) { throw new RuntimeException(ioex); }
    	}
    	
    	public String readSingleString() throws IOException
    	{	
    		List<String> list = readLineList();
    		return Util.join(list, "\n");
    	}
    	
    	public String readSingleStringE()
    	{	
    		try { return readSingleString(); }
    		catch (IOException ioex) { throw new RuntimeException(ioex); }
    	}        	
    }
    
    
    // For fluent operation
    public static SplicerUtil getSplicerUtil()
    { 
    	return new SplicerUtil();
    }
    	
    public static class SplicerUtil
    {
    	private List<String> _fullOrigList;
    	
    	private List<String> _insertList;
    	
    	private String _searchTag; 
    	
    	public SplicerUtil setOrigLineList(List<String> linelist)
    	{
    		_fullOrigList = linelist;
    		return this;
    	}

    	public SplicerUtil setInsertList(List<String> linelist)
    	{
    		_insertList = linelist;
    		return this;
    	}
    	
    	public SplicerUtil setSearchTag(String basetag)
    	{
    		_searchTag = basetag;	
    		return this;
    	}
    	
    	public static String getAutoGenTag(String basetag, boolean isstart)
    	{
			return Util.sprintf("AUTOGEN::%sDEF::%s", (isstart ? "ALPHA" : "OMEGA"), basetag.toUpperCase());	
    	}

	
		public List<String> getResult()
		{
			Util.massert(_fullOrigList != null && _insertList != null && _searchTag != null,
				"Must set origlist, insertlist, and searchtag before calling");
			
			LinkedList<String> origlist = Util.linkedlistify(_fullOrigList);
			LinkedList<String> restlist = Util.linkedlist();
			
			String strtag = getAutoGenTag(_searchTag, true);
			String endtag = getAutoGenTag(_searchTag, false);
			
			while(true)
			{
				Util.massert(!origlist.isEmpty(), 
					"Reached end of line list without encountering start tag %s", strtag);
				
				String nextline = origlist.poll();
				
				// Add the line even if it's start tag
				restlist.add(nextline);
				
				// Break if you see the start tag.
				if(nextline.contains(strtag))
					{ break; }
			}
			
			// Add the insert lines
			restlist.addAll(_insertList);
			
			// Peel off lines until you find the end tag
			while(true)
			{
				Util.massert(!origlist.isEmpty(), 
					"Reached end of line list without encountering END tag %s", endtag);
				
				String nextline = origlist.poll();
				
				// if you see end tag, add it and break;
				if(nextline.contains(endtag))
				{ 
					restlist.add(nextline);
					break;
				}				
			}

			// Add all remaining lines.
			restlist.addAll(origlist);

			return restlist;
		}
		
		public void insert2File(File thefile)
		{
			Util.massert(_fullOrigList == null, "Cannot already have original data");
			Util.massert(thefile.exists(), "Local file %s does not exist", thefile);
			
			_fullOrigList = FileUtils.getReaderUtil()
							.setTrim(false)
							.setFile(thefile)
							.readLineListE();
							
			List<String> newlist = getResult();
			
			FileUtils.getWriterUtil()
					.setFile(thefile)
					.writeLineListE(newlist);
		}
	}
} 

