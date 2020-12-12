#!/usr/bin/python3

import os 
import sys
import shutil

import ArgMap
import CodeUploader

from zipfile import ZipFile
	
class DbUploader(CodeUploader.AssetUploader):
	
	def __init__(self, argmap):
		
		super().__init__(argmap)
		
	def get_db_path(self):
		dbname = "{}_DB.sqlite".format(self.widget.upper())
		return os.sep.join([self.basedir, dbname])
		
	def get_file_type(self):
		return "sqlite"		
		
	def find_base_dir(self, configmap):
		self.basedir = configmap["dbdir"]
		
	def get_payload_path(self):
		return self.get_db_path()		
		
	def is_okay(self):
		#print("DB path is {}".format(self.get_db_path()))
		return os.path.exists(self.get_db_path())	
	
	def do_prep(self):
		pass

if __name__ == "__main__":
	
	argmap = ArgMap.getFromArgv(sys.argv)
	CodeUploader.check_update_username(argmap)

	username = argmap.getStr("username")
	
	configmap = CodeUploader.get_config_map(username)
	dbdir = argmap.getStr("dbdir", configmap.get("dbdir", ""))
	assert dbdir != None and len(dbdir) > 0, "You must specify a dbdir config setting, either in config file, or in command line via dbdir="
	assert os.path.exists(dbdir), "DB directory {} does not exist".format(dbdir)
		
	# This is hacky
	argmap.put("basedir", dbdir)
	
	uploader = DbUploader(argmap)
	uploader.find_base_dir(configmap)
	uploader.ensure_okay()
	
	
	uploader.do_prep()
	uploader.do_upload(configmap)
	uploader.do_cleanup()
	
	