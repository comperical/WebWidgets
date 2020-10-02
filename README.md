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
Currently only one pair is supported, the `accesshash`,

```
bash-3.2$ cat ~/.ssh/dburfoot__widget.conf 
accesshash=0123456789abcdfe0123456789abcdf
```


Usage:

```
python DbGrabber.py username=dburfoot dbdir=/path/to/my/widget/directory widget=danswidget
```

This command will upload the DB file for the widget `danswidget` from the directory `/path/to/my/widget/directory`,
	for the user `dburfoot`.
The full path to the DB file must be  `/path/to/my/widget/directory/DANSWIDGET_DB.sqlite`.


### JavaScript Library

