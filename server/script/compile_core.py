#!/usr/bin/python3

import re
import os
import sys
from pathlib import Path


import utility as UTIL

JAVA_CODE_INSTALL_DIR_TAG = "WWIO_CONFIG_DIR_GOES_HERE"

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

	swap_install_dir_string(shortpack, True)

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

	swap_install_dir_string(shortpack, False)


def opt_create_dummy_config():

	pluginpath = os.path.sep.join([UTIL.get_base_config_dir(), "PluginConfig.props"])
	if os.path.exists(pluginpath):
		return

	pardir = Path(pluginpath).parent
	if not os.path.exists(pardir):
		pardir.mkdir()


	dummydata = """
# This is a dummy plugin config file.
# The format is Java Properties, see https://docs.oracle.com/javase/8/docs/api/java/util/Properties.html
# You can update this with your own extension classes
BLOB_STORAGE_PLUGIN=
EMAIL_SENDER_PLUGIN=
ADMIN_EXTENSION_PLUGIN=
"""

	with open(pluginpath, 'w') as fh:
		fh.write(dummydata)

	print(f"Wrote dummy plugin config to {pluginpath}")


def swap_install_dir_string(shortpack, swapin):

	if shortpack != "core":
		return

	opt_create_dummy_config()

	srcdir = UTIL.get_java_src_dir()
	srcpath = os.path.sep.join([srcdir, "io", "webwidgets", "core", "CoreUtil.java"])
	assert os.path.exists(srcpath)

	searchfor, swapinstr = (JAVA_CODE_INSTALL_DIR_TAG, UTIL.get_base_config_dir())
	if not swapin:
		searchfor, swapinstr = (swapinstr, searchfor)


	newlines = []
	swapcount = 0

	for line in open(srcpath):
		if searchfor in line:
			line = line.replace(searchfor, swapinstr)
			swapcount += 1

		newlines.append(line)

	assert swapcount > 0, f"Failed to find the string {searchfor} in file {srcpath}"
	assert swapcount == 1, f"Found string {searchfor} multiple times in file {srcpath}, must be present exactly once"

	with open(srcpath, 'w') as fh:
		for line in newlines:
			fh.write(line)

	if not swapin:
		print(f"Swapped install dir {UTIL.get_base_config_dir()} into src code, and back out again")


if __name__ == "__main__":


	# For now, no special options here, just compile both the small packages


	for shortpack in UTIL.get_core_package_list():
		build_directory(shortpack)

