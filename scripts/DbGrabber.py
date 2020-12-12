#!/usr/bin/python3

import os 
import sys
import shutil

import ArgMap
import CodeUploader


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

if __name__ == "__main__":

	argmap = ArgMap.getFromArgv(sys.argv)
	CodeUploader.check_update_username(argmap)

	# Widgetname and username are required
	username = argmap.getStr("username")
	widget = argmap.getStr("widgetname")	
	local = argmap.getBit("local", False)
	configmap = CodeUploader.get_config_map(username)

	dbdir = lookup_db_dir(argmap, configmap)
	assert os.path.exists(dbdir), "DB directory {} does not exist".format(dbdir)
	
	dbpath = get_db_path(dbdir, widget)
	if argmap.getBit("deleteold", False) and os.path.exists(dbpath):
		os.remove(dbpath)
		print("Deleted old DB path {}".format(dbpath))
	
	assert not os.path.exists(dbpath), "DB path {} already exists, please delete or move first, or use deleteold=true".format(dbpath)
	
	domainpref = CodeUploader.get_domain_prefix(local)
	url = "{}/life/pull2you?username={}&widget={}&accesshash={}".format(domainpref, username, widget, configmap['accesshash'])	
	
	curlcall = "curl  \"{}\" --output {}".format(url, dbpath)
	os.system(curlcall)
	
	assert os.path.exists(dbpath), "Curl call failed to retrieve DB file to expected path {}".format(dbpath)
	print("Downloaded DB file to path {}".format(dbpath))