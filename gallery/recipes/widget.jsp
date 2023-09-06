
<html>
<head>
<title>Recipes</title>

<%= DataServer.include(request) %>

<script>

STUDY_RECIPE_ID = -1;

STUDY_INGR_ID = -1;

VIEW_SHOPPING_LIST = true;

function getPageComponent()
{
	if(VIEW_SHOPPING_LIST)
		{ return "shopping_list"; }
	
	if(STUDY_INGR_ID != -1)
		{ return "study_ingredient"; }
	
	if(STUDY_RECIPE_ID != -1)
		{ return "study_recipe"; }
	
	return "main_list";
}

function studyRecipe(recid) 
{
	STUDY_RECIPE_ID = recid;
	redisplay();
}
             
function studyIngredient(ingrid) 
{
	STUDY_INGR_ID = ingrid;
	redisplay();
}

function back2Recipe() 
{
	STUDY_INGR_ID = -1;
	redisplay();
}


function back2Main() 
{
	STUDY_INGR_ID = -1;
	STUDY_RECIPE_ID = -1;
	VIEW_SHOPPING_LIST = false;
	redisplay();
}

function viewShoppingList() 
{
	VIEW_SHOPPING_LIST = true;
	redisplay();
}

function editIngrName()
{
	genericEditTextField("ingredient", "ingr_name", STUDY_INGR_ID);	
}                

function editIngrCategory()
{
	genericEditTextField("ingredient", "category", STUDY_INGR_ID);	
}                



function editQuantity()
{
	genericEditTextField("ingredient", "quantity", STUDY_INGR_ID);	
}               


function editIngrNotes()
{
	genericEditTextField("ingredient", "notes", STUDY_INGR_ID);	
}

function newRecipe()
{
	const shortname = prompt("Name of new recipe: ");
	
	if(shortname)
	{
		const newid = newBasicId("recipe_item");

		const todaycode = getTodayCode().getDateString();
		
		// created_on, active_on, completed_on, dead_line
		const newrec = {
			"id" : newid,
			"recipe_name" : shortname,
			"is_active" : 1,
			"extra_info": "NotYetSet",
			"created_on" : todaycode		
		};		
		
		const newitem = buildItem("recipe_item", newrec);
		newitem.syncItem();
		redisplay();
	}
}

function addRecipe2List(recid)
{
	const recipe = W.lookupItem("recipe_item", recid);
	
	if(confirm(`Add recipe ${recipe.getRecipeName()} to your shopping list?`))
	{
		const todaycode = getTodayCode().getDateString();
				
		W.getItemList("ingredient").forEach(function(ingr) {
				
			if(ingr.getRecipeId() != recipe.getId())
				{ return; }
			
			const newrec = {
				"ingr_id" : ingr.getId(),
				"is_active" : 1,
				"created_on" : todaycode
			};
			// sqlite> create table shopping_list(id int, ingr_id int, is_active smallint, created_on varchar(10), primary key(id));                   
			
			const newitem = W.buildItem("shopping_list", newrec);
			newitem.syncItem();
		});
		
		redisplay();
	}
}

function addIngredient()
{
	massert(STUDY_RECIPE_ID != -1, "Somehow called this function without a recipe ID");
	
	const itemname = prompt("Name of new ingredient: ");
	
	if(itemname)
	{		
		// created_on, active_on, completed_on, dead_line
		const newrec = {
			"recipe_id" : STUDY_RECIPE_ID,
			"ingr_name" : itemname,
			"category" : "produce",
			"quantity" : "2",
			"notes" : "..."
		};		
		
		const newitem = W.buildItem("ingredient", newrec);
		newitem.syncItem();
		redisplay();		
	}
}

function deleteIngredient(killid)
{
	const ingritem = W.lookupItem("ingredient", killid);
	
	if(confirm("Are you sure you want to delete item " + ingritem.getIngrName() + "?"))
	{
		ingritem.deleteItem();
		redisplay();
	}
}


function deleteShoppingItem(killid)
{
	const shopitem = W.lookupItem("shopping_list", killid);
	
	if(confirm("Are you sure you want to delete this item ? "))
	{
		shopitem.deleteItem();
		redisplay();
	}
}

function clearShoppingList() 
{
	if(confirm("Are you sure you want to clear your shopping list?"))
	{
		W.getItemList("shopping_list").forEach(function(shop) {
			shop.deleteItem();
		});
	}	
	
	redisplay();
	
}

function cycleRecipeActive(ritemid)
{
	if(confirm("Are you sure you deactivate this recipe?"))
	{
		genericToggleActive("recipe_item", ritemid);
	}	
	
	redisplay();
}


function redisplay()
{
	reDispRecipeItem();
	
	reDispMainTable();
	
	reDispIngredient();
	
	reDispShoppingList();
	
	setPageComponent(getPageComponent());
}

function reDispIngredient()
{
	if(STUDY_INGR_ID == -1)
		{ return; }

	const myingr = W.lookupItem("ingredient", STUDY_INGR_ID);
	
	const datastr = `
		<table  class="basic-table" width="50%">
		<tr>
		<td>Back</td>
		<td colspan="2">
		<a href="javascript:back2Recipe()">
		<img src="/u/shared/image/leftarrow.png" height="18"/></a>
		</td>
		</tr>
		
		<tr>
		<td>Name</td>
		<td>${myingr.getIngrName()}</td>
		<td>
		<a href="javascript:editIngrName()">
		<img src="/u/shared/image/edit.png" height="18"/></a>
		
		</td>
		
		</tr>
		<tr>
		<td>Category</td>
		<td>${myingr.getCategory()}</td>

		<td>
		<a href="javascript:editIngrCategory()">
		<img src="/u/shared/image/edit.png" height="18"/></a>
		</td>		
		</tr>
		
		<tr>
		<td>Quantity</td>
		<td>${myingr.getQuantity()}</td>
		
		<td>
		<a href="javascript:editQuantity()">
		<img src="/u/shared/image/edit.png" height="18"/></a>
		</td>			
		
		</tr>
		
		
		</table>
		
		<br/>
		
		<table  class="basic-table" width="50%">
		<tr>
		<th colspan="2">Notes</th>
		</tr>
		<tr>
		<td>${myingr.getNotes()}</td>
		<td width="10%">
		<a href="javascript:editIngrNotes()">
		<img src="/u/shared/image/edit.png" height="18"/></a>
		</td>
		</tr>
		
	`;
	
	populateSpanData({"ingredient_info" : datastr });
}



function reDispRecipeItem()
{
	if(STUDY_RECIPE_ID == -1)
		{ return; }
	
	const recipeitem = W.lookupItem("recipe_item", STUDY_RECIPE_ID);
	
	var tablestr = `
		<table class="basic-table"  width="70%">
		<tr>
		<th>Category</th>
		<th>Ingredient</th>
		<th>Quantity</th>
		<th>Notes</th>
		<th>...</th>
		</tr>
	`;
	
	const ingrlist = W.getItemList("ingredient");
	
	ingrlist.forEach(function(ritem) {
		
		if(ritem.getRecipeId() != STUDY_RECIPE_ID)
			{ return; }
			
			
		const rowstr = `
			<tr>
			<td>${ritem.getCategory()}</td>
			<td>${ritem.getIngrName()}</td>
			<td>${ritem.getQuantity()}</td>
			<td>${ritem.getNotes()}</td>
			<td>
			<a href="javascript:studyIngredient(${ritem.getId()})">
			<img src="/u/shared/image/inspect.png" height="18"/></a>
			
			&nbsp; &nbsp;
			
			<a href="javascript:deleteIngredient(${ritem.getId()})">
			<img src="/u/shared/image/remove.png" height="18"/></a>			
			
			
			</td>
			</tr>
		`;
		
		tablestr += rowstr;
	});
	
	
	tablestr += `</table>`;
	
	const nameheader = `<h2>${recipeitem.getRecipeName()}</h2>`;
	
	populateSpanData({
		"recipe_info" : tablestr,
		"recipe_name_header" : nameheader
	
	});	
	
	
}


function reDispMainTable()
{
	var tablestr = `
		<table class="basic-table"  width="60%">
		<tr>
		<th>Recipe</th>
		<th>#Items</th>
		<th>...</th>
		</tr>
	`;
	
	const recipes = W.getItemList("recipe_item");
	
	const counts = getRecipeItemCounts();
	
	recipes.forEach(function(ritem) {
		
		if(ritem.getIsActive() != 1) 
			{ return; }

		const ingcount = counts[ritem.getId()];
			
		const rowstr = `
			<tr>
			<td>${ritem.getRecipeName()}</td>
			<td>${ingcount}</td>
			<td>
			<a href="javascript:studyRecipe(${ritem.getId()})">
			<img src="/u/shared/image/inspect.png" height="18"/></a>

			&nbsp; &nbsp;
						
			<a href="javascript:addRecipe2List(${ritem.getId()})">
			<img src="/u/shared/image/add.png" height="18"/></a>
			
			&nbsp; &nbsp;
						
			<a href="javascript:cycleRecipeActive(${ritem.getId()})">
			<img src="/u/shared/image/cycle.png" height="18"/></a>

			</td>
			</tr>
		`;
		
		tablestr += rowstr;
			
	});
	
	
	tablestr += `</table>`;
	
	populateSpanData({
		"main_table" : tablestr ,
		"shopping_list_count" : W.getItemList("shopping_list").length
	});
	
}

// These two functions are prevention against chance that you created an ingredient,
// added to shopping list, then deleted ingredient.
function getCategoryOrEmpty(ingrid)
{
	return W.haveItem("ingredient", ingrid) ? W.lookupItem("ingredient", ingrid).getCategory() : "";
}

function getNameOrEmpty(ingrid)
{

	return W.haveItem("ingredient", ingrid) ? W.lookupItem("ingredient", ingrid).getIngrName() : "";
}

function getRecipeItemCounts()
{
	var counts = {};

	W.getItemList("recipe_item").forEach(function(ritem) {
		counts[ritem.getId()] = 0;
	});
	
	W.getItemList("ingredient").forEach(function(ingr) {
				
		const recpid = ingr.getRecipeId();

		// should not be necessary, but I am paranoid			
		if(!(recpid in counts))
			{ counts[recpid] = 0; }
		
		counts[recpid] += 1;
	});
	
	return counts;
}


function reDispShoppingList()
{
	var tablestr = `
		<table class="basic-table"  width="60%">
		<tr>
		<th>Category</th>
		<th>Item</th>
		<th>Quantity</th>
		<th>Of Recipe</th>
		<th>...</th>
		</tr>
	`;
	
	const shoplist = W.getItemList("shopping_list");
	
	shoplist.sort(proxySort(shop => [getCategoryOrEmpty(shop.getIngrId()), getNameOrEmpty(shop.getIngrId())]));
	
	shoplist.forEach(function(shop) {

		if(!W.haveItem("ingredient", shop.getIngrId()))
			{ return; }
			
		const ingr = W.lookupItem("ingredient", shop.getIngrId());

		const recipe = W.lookupItem("recipe_item", ingr.getRecipeId());
			
		const rowstr = `
			<tr>
			<td>${ingr.getCategory()}</td>			
			<td>${ingr.getIngrName()}</td>
			<td>${ingr.getQuantity()}</td>
			<td>${recipe.getRecipeName()}</td>			
			<td>
			<a href="javascript:deleteShoppingItem(${shop.getId()})">
			<img src="/u/shared/image/remove.png" height="18"/></a>
			</td>
			</tr>
		`;
		
		tablestr += rowstr;			
			
	});
	
	
	tablestr += `</table>`;
	
	populateSpanData({"shopping_list_info" : tablestr });	
	
}

</script>

</head>

<body onLoad="javascript:redisplay()">

<center>

<span class="page_component" id="main_list">

<h2>Recipe List</h2>

<a href="javascript:viewShoppingList()">s'ping list</a>
<br/>
(<span id="shopping_list_count"></span> items)


<div id="main_table"></div>

<br/>

<a class="css3button" onclick="javascript:newRecipe()">+RECP</a>


</span>

<span class="page_component" id="study_recipe">


<span id="recipe_name_header"></span>



<br/>
<a href="javascript:back2Main()">main</a>
<br/>

<div id="recipe_info"></div>

<br/><br/>

<a class="css3button" onclick="javascript:addIngredient()">+INGR</a>



</span>

<span class="page_component" id="study_ingredient">

<h2>Ingredient Info</h2>


<div id="ingredient_info"></div>


<br/><br/>



</span>          

<span class="page_component" id="shopping_list">

<h2>Shopping List</h2>

<a href="javascript:back2Main()">main</a>

<div id="shopping_list_info"></div>

<br/>

<a class="css3button" onclick="javascript:clearShoppingList()">CLEAR</a>

</span>




<br/>



</center>
</body>
</html>
