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
	

def build_directory(shortpack, outputdir=UTIL.get_java_class_dir()):

	pack2src = UTIL.get_package_info()
	assert shortpack in pack2src, f"Could not find short package name {shortpack} in package layout, options are {pack2src.keys()}"
	srcdir = pack2src[shortpack]

	assert os.path.exists(srcdir), f"Source directory {srcdir} does not exist"
	assert os.path.exists(outputdir), f"Output directory {outputdir} does not exist"

	classpath = UTIL.get_compile_class_path(jclassdir=outputdir)

	jcompcall = f"""
	javac -Xlint:deprecation -Xlint:unchecked -d {outputdir} -cp {classpath} {srcdir}/*.java
	"""
	print(jcompcall)
	os.system(jcompcall)

if __name__ == "__main__":


	# For now, no special options here, just compile both the small packages

	for shortpack in UTIL.get_core_package_list():
		build_directory(shortpack)

