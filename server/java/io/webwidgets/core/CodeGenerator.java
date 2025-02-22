
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 

import org.json.simple.JSONObject;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.CollUtil.*;
import net.danburfoot.shared.FileUtils;

import io.webwidgets.core.CoreUtil.*;
import io.webwidgets.core.LiteTableInfo.*;


public class CodeGenerator
{
	
	private final LiteTableInfo _liteTable;
	
	private List<String> _srcList = Util.vector();
	
	CodeGenerator(LiteTableInfo lite)
	{
		_liteTable = lite;
	}
	
	static List<String> buildAndRun(LiteTableInfo lite)
	{
		return (new CodeGenerator(lite)).getCodeLineList();	
	}
	
	List<String> getCodeLineList()
	{
		generateCode();
		return Collections.unmodifiableList(_srcList);
	}
		
	private void add(String s, Object... vargs)
	{
		_srcList.add(String.format(s, vargs));
	}
	
	private void generateCode() 
	{
		_srcList.add("// Auto-Generated JavaScript code for " + _liteTable.dbTabPair._2);
	
		genMainCollection();
		
		genConstructor();
		
		genDictionaryBuilder();
				
		genObjectMethods();
		
		genGetSetMethods();
	}
	
	private void genMainCollection()
	{

		add("");
		add("// Register the Widget Table with the table index");
		add("W.__tableNameIndex.set('%s', { ", _liteTable.getSimpleTableName());

		add("");

		add("\t// Table properties");
		add("\twidgetOwner : \"" + _liteTable.getWidgetOwner() + "\",");
		add("\twidgetName : \"" + _liteTable.getWidgetName() + "\",");
		add("\ttableName : \"" + _liteTable.getSimpleTableName() + "\",");
		
		{
			String fnamestr = Util.join(_liteTable.getColumnNameSet(), "', '");
			add("");
			add("\t// List of object field/column names");
			add("\tfieldList : ['%s'],", fnamestr);
			add("");
		}



		add("\t_dataMap : new Map(),");
		add("");
		add("");


		addDefaultInfo();

		add("\tregister : function(tableitem)");
		add("\t{");
		
		add("\t\t// Assign the K/Value pair.");
		add("\t\tthis._dataMap.set(tableitem.getId(), tableitem);");


		add("\t}");
		add("});");
		

		add("");
		add("// Create entry for table indexes");
		add("W.__registerTableIndexEntry('%s');", _liteTable.getSimpleTableName());
		
		
		add("");
		
	}
	
	// Note, there are a lot of Map<String, Object> type things floating around.
	// Be careful about which one you are using
	// All this SQLite-table access should eventually go into a separate place
	@SuppressWarnings("unchecked")
	private void addDefaultInfo()
	{
		JSONObject ob = new JSONObject();

		try {
			ob.putAll(_liteTable.getDefaultInfo());
		} catch (Exception ex) {
			// Gotcha: error message could extend to multiple lines
			add("\t// Failed to load defaults with error %s", ex.getMessage().replaceAll("\n", " "));
		}

		add("");
		add("\t// Default values");
		add("\t_defaultInfo : %s,", ob.toString());
		add("");
	}


	private void genConstructor()
	{
		_srcList.add("// Standard constructor");
		
		String signature = Util.join(_liteTable.getColumnNameSet(), ", ");
		add(String.format("function %s(%s)", _liteTable.getRecordName(), signature));
		add("{");
		add("");
		
		for(String onecol : _liteTable.getColumnNameSet())
		{
			ExchangeType extype = _liteTable.getExchangeType(onecol);
			
			// Update Feb 2024, these now call a utility method that returns null if the input is null,
			// otherwise requires the input to be a valid integer or float 
			if(extype.isJsInteger())
			{
				add(String.format("\tthis.%s = __strictIntParseOkayNull(%s); ", onecol, onecol));
				add("");
				continue;
			}
			
			if(extype.isJsFloat())
			{
				add(String.format("\tthis.%s = __strictFloatParseOkayNull(%s); ", onecol, onecol));
				add("");
				continue;
			}
						
			add(String.format("\tthis.%s = %s; ", onecol, onecol));
		}
				
		add("}");
		add("");
	}
	
	private void genDictionaryBuilder()
	{
		add("// Dictionary builder. Check all fields are present.");
		add("W.__buildItemFuncMap['%s'] = function(record)", 
			_liteTable.getSimpleTableName());
		
		add("{");
		
		String signature = Util.join(_liteTable.getColumnNameSet(), "', '");
		add("\tconst fieldlist = ['%s'];", signature);
		add("\tconst tableob = W.__tableNameIndex.get('%s');", _liteTable.getSimpleTableName());

		add("");
		
		add("\tfor(var fi in fieldlist)");
		add("\t{");
		add("\t\tvar fname = fieldlist[fi];");
		add("");

		add("\t\t// Fold in default value if it is available");
		add("\t\tif(!(fname in record) && (fname in tableob._defaultInfo))");
		add("\t\t\t{ record[fname] = tableob._defaultInfo[fname]; }");
		add("");


		
		add("\t\tif(fname == \"id\" && !(fname in record))");
		add("\t\t\t{ record[\"id\"] = W.newBasicId('%s'); }", _liteTable.getSimpleTableName());	

		add("");
		add("\t\tmassert(fname in record, \"Record is missing field \" + fname);");

		add("\t}");
		
		
		List<String> reclook = Util.map2list(_liteTable.getColumnNameSet(), col -> "record." + col);
		String recordLookupStr = Util.join(reclook, ", ");
		
		add("");
		add("\tvar item = new %s(%s);", _liteTable.getRecordName(), recordLookupStr);
		add("\t// Update, Jan 2022 - buildItem now registers new object");
		add("\ttableob.register(item);");


		add("");
		add("\t// Update, Jan 2024 - place item in indexes");
		add("\tW.__placeItemInIndexes(item, null);");

		add("\treturn item;");
		add("}");
		add("");
		add("");
		
	}

	private void genObjectMethods()
	{
		String signature = Util.join(_liteTable.getColumnNameSet(), "', '");

		add("// Sync Item to Lite DB");
		add("%s.prototype.syncItem = function()", _liteTable.getRecordName());
		add("{");
		add("\tconst upsert = W.__genericUpsertUrl(this, ['%s']);", signature);
		add("\tW.__submitNewRequest(upsert, \"sync\", this.getId());");
		add("}");
		add("");
		add("");
		
		add("// Remove from DataMap and from SQLite.");
		add("%s.prototype.deleteItem = function()", _liteTable.getRecordName());
		add("{");
		add("\tconst myid = this.getId();");
		add("\tconst tableob = this.__getTableObject();");

		add("");
		add("\ttableob._dataMap.delete(myid);");
		add("");
		add("\t// Remove the item from the indexes");
		add("\tW.__removeItemFromIndexes(this, null);");
		add("");
		add("\t// This is a call to global AJAX JS");
		add("\tconst delurl = W.__genericDeleteUrl(this);");
		add("\tW.__submitNewRequest(delurl, \"delete\", this.getId());");
		add("}");
		add("");
		add("");
		
		
		add("");
		add("// Get reference to the Table object, which holds metadata; normal WWIO dev should not require this");
		add("%s.prototype.__getTableObject = function()", _liteTable.getRecordName());
		add("{");
		add("\treturn W.__tableNameIndex.get('%s');", _liteTable.getSimpleTableName());
		add("}");


		
	}
	
	private void genGetSetMethods()
	{
		add("");
		add("// Get/Set Methods");
		for(String onecol : _liteTable.getColumnNameSet())
		{
			if(onecol.startsWith("_"))
				{ continue; }
			
			String colname = CoreUtil.snake2CamelCase(onecol);
			add("%s.prototype.get%s = function()", _liteTable.getRecordName(), colname);
			add("{");
			add("\treturn this.%s;", onecol);
			add("}");
			add("");
			
			// No setter for ID column!!!
			if(!onecol.toLowerCase().equals("id"))
			{
				add("%s.prototype.set%s = function(x)", _liteTable.getRecordName(), colname);
				add("{");

				// Update Jan 2024: the setXXX just forwards to setField('xxx'), this is important
				// for calling the add/remove methods on the indexes
				// add("\tthis.%s = x;", onecol);
				add("\tthis.setField('%s', x);", onecol);
				add("}");
				add("");
				add("");
			}
		}


		add("");
		add("// Check generic field name lookup correctness");
		add("%s.prototype.checkFieldName = function(fieldname)", _liteTable.getRecordName());
		add("{");
		add("\tif(!this.hasOwnProperty(fieldname))");
		add("\t{");
		add("\t\tmassert(false, `Unknown field ${fieldname}, options are ${W.getFieldList('%s')}, use W.getFieldList(..) to check if unsure`);",
					_liteTable.dbTabPair._2);

		add("\t}");
		add("}");

		
		add("");
		add("// Generic getField");
		add("%s.prototype.getField = function(fieldname)", _liteTable.getRecordName());
		add("{");
		add("\tthis.checkFieldName(fieldname);");
		add("\treturn this[fieldname];");
		add("}");
		
		add("");
		add("// Generic setField");
		add("// Remove the item from indexes and then re-add");
		add("%s.prototype.setField = function(fieldname, x)", _liteTable.getRecordName());
		add("{");
		add("\tthis.checkFieldName(fieldname);");
		add("\tW.__indexUpdateProcess(this, fieldname, true);"); 
		add("\tthis[fieldname] = x;");
		add("\tW.__indexUpdateProcess(this, fieldname, false);"); 
		add("}");
		
		
		// Hmmm: should I add a dummy implementation that throws an error, if you attempt to call
		// the method on an object that isn't a blob store...?
		if(_liteTable.isBlobStoreTable())
		{
			add("");
			add("// Special Blob Record function");
			add("%s.prototype.%s = function()", _liteTable.getRecordName(), BlobDataManager.GET_BLOB_STORE_METHOD);			
			add("{");
			add("\tconst tableob = this.__getTableObject();");
			add("\treturn W.getBlobStoreUrl(tableob.widgetOwner, tableob.widgetName, tableob.tableName, this.id);");
			add("}");
		} else {
			
			add("");
			add("// Special Blob Record function");
			add("%s.prototype.%s = function()", _liteTable.getRecordName(), BlobDataManager.GET_BLOB_STORE_METHOD);
			add("{");
			add("\tmassert(false, `This object is not configured as a blob store, did you pick the column names correctly?`);");
			add("}");			
			
		}
	}


	public static List<String> maybeUpdateCode4Table(LiteTableInfo LTI, boolean dogenerate)
	{
		Optional<File> prevfile = LTI.findAutoGenFile();
		// Normal situation - file exists and we aren't asked to generate it.
		if(prevfile.isPresent() && !dogenerate)
			{ return Util.listify(); }
		
		
		CodeGenerator ncgen = new CodeGenerator(LTI);
		List<String> newsrc = ncgen.getCodeLineList();
		
		if(oldVersionOkay(prevfile, newsrc))
		{
			String mssg = Util.sprintf("New version of AutoGen code identical to previous for DB %s\n", LTI.dbTabPair._2);
			return Util.listify(mssg);
		}
		
		int oldversion = prevfile.isPresent() ? getVersionFromPath(prevfile.get()) : 0;
		String newjspath = getAutoGenProbePath(LTI, oldversion+1);
		
		FileUtils.getWriterUtil()
				.setFile(newjspath)
				.writeLineListE(newsrc);
		
		List<String> loglist = Util.vector();
		loglist.add(Util.sprintf("Wrote autogen code to path %s\n", newjspath));
		
		if(prevfile.isPresent())
		{
			prevfile.get().delete();
			loglist.add(Util.sprintf("Deleted old file %s\n", prevfile.get()));	
		}
		
		return loglist;

	}

	static boolean oldVersionOkay(Optional<File> prevfile, List<String> newsrc)
	{
		if(!prevfile.isPresent())
			{ return false; }
		
		List<String> oldsrc = FileUtils.getReaderUtil()
							.setFile(prevfile.get())
							.setTrim(false)
							.readLineListE();

		return oldsrc.equals(newsrc);
	}

	// TODO: need to get rid of this hacky way of upgrading the versions
	// This is all just a roundabout way to ensure that the browser doesn't cache
	// old versions of the autogen code
	// The better way is to use modtime=... argument, like with the other assets
	static int getVersionFromPath(File thefile)
	{
		String fname = thefile.getName();
		String[] toks = fname.split("__");
		String justnum = CoreUtil.peelSuffix(toks[1], ".js");
		return Integer.valueOf(justnum);
	}
		
	private static String getAutoGenProbePath(LiteTableInfo LTI, int version)
	{
		File wdir = LTI.dbTabPair._1.getAutoGenJsDir();
		return Util.sprintf("%s/%s__%03d.js", wdir.toString(), LTI.getBasicName(), version);
	}
	

	static boolean matchesFileName(LiteTableInfo LTI, File thefile)
	{
		String fname = thefile.getName();
		String[] toks = fname.split("__");
		return LTI.getBasicName().equals(toks[0]);
	}
} 



