

<html>
<head>
<title>Photo Manager</title>

<%= DataServer.basicInclude(request) %>

<script>

var EDIT_STUDY_ITEM = -1;

var SYNC_TARGET_ID = -1;

function deleteBlobItem(itemid)
{
  const victim = W.lookupItem("photo_main", itemid);

  if(confirm(`Are you sure you want to delete photo ${victim.getBlobFileName()}?`)) 
  {
    const newitem = W.lookupItem("photo_main", itemid);
    newitem.deleteItem();
    redisplay();    
  }
}

function back2Main()
{
  EDIT_STUDY_ITEM = -1;
  redisplay();
}

function editShortName()
{
  genericEditTextField("photo_main", "short_name", EDIT_STUDY_ITEM);
}

function editNoteInfo()
{
  genericEditTextField("photo_main", "full_desc", EDIT_STUDY_ITEM);
}


function isBlobReady(blobitem)
{
  return getBlobFileSize(blobitem) != -1;
}

function getBlobFileSize(blobitem)
{
  const base64 = blobitem.getBase64BlobData();

  if(!base64.startsWith("b10bf00d::"))
    { return -1; }

  const tokens = base64.split("::");
  return parseInt(tokens[1]);
}

function refreshAfterUpload()
{
  window.location.reload();
}

function checkUploadAndGo()
{
    const uploadel = getUniqElementByName("uploadMe");
    const filename = uploadel.files[0].name;
    
    if(!confirm(`Okay to upload file ${filename}?`))
        { return; }

    const reader = new FileReader();
    reader.readAsDataURL(uploadel.files[0]);
    reader.onload = function () {
         // console.log(reader.result);
        updateAttachmentContent(reader.result, filename);
    };

    reader.onerror = function (error) {
        console.log('Error: ', error);
    };
}

function updateAttachmentContent(base64data, filename)
{
  ///CREATE TABLE photo_main (id int, short_name varchar(20), tag_list varchar(30), photo_date varchar(10), base64_blob_data varchar(1000), blob_file_name varchar(100), primary key(id));

    const newrec = {
        "short_name" : "NotYetSet",
        "full_desc" : "...",
        "tag_list" : "",
        "photo_date" : getTodayCode().getDateString(),
        "description" : "---",
        "base64_blob_data" : base64data,
        "blob_file_name" : filename
    };


    const item = W.buildItem("photo_main", newrec);
    SYNC_TARGET_ID = item.getId();
    item.syncItem();
}

function ajaxRequestUserCallBack(opurl, opname, itemid)
{
  if(itemid == SYNC_TARGET_ID)
  {
    alert("Upload complete, going to reload page");
    window.location.reload();
  }
}


function editStudyItem(itemid)
{
  EDIT_STUDY_ITEM = itemid;
  redisplay();
}

function getFileThenExtension(photoitem)
{
  const tokens = photoitem.getBlobFileName().split(".");
  massert(tokens.length == 2, "Expected 2 file tokens, got " + photoitem.getBlobFileName());
  return tokens;
}

function getCoreFileName(photoitem)
{
  return getFileThenExtension(photoitem)[0];
}


function editCoreFileName()
{
  const studyitem = W.lookupItem("photo_main", EDIT_STUDY_ITEM);
  const file_ext = getFileThenExtension(studyitem);
  const newcore = prompt("Enter new core file name:", file_ext[0]);

  if(newcore)
  {
    const fullname = `${newcore}.${file_ext[1]}`;
    studyitem.setBlobFileName(fullname);
    studyitem.syncItem();
    redisplay();
  }
}

function redisplay()
{
  const pageinfo = EDIT_STUDY_ITEM == -1 ? redisplayMain() : redisplayEdit();

  populateSpanData({"pageinfo" : pageinfo});
}

function redisplayEdit()
{

  const item = W.lookupItem("photo_main", EDIT_STUDY_ITEM);
  const blobstore = item.getBlobStoreUrl();



  var pageinfo = `
      <h3>Photo Details</h3>

      <br/>
      <br/>

      <table class="basic-table" width="60%">

      <tr>
      <td><b>Back</b></td>
      <td></td>
      <td>
      <a href="javascript:back2Main()"><img src="/u/shared/image/leftarrow.png" height="18"/></a>
      </td>
      </tr>


      <tr>
      <td><b>Name</b></td>
      <td>${item.getShortName()}</td>
      
      <td>
      <a href="javascript:editShortName()"><img src="/u/shared/image/edit.png" height="18"/></a>
      </td>

      </tr>
      <tr>
      <td><b>Description</b></td>
      <td>${item.getFullDesc()}</td>
      <td>

      <a href="javascript:editNoteInfo()"><img src="/u/shared/image/edit.png" height="18"/></a>
      </td>
      </tr>

      <tr>
      <td><b>File Name</b></td>
      <td>${getCoreFileName(item)}</td>
      <td>

      <a href="javascript:editCoreFileName()"><img src="/u/shared/image/edit.png" height="18"/></a>
      </td>
      </tr>


      <tr>
      <td><b>Activity Date</b></td>
      <td>${item.getPhotoDate()}</td>
      <td>

      <a href="javascript:editEventDate()"><img src="/u/shared/image/edit.png" height="18"/></a>
      </td>
      </tr>

      </table>



      <br/>
      <br/>

      <img src="${blobstore}&download=false" width="60%"/>

  `;

  return pageinfo;
}

function redisplayMain()
{

  var pageinfo = `

    <h2>Photo Manager</h2>

    <label for="file-upload" class="custom-file-upload">
        <i class="fa fa-cloud-upload"></i> New Photo
    </label>
    <input id="file-upload" type="file" name="uploadMe" onChange="javascript:checkUploadAndGo()"/>
    <br/>
    <br/>


    <table class="basic-table" width="60%">
    <tr>
    <th>ID</th>
    <th>Ready?</th>
    <th>File Size</th>
    <th>FileName</th>
    <th>...</th>
  `;

  W.getItemList("photo_main").forEach(function(item) {

    const startblob = item.getBase64BlobData().substring(0,10);

    // This is the special auto-attached function
    const blobstore = item.getBlobStoreUrl();

    const readystr = isBlobReady(item) ? "Y" : "N";

    const filesize = getBlobFileSize(item);

    const rowinfo = `
      <tr>
      <td>${item.getId()}</td>
      <td>${readystr}</td> 
      <td>${filesize}</td>
      <td>${item.getBlobFileName()}</td>
      <td>

      <a href="javascript:editStudyItem(${item.getId()})"><img src="/u/shared/image/inspect.png" height="18"/></a>

      &nbsp;
      &nbsp;
      &nbsp;


      <a href="${blobstore}"><img src="/u/shared/image/download.png" height="18"/></a>

      &nbsp;
      &nbsp;
      &nbsp;

      <a href="javascript:deleteBlobItem(${item.getId()})"><img src="/u/shared/image/remove.png" height="18"/></a>

      </td>      
      </tr>
    `;

    pageinfo += rowinfo;

  });


  pageinfo += `
    </table>
  `;

  return pageinfo;

}

</script>


<style>
input[type="file"] {
    display: none;
}
.custom-file-upload {
    border: 3px solid #ccc;
    border-color: black;
    background-color:  white;
    display: inline-block;
    padding: 6px 12px;
    cursor: pointer;
}
</style>

</head>

<body onLoad="javascript:redisplay()">

<center>




<span id="pageinfo"></span>

</center>
</body>
</html>
