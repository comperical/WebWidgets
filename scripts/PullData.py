#!/usr/bin/python3

import os 
import sys
import shutil

import ArgMap
import CodePush


def lookup_db_dir(argmap, configmap):

	if argmap.containsKey("dbdir"):
		return argmap.getStr("dbdir")

	if "dbdir" in configmap:
		return configmap["dbdir"]

	assert False, "You must specify a dbdir= parameter in either the command line or the config file"

	
def get_db_path(dbdir, widget):
	assert widget.lower() == widget, "Widget names must be lowercase"
	dbfile = "{}_DB.sqlite".format(widget.upper())
	return os.sep.join([dbdir, dbfile])

# okay, we need to do something special here, otherwise the user might think 
# everything worked okay, even though the contents of the output file are just a 
# couple of text lines saying "Access Denied!!"
def check_sqlite_file_okay(dbfile):

	with open(dbfile, "rb") as f:
	    byte = f.read(16)
	    if byte == b'SQLite format 3\x00':
	    	return True


	print("There was a problem downloading the Widget database:")
	linecount = 0

	for line in open(dbfile):
		print("\t{}".format(line))

		linecount += 1
		if linecount >= 10:
			break

	return False

if __name__ == "__main__":

	argmap = ArgMap.getFromArgv(sys.argv)
	CodePush.check_update_username(argmap)

	# Widgetname and username are required
	username = argmap.getStr("username")
	widget = argmap.getStr("widgetname")	
	local = argmap.getBit("local", False)
	configmap = CodePush.get_config_map(username)

	dbdir = lookup_db_dir(argmap, configmap)
	assert os.path.exists(dbdir), "DB directory {} does not exist".format(dbdir)
	
	dbpath = get_db_path(dbdir, widget)
	if argmap.getBit("deleteold", False) and os.path.exists(dbpath):
		os.remove(dbpath)
		print("Deleted old DB path {}".format(dbpath))
	
	if os.path.exists(dbpath):
		print("**Error** : DB path {} already exists, please delete or move first, or use deleteold=true".format(dbpath))
		quit()
	
	domainpref = CodePush.get_domain_prefix(local)
	url = "{}/u/pull2you?username={}&widget={}&accesshash={}".format(domainpref, username, widget, configmap['accesshash'])	
	
	curlcall = "curl  \"{}\" --output {}".format(url, dbpath)
	os.system(curlcall)
	
	assert os.path.exists(dbpath), "Curl call failed to retrieve DB file to expected path {}".format(dbpath)
	assert check_sqlite_file_okay(dbpath), "Problem downloading DB file"
	print("Success, downloaded DB file to path {}".format(dbpath))