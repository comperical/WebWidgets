# WebWidgets

Public gallery code and scripts for WebWidgets system. 

### Widget Gallery

This is a gallery of widgets that I have chosen as examples for public demonstration.
Most of them are quite simple, the main exceptions are the `chinese` tools 
	(this is actually a collection of tools) 
	and the `workout` widget, which has some complex logic.
	

The gallery demonstrates several of the following points:

1. Loading the data from the SQLite DB for the widget
1. Including the Authentication and Asset tags
1. Standard create/update/delete operations on records
1. Composition of HTML strings with ES 6 String interpolation.


### Python Scripts

This directory contains Python scripts that can be used to grab widget DB files from the server (`DbGrabber.py`),
	and to upload either DB files or widget code files.
Important: you are expected to maintain, backup, and/or source control your widget code!
The service will backup the DB files, but not the source code. 

Configuration: 

Both of the scripts utilize the same configuration method,
	which requires you to put a file in your SSH directory
	with the name `username__widget.conf`.
This file should contain key=value pairs, one per line.
Currently only one pair is supported, the `accesshash`.
This command illustrates what a proper configuration should look like:

```
bash-3.2$ cat ~/.ssh/dburfoot__widget.conf 
accesshash=0123456789abcdfe0123456789abcdf
```


`DbGrabber` Usage:

```
python DbGrabber.py username=dburfoot dbdir=/path/to/my/widget/directory widget=danswidget
```

This command will grab the DB file for the widget `danswidget` into the directory `/path/to/my/widget/directory`,
	for the user `dburfoot`.
The resulting full path for the DB file will be: 
	`/path/to/my/widget/directory/DANSWIDGET_DB.sqlite`.


`CodeUploader` Usage:


```
python CodeUploader.py username=dburfoot basedir=/path/to/code/or/db/dir widget=danswidget
```

This script will upload *either* a DB file or a widget code directory, 
	depending on what it finds in the `basedir` argument.
If it finds a DB file named `DANSWIDGET_DB.sqlite`, 
	it will upload the single file to the server.
If it finds a directory named `danswidget`, it will zip the contents 
	of the directory and send the zip file to the server.
The server will unzip the contents into the appropriate place.
You can include anything you want in the Zip file, 
	but there is a limit on the maximum size of the upload.
For the standard widget Zip upload,
	the script will include any nested directories it finds in the widget directory.
	
There is a special option to send the base files for the user
	by using the argument `widget=base`.
In this case, the script will collect all the direct child files in the basedir,
	and send the result to the server to be expanded into the user directory.
This enables you to update your `index.jsp` file.
This script does NOT collect any nested directories.


### JavaScript Library

