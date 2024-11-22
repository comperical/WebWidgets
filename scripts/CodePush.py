#!/usr/bin/python3

import os 
import sys
import shutil
from pathlib import Path

import ArgMap

from zipfile import ZipFile

# Note - this must agree with code below
CONFIG_MAP_OKAY_KEYS = ["accesshash", "dbdir", "codedir1", "codedir2", "codedir3", "codedir4", "codedir5"]

SUBFOLDER_NAME = ".ssh"

WWIO_DOCS_URL = "https://webwidgets.io/u/docs/index.html"

WWIO_USER_ENV_VAR = "WWIO_USER_NAME"

WWIO_HOST_ENV_VAR = "WWIO_HOST_NAME"

# Cannot upload data bigger than this. This number must agree with the value defined in the Java code.
# TODO: probably increase this, 10 Mb seems low
MAX_UPLOAD_SIZE_BYTES = 10_000_000


def get_domain_prefix(local=False):

	if WWIO_HOST_ENV_VAR in os.environ:
		host = os.environ.get(WWIO_HOST_ENV_VAR)
		assert not host.startswith("http"), f"By convention, host name does not start with http prefix"
		print(f"Sending data to host {host}")
		return f"https://{host}"

	return  "https://webwidgets.io"



# Attempt to infer the widgetname from the current directory
# If found, set the widgetname= argument in argmap, if it is not already set
def check_update_widget_cd(configmap, argmap):

	if argmap.containsKey("widgetname"):
		return

	currentdir = Path(os.getcwd())

	for cdidx in range(1, 5):
		cdstr = f"codedir{cdidx}"
		if cdstr in configmap:
			cdpath = Path(configmap[cdstr])

			if cdpath == currentdir.parent:
				infname = currentdir.name.lower()
				argmap.put("widgetname", infname)
				print(f"Inferred widgetname _{infname}_ from current directory")



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
		assert username in candidates, f"User name {username} from command line not found in config list, options are {str(candidates)}"
		return username


	if WWIO_USER_ENV_VAR in os.environ:
		username = os.environ.get(WWIO_USER_ENV_VAR)
		assert username in candidates, f"User name {username} from environment variables not found in config list, options are {str(candidates)}"
		return username


	# Okay we found the username from the config files, because there's only one proper config file.
	if len(candidates) == 1:
		return candidates[0]

	# Special treatment for admin user :-)
	if "dburfoot" in candidates:
		print("Defaulting to admin user name")
		return "dburfoot"

	assert False, f"System could not find the username from config files, please specify on command line using username= option or {WWIO_USER_ENV_VAR} environment variable"


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
		self.securecurl = argmap.getBit("securecurl", True)
		self.basedir = None

	def ensure_okay(self, postprep=False):
		assert self.basedir != None, "Failed to find a good base directory in config"
		#assert os.path.exists(self.get_widget_dir()), "Widget directory {} does not exists".format(self.get_widget_dir())

		if postprep:
			paypath = self.get_payload_path()
			assert os.path.exists(paypath), f"Could not find payload path {paypath}"

			filesize = os.path.getsize(paypath)
			assert filesize <= MAX_UPLOAD_SIZE_BYTES, f"Your upload file {paypath} is too big ({filesize}), the max upload size is {MAX_UPLOAD_SIZE_BYTES}"


	def compose_curl_call(self, configmap):
		# curl  --request POST --form name=@TabCompleter.py http://localhost:8080/life/push2me?hello=world
		payload = self.get_payload_path()
		extend = self.get_file_type()
		acchash = configmap['accesshash']
		domainpref = get_domain_prefix(local=self.local)
		securestr = "" if self.securecurl else " --insecure "

		assert os.path.exists(payload), "Payload path {} does not exist".format(payload)
		return "curl --request POST {} --form payload=@{}  --form filetype={} --form username={} --form widget={} --form accesshash={} {}/u/push2me".format(securestr, payload, extend, self.username, self.widget, acchash, domainpref)
	
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

		# As of Sept 2024, the server excludes the Mac OS .DS_Store files,
		# so it doesn't matter if we include them here
		# This command is very handy, but it doesn't allow me to exclude anything
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

	# Attempt to infer widgetname= argument from current directory, if it is not provided
	check_update_widget_cd(configmap, argmap)

	widget = argmap.getStr("widgetname")
	uploader = BaseUploader(argmap) if widget == "base" else ZipUploader(argmap)
	uploader.find_base_dir(configmap)

	# Little bit weird, do the ensure okay twice, to make sure the .zip is checked
	uploader.ensure_okay()
	uploader.do_prep()
	uploader.ensure_okay(postprep=True)

	# print("Going to run upload for type {}".format(uploader.__class__.__name__))
	
	uploader.do_upload(configmap)
	uploader.do_cleanup()
		