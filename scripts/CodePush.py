#!/usr/bin/python3

import os 
import sys
import shutil

import ArgMap

from zipfile import ZipFile

CONFIG_MAP_OKAY_KEYS = ["accesshash", "dbdir", "codedir1", "codedir2", "codedir3"]

SUBFOLDER_NAME = ".ssh"


def get_domain_prefix(local=False):
	return  "https://webwidgets.io"

def get_config_directory():
	from os.path import expanduser
	homedir = expanduser("~")
	return os.path.sep.join([homedir, SUBFOLDER_NAME])

def get_widget_config_path(username):
	filename = "{}__widget.conf".format(username)
	return os.path.sep.join([get_config_directory(), filename])


def check_update_username(argmap):
	username = find_username(argmap)
	argmap.put("username", username)

def find_username(argmap):

	candidates = get_username_configs()

	# Okay, the user decided to specify in the command line, respect that
	if argmap.containsKey("username"):
		username = argmap.getStr("username")
		assert username in candidates, "User name {} not found in config list, options are {}".format(username, str(candidates))
		return username


	# Okay we found the username from the config files, because there's only one proper config file.
	if len(candidates) == 1:
		return candidates[0]

	# Special treatment for admin user :-)
	if "dburfoot" in candidates:
		print("Defaulting to admin user name")
		return "dburfoot"

	assert False, "System could not find the username from config files, please specify on command line using username= option"


def get_username_configs():

	def gencands():
		for onefile in os.listdir(get_config_directory()):
			if onefile.endswith("__widget.conf"):
				yield onefile.split("__")[0]

	return list(gencands())

def get_config_map(username):
	
	configpath = get_widget_config_path(username)
	assert os.path.exists(configpath), "Could not find config path for user {}, you must put your config file at path {}".format(username, configpath)
	
	def genconf():
		for line in open(configpath):			
			if line.strip().startswith("#") or not "=" in line:
				continue
				
			k, v = line.strip().split("=")
			yield k.strip(), v.strip()


	configmap = { k : v for k, v in genconf() }
	assert 'accesshash' in configmap, "Require an accesshash parameter in configuration file"

	for k, _ in configmap.items():
		assert k in CONFIG_MAP_OKAY_KEYS, "Unknown configuration parameter '{}' in file, options are {}".format(k, CONFIG_MAP_OKAY_KEYS)

	return configmap	


class AssetUploader:
	
	def __init__(self, argmap):
		
		self.widget = argmap.getStr("widgetname")
		self.username = argmap.getStr("username")
		self.local = argmap.getBit("local", False)
		self.basedir = None

	def ensure_okay(self):
		assert self.basedir != None, "Failed to find a good base directory in config"
		#assert os.path.exists(self.get_widget_dir()), "Widget directory {} does not exists".format(self.get_widget_dir())


	def compose_curl_call(self, configmap):
		# curl  --request POST --form name=@TabCompleter.py http://localhost:8080/life/push2me?hello=world
		payload = self.get_payload_path()
		extend = self.get_file_type()
		acchash = configmap['accesshash']
		domainpref = get_domain_prefix(local=self.local)
		assert os.path.exists(payload), "Payload path {} does not exist".format(payload)
		return "curl --request POST --form payload=@{}  --form filetype={} --form username={} --form widget={} --form accesshash={} {}/u/push2me".format(payload, extend, self.username, self.widget, acchash, domainpref)
	
	def do_upload(self, configmap):
		curlcall = self.compose_curl_call(configmap)
		# print(curlcall)
		os.system(curlcall)

	def do_cleanup(self):
		pass

class ZipUploader(AssetUploader):
	
	def __init__(self, argmap):
		
		super().__init__(argmap)
		
	def get_file_type(self):
		return "widgetzip"
		
	def find_base_dir(self, configmap):

		def genprobes():
			for idx in range(1, 6):
				codekey = "codedir{}".format(idx)
				if not codekey in configmap:
					continue

				probe = os.path.sep.join([configmap[codekey], self.widget])
				if os.path.exists(probe):
					yield configmap[codekey]

		probelist = list(genprobes())
		assert len(probelist) >  0, "Failed to find widget named {} in and code directories".format(self.widget)
		assert len(probelist) == 1, "Found multiple directories for widget {} :: {}".format(self.widget, probelist)
		self.basedir = probelist[0]


	def get_zip_path(self, extension=False):
		extstr = ".zip" if extension else ""
		return os.sep.join([self.basedir, "__" + self.widget + extstr])
	
	def get_widget_dir(self):
		return os.sep.join([self.basedir, self.widget])
		
	def do_prep(self):
		self.create_archive()
		
	def get_payload_path(self):
		return self.get_zip_path(extension=True)

	def do_cleanup(self):
		paypath = self.get_payload_path()
		if os.path.exists(paypath):
			os.remove(paypath)
		
		#print("Deleted {}".format(paypath))

	def create_archive(self):
		widgetdir = self.get_widget_dir()
		assert os.path.exists(self.basedir), "Base directory {} does not exist".format(self.basedir)
		assert os.path.exists(widgetdir), "Widget directory {} does not exist".format(widgetdir)
		
		zpath = self.get_zip_path()
		shutil.make_archive(zpath, 'zip', widgetdir)
		
class BaseUploader(AssetUploader):
	
	def __init__(self, argmap):
		
		super().__init__(argmap)
		
	def get_zip_path(self, extension=False):
		extstr = ".zip" if extension else ""
		return os.sep.join(["__" + self.widget + extstr])
		
	def get_file_type(self):
		return "basezip"	

	def find_base_dir(self, configmap):
		assert 'codedir1' in configmap, "You must have a property codedir1 in your configuration file"
		self.basedir = configmap['codedir1']
			
	def do_prep(self):
		self.create_archive()
		
	def get_payload_path(self):
		return self.get_zip_path(extension=True)

	def do_cleanup(self):
		paypath = self.get_payload_path()
		if os.path.exists(paypath):
			os.remove(paypath)
			print("Cleaned {}".format(paypath))

		

	def create_archive(self):
		assert os.path.exists(self.basedir), "Base directory {} does not exist".format(self.basedir)
		
		zpath = self.get_zip_path(extension=True)

		with ZipFile(zpath, 'w') as myzip:
			for myfile in os.listdir(self.basedir):

				# Gotcha: the __base.zip goes into this directory, avoid recursively adding the file to itself
				if myfile.endswith(".zip"):
					continue

				fullpath = os.sep.join([self.basedir, myfile])
				if os.path.isdir(fullpath):
					continue
					
				#print("Full path is {}".format(fullpath))
				# Need the arcname= argument to give the files the right location in the archive.
				myzip.write(fullpath, arcname=myfile)


if __name__ == "__main__":
	
	argmap = ArgMap.getFromArgv(sys.argv)
	check_update_username(argmap)

	configmap = get_config_map(argmap.getStr('username'))

	widget = argmap.getStr("widgetname")
	uploader = BaseUploader(argmap) if widget == "base" else ZipUploader(argmap)
	uploader.find_base_dir(configmap)
	uploader.ensure_okay()

	# print("Going to run upload for type {}".format(uploader.__class__.__name__))
	
	uploader.do_prep()
	uploader.do_upload(configmap)
	uploader.do_cleanup()
		