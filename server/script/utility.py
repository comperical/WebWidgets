
import re
import os
import sys

from pathlib import Path

def get_core_package_list():
	return ["shared", "core"]

def get_install_base_dir():
	thisdir = Path(__file__).parent
	assert thisdir.name == "script"
	assert thisdir.parent.name == "server"
	return str(thisdir.parent.parent)


def get_java_src_dir():
	return os.path.sep.join([get_install_base_dir(), "server", "java"])

def get_working_dir():
	return os.path.sep.join([get_install_base_dir(), "server", "workdir"])

def get_jar_file_dir():
	return os.path.sep.join([get_install_base_dir(), "server", "jarfiles"])

def get_java_class_dir():
	return os.path.sep.join([get_working_dir(), "jclass"])

def get_jar_list():
	jardir = get_jar_file_dir()

	def genjar(): 
		for onefile in os.listdir(jardir):
			if onefile.endswith(".jar"):
				yield os.path.sep.join([jardir, onefile])

	return list(genjar())

def get_compile_class_path():

	classlist = [] + get_jar_list() + [get_java_class_dir()]
	return ":".join(classlist)


def classes_from_dir(topdir):
	for reldir, _, fnames in os.walk(topdir):
		for fn in fnames:
			if not fn.endswith(".class"):
				continue
			
			fullpath = "{}/{}".format(reldir, fn)
			assert fullpath.startswith(topdir)
			relpath = fullpath[len(topdir):]
			
			classtoks = relpath.split("/")
			if len(classtoks[0]) == 0:
				classtoks = classtoks[1:]
				
			yield ".".join(classtoks)


# Map of short package name to directory path
def get_package_info():

	def geninfo():
		for dirpath, _, filenames in os.walk(get_java_src_dir()):
			for fname in filenames:
				if not fname.endswith(".java"):
					continue

				package = Path(dirpath)
				yield package.name, str(package)


	pinfo = { name : fullpath for name, fullpath in geninfo() }
	return pinfo