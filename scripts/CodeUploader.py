#!/usr/bin/python3

import os 
import sys
import shutil

import ArgMap
import DbGrabber

from zipfile import ZipFile


class CodeUploader:
	
	def __init__(self, argmap):
		
		self.basedir = argmap.getStr("basedir")
		self.widget = argmap.getStr("widget")
		self.username = argmap.getStr("username")
		self.local = argmap.getBit("local", False)
						
	def compose_curl_call(self, configmap):
		# curl  --request POST --form name=@TabCompleter.py http://localhost:8080/life/push2me?hello=world
		payload = self.get_payload_path()
		extend = self.get_file_type()
		acchash = configmap['accesshash']
		domainpref = DbGrabber.get_domain_prefix(local=self.local)
		assert os.path.exists(payload), "Payload path {} does not exist".format(payload)
		return "curl --request POST --form payload=@{}  --form filetype={} --form username={} --form widget={} --form accesshash={} {}/life/push2me".format(payload, extend, self.username, self.widget, acchash, domainpref)
	
	def do_upload(self, configmap):
		curlcall = self.compose_curl_call(configmap)
		# print(curlcall)
		os.system(curlcall)

	def do_cleanup(self):
		pass

class ZipUploader(CodeUploader):
	
	def __init__(self, argmap):
		
		super().__init__(argmap)
		
	def get_file_type(self):
		return "widgetzip"
		
	def get_zip_path(self, extension=False):
		extstr = ".zip" if extension else ""
		return os.sep.join([self.basedir, "__" + self.widget + extstr])
	
	def get_widget_dir(self):
		return os.sep.join([self.basedir, self.widget])
	
	def is_okay(self):
		return os.path.exists(self.get_widget_dir())	
	
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
		
class BaseUploader(CodeUploader):
	
	def __init__(self, argmap):
		
		super().__init__(argmap)
		
	def get_zip_path(self, extension=False):
		extstr = ".zip" if extension else ""
		return os.sep.join(["__" + self.widget + extstr])
		
	def get_file_type(self):
		return "basezip"		
		
	def is_okay(self):
		return self.widget == "base"
	
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
				fullpath = os.sep.join([self.basedir, myfile])
				print("Full path is {}".format(fullpath))
				# Need the arcname= argument to give the files the right location in the archive.
				
				myzip.write(fullpath, arcname=myfile)
		
	
class DbUploader(CodeUploader):
	
	def __init__(self, argmap):
		
		super().__init__(argmap)
		
	def get_db_path(self):
		dbname = "{}_DB.sqlite".format(self.widget.upper())
		return os.sep.join([self.basedir, dbname])
		
	def get_file_type(self):
		return "sqlite"		
		
	def get_payload_path(self):
		return self.get_db_path()		
		
	def is_okay(self):
		#print("DB path is {}".format(self.get_db_path()))
		return os.path.exists(self.get_db_path())	
	
	def do_prep(self):
		pass
	


if __name__ == "__main__":
	
	argmap = ArgMap.getFromArgv(sys.argv)
	configmap = DbGrabber.get_config_map(argmap.getStr('username'))
	
	
	probeloaders = [ZipUploader(argmap), DbUploader(argmap), BaseUploader(argmap)]
	probeloaders = [up for up in probeloaders if up.is_okay()]
	
	assert len(probeloaders) > 0, "Neither ZipUploader nor DbUploader are configured properly"
	assert len(probeloaders) == 1, "Somehow BOTH ZipUploader and DbUploader are configured, you should keep DBs in separate directory!!!"
	
	uploader = probeloaders[0]
	print("Going to run upload for type {}".format(uploader.__class__.__name__))
	
	uploader.do_prep()
	uploader.do_upload(configmap)
	uploader.do_cleanup()
		
