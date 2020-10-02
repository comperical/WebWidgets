#!/usr/bin/python3

import os 
import sys
import shutil

import ArgMap

def get_domain_prefix(local=False):
	return "http://localhost:8080" if local else "https://danburfoot.net"

def get_config_map(username=None):
	
	assert username != None, "Default not yet implemented"
	
	from os.path import expanduser
	homedir = expanduser("~")	
	configpath = "{}/.ssh/{}__widget.conf".format(homedir, username)
	assert os.path.exists(configpath), "Could not find config file at {}".format(configpath)
	
	def genconf():
		for line in open(configpath):			
			if line.strip().startswith("#") or not "=" in line:
				continue
				
			k, v = line.strip().split("=")
			yield k.strip(), v.strip()


	configmap = { k : v for k, v in genconf() }
	assert 'accesshash' in configmap
	return configmap	
	
def get_db_path(dbdir, widget):
	assert widget.lower() == widget
	dbfile = "{}_DB.sqlite".format(widget.upper())
	return os.sep.join([dbdir, dbfile])

if __name__ == "__main__":

	
	argmap = ArgMap.getFromArgv(sys.argv)
	username = argmap.getStr("username")
	dbdir = argmap.getStr("dbdir", "/opt/userdata/lifecode/datadir/userdb/{}".format(username))
	
	local = argmap.getBit("local", False)
	assert os.path.exists(dbdir), "DB directory {} does not exist".format(dbdir)
	
	widget = argmap.getStr("widget")
	
	configmap = get_config_map(username)
	print("Config is {}".format(configmap))

	dbpath = get_db_path(dbdir, widget)
	assert not os.path.exists(dbpath), "DB path {} already exists, please delete or move first".format(dbpath)
	
	domainpref = get_domain_prefix(local)
	url = "{}/life/pull2you?username={}&widget={}&accesshash={}".format(domainpref, username, widget, configmap['accesshash'])	
	
	curlcall = "curl  \"{}\" --output {}".format(url, dbpath)
	print(curlcall)
	os.system(curlcall)