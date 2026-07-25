#!/usr/bin/python3

import os 
import sys
import shutil
import time

import ArgMap
import CodePush

from zipfile import ZipFile

MAX_AGE_SECONDS = 60 * 60

	
class DataPush(CodePush.AssetUploader):
	
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
		return os.path.exists(self.get_db_path())
	

	def check_modtime(self):

		payload = self.get_payload_path()
		modtime = os.path.getmtime(payload)
		age_seconds = time.time() - modtime
		age_minutes = round(age_seconds / 60)

		okaypush = age_seconds <= MAX_AGE_SECONDS

		refmssg = f"""
Refusing to push {payload}, last modified {age_minutes} minutes ago.
As a precaution against data overwriting, we block uploads of SQLite files that are older than 1 hour.
You should probably delete local and re-pull from server. You can also run:
touch {payload}
This will update the DB file modtime.
		"""

		if not okaypush:
			print(refmssg)
			sys.exit(1)

	def do_prep(self):
		pass

if __name__ == "__main__":
	
	argmap = ArgMap.getFromArgv(sys.argv)
	CodePush.check_update_username(argmap)

	username = argmap.getStr("username")
	
	configmap = CodePush.get_config_map(username)
	dbdir = argmap.getStr("dbdir", configmap.get("dbdir", ""))
	assert dbdir != None and len(dbdir) > 0, "You must specify a dbdir config setting, either in config file, or in command line via dbdir="
	assert os.path.exists(dbdir), "DB directory {} does not exist".format(dbdir)
		
	# This is hacky
	argmap.put("basedir", dbdir)
	
	uploader = DataPush(argmap)
	uploader.find_base_dir(configmap)
	uploader.ensure_okay()

	uploader.check_modtime()
	
	if uploader.widget == "mailbox":
		mssg = f"""The mailbox DB can only be downloaded, not uploaded. This is to prevent abuse of the mail system.
		Please see {CodePush.WWIO_DOCS_URL} for more information
		""".replace("\t", " ")


		print(mssg)
		quit()

	
	uploader.do_prep()
	uploader.ensure_okay(postprep=True)

	uploader.do_upload(configmap)
	uploader.do_cleanup()
	
	
