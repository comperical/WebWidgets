
package io.webwidgets.core; 

import java.io.*; 
import java.util.*; 
import java.sql.*; 

import net.danburfoot.shared.Util;
import net.danburfoot.shared.CollUtil.*;

import io.webwidgets.core.CoreUtil.*;
import io.webwidgets.core.WidgetOrg.*;
import io.webwidgets.core.LiteTableInfo.*;


// This is a replacement for the old JsCodeGenerator.jsp page
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
		add("// Definition of main collection name");
		add("");
		
		add(_liteTable.getCollectName() + " = ");
		add("{");
		add("");

		add("\t// Table properties");
		add("\twidgetOwner : \"" + _liteTable.getWidgetOwner() + "\",");
		add("\twidgetName : \"" + _liteTable.getWidgetName() + "\",");
		add("\ttableName : \"" + _liteTable.getSimpleTableName() + "\",");
		
		
		add("\t_dataMap : new Map(),");
		add("");
		add("");
		
		add("\tregister : function(tableitem)");
		add("\t{");
		
		add("\t\t// Assign the K/Value pair.");
		add("\t\tthis._dataMap.set(tableitem.getId(), tableitem);");

		add("\t}");
		add("};");
		
		add("");
		add("// Register the Widget Table with the table index");
		add("W.__tableNameIndex.set('%s', %s);", _liteTable.getSimpleTableName(), _liteTable.getCollectName());
		
		
		add("");
		
	}
	
	private void genConstructor()
	{
		_srcList.add("// Standard constructor");	
		
		String signature = Util.join(_liteTable.getColTypeMap().keySet(), ", ");
		add(String.format("function %s(%s)", _liteTable.getRecordName(), signature));
		add("{");
		add("");
		
		for(String onecol : _liteTable.getColTypeMap().keySet())
		{
			ExchangeType extype = _liteTable.getColumnExType(onecol);
			
			if(extype.isJsInteger())
			{
				add(String.format("\tthis.%s = parseInt(%s); ", onecol, onecol));
				add(String.format("\tmassert(!isNaN(this.%s), \"Failed to convert value to integer for column %s\");", onecol, onecol));
				add("");
				continue;	
			}
			
			if(extype.isJsFloat())
			{
				add(String.format("\tthis.%s = parseFloat(%s); ", onecol, onecol));
				add(String.format("\tmassert(!isNaN(this.%s), \"Failed to convert value to float for column %s\");", onecol, onecol));
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
		
		String signature = Util.join(_liteTable.getColTypeMap().keySet(), "', '");
		add("\tvar fieldlist = ['%s'];", signature);
		add("");
		
		add("\tfor(var fi in fieldlist)");
		add("\t{");
		add("\t\tvar fname = fieldlist[fi];");
		add("");
		
		add("\t\tif(fname == \"id\" && !(fname in record))");
		add("\t\t\t{ record[\"id\"] = W.newBasicId('%s'); }", _liteTable.getSimpleTableName());	

		add("");
		add("\t\tmassert(fname in record, \"Record is missing field \" + fname);");

		add("\t}");
		
		
		List<String> reclook = Util.map2list(_liteTable.getColTypeMap().keySet(), col -> "record." + col);
		String recordLookupStr = Util.join(reclook, ", ");
		
		add("");
		add("\tvar item = new %s(%s);", _liteTable.getRecordName(), recordLookupStr);
		add("\t// Update, Jan 2022 - buildItem now registers new object");
		add("\t%s.register(item);", _liteTable.getCollectName());

		add("\treturn item;");
		add("}");
		add("");
		add("");
		
	}

	private void genObjectMethods()
	{
		
		add("// Register Item with DataMap and sync 2 LiteDb");
		add("%s.prototype.registerNSync = function()", _liteTable.getRecordName());
		add("{");
		add("\tconsole.log(\"Warning: registerNSync is deprecated and no longer necessary: buildItem command now registers new objects\");");
		
		add("\t%s.register(this);", _liteTable.getCollectName());
		add("");
		add("\t// This is a call to global AJAX JS");
		add("\tsyncSingleItem(this);");
		add("}");
		add("");
		add("");
		



		
		add("// Sync Item to Lite DB");
		add("%s.prototype.syncItem = function()", _liteTable.getRecordName());
		add("{");
		add("\tW.__submitNewRequest(this.getUpsertUrl(), \"sync\", this.getId());");
		add("}");
		add("");
		add("");
		
		add("// Remove from DataMap and from SQLite.");
		add("%s.prototype.deleteItem = function()", _liteTable.getRecordName());
		add("{");
		add("\tconst myid = this.getId();");
		add("");
		add("\t%s._dataMap.delete(myid);", _liteTable.getCollectName());
		add("");
		add("\t// This is a call to global AJAX JS");
		add("\tW.__submitNewRequest(this.getDeleteUrl(), \"delete\", this.getId());");
		add("}");
		add("");
		add("");
		
		String signature = Util.join(_liteTable.getColTypeMap().keySet(), "', '");
		add("%s.prototype.getUpsertUrl = function()", _liteTable.getRecordName());
		add("{");
		add("\treturn W.genericUpsertUrl(%s, this, ['%s']);", _liteTable.getCollectName(), signature);
		add("}");
		add("");
		add("");
		

		String delsign = Util.join(_liteTable.getPkeyList(), "', '");
		add("%s.prototype.getDeleteUrl = function()", _liteTable.getRecordName());
		add("{");
		add("\treturn W.genericDeleteUrl(%s, this, ['%s']);", _liteTable.getCollectName(), delsign);
		add("}");		
		
		
		
	}
	
	private void genGetSetMethods()
	{
		add("");
		add("// Get/Set Methods");
		add("");
		
		for(String onecol : _liteTable.getColTypeMap().keySet())
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
				add("\tthis.%s = x;", onecol);
				add("}");
				add("");
				add("");
			}
		}
		
		// TODO: want an assert here that tells me if I got the field name wrong
		add("");
		add("// Generic getField");
		add("%s.prototype.getField = function(fieldname)", _liteTable.getRecordName());
		add("{");
		add("\treturn this[fieldname];");
		add("}");
		
		add("");
		add("// Generic setField");
		add("%s.prototype.setField = function(fieldname, x)", _liteTable.getRecordName());
		add("{");
		add("\tthis[fieldname] = x;");
		add("}");		
		
		
		// Hmmm: should I add a dummy implementation that throws an error, if you attempt to call
		// the method on an object that isn't a blob store...?
		if(_liteTable.isBlobStoreTable())
		{
			add("");
			add("// Special Blob Record function");
			add("%s.prototype.%s = function()", _liteTable.getRecordName(), BlobDataManager.GET_BLOB_STORE_METHOD);			
			add("{");
			add("\treturn W.getBlobStoreUrl(%s.widgetOwner, %s.widgetName, %s.tableName, this.id);", 
				_liteTable.getCollectName(), _liteTable.getCollectName(), _liteTable.getCollectName());

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
} 



