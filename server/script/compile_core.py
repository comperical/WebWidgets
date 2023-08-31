#!/usr/bin/python3

import re
import os
import sys
from zipfile import ZipFile

import utility as UTIL

def generateQualifiedClassNames():
	if shouldUseJar():
		yield from classesFromZip(getWidgetJarPath())
	else:
		yield from classesFromDir(getLifeClassDir())
	

	
def findTargetClass(partial, exact=True):
	
	for oneclass in generateQualifiedClassNames():
			
		# Previously checked to see if the subclass was one of a special list

		probe = "${}".format(partial)
			
		if not probe in oneclass:
			continue
			
		if exact and not oneclass.endswith(probe + ".class"):
			continue
		
		yield oneclass
	

def build_directory(shortpack, srcdir):

	jclassdir = UTIL.get_java_class_dir()
	assert os.path.exists(jclassdir)

	jcompcall = f"""
	javac -Xlint:deprecation -Xlint:unchecked -d {jclassdir} -cp {UTIL.get_compile_class_path()} {srcdir}/*.java
	"""
	print(jcompcall)
	os.system(jcompcall)

if __name__ == "__main__":

	print("Going to look at compile info")
	print(UTIL.get_java_src_dir())

	packinfo = UTIL.get_package_info()
	print(packinfo)


	for shortpack in UTIL.get_core_package_list():
		assert shortpack in packinfo, f"Missing directory for package {shortpack}"
		build_directory(shortpack, packinfo[shortpack])

