
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


# Get directories that are 
def get_install_peer_dir(peername):
	repodir = Path(get_install_base_dir()).parent
	return os.path.sep.join([str(repodir), peername])

def get_widget_code_dir():
	return get_install_peer_dir("widgetserve")

def get_widget_db_dir():
	return get_install_peer_dir("db4widget")

def get_web_inf_dir():
	return os.path.sep.join([get_widget_code_dir(), "WEB-INF"])

# TODO: this should probably go in a client/ subdirectory
# It is important to know this path to import the ArgMap utility
def get_client_script_dir():
	return os.path.sep.join([get_install_base_dir(), "scripts"])

def get_java_src_dir():
	return os.path.sep.join([get_install_base_dir(), "server", "java"])

def get_working_dir():
	return os.path.sep.join([get_install_base_dir(), "server", "workdir"])

def get_base_config_dir():
	return os.path.sep.join([get_working_dir(), "config"])

def get_jar_file_dir():
	return os.path.sep.join([get_working_dir(), "jarfiles"])

def get_java_class_dir():
	return os.path.sep.join([get_working_dir(), "jclass"])

def get_jar_list():
	jardir = get_jar_file_dir()

	def genjar(): 
		for onefile in os.listdir(jardir):
			if onefile.endswith(".jar"):
				yield os.path.sep.join([jardir, onefile])

	return list(genjar())


def od_setup_working_dir():
	for mydir in [get_working_dir(), get_jar_file_dir(), get_java_class_dir()]:
		if not os.path.exists(mydir):
			os.mkdir(mydir)
			print(f"Created directory {mydir}")

def get_compile_class_path(jclassdir=get_java_class_dir()):

	classlist = [] + get_jar_list() + [jclassdir]
	return ":".join(classlist)


def build_subclass_lookup():

	topdir = get_java_class_dir()

	def gen_lookup():
		for reldir, _, fnames in os.walk(topdir):
			for fn in fnames:
				if not fn.endswith(".class"):
					continue

				if not "$" in fn:
					continue
				
				# Peel off ".class" suffix
				fullpath = "{}/{}".format(reldir, fn[:-len(".class")])
				assert fullpath.startswith(topdir)
				relpath = fullpath[len(topdir):]
				
				classtoks = relpath.split("/")
				if len(classtoks[0]) == 0:
					classtoks = classtoks[1:]
					
				fullclass = ".".join(classtoks)
				shortname = fullclass.split("$")
				assert len(shortname) == 2
				yield (shortname[1], fullclass)


	lookup = {}
	for shortname, fullclass in gen_lookup():
		lookup.setdefault(shortname, [])
		lookup[shortname].append(fullclass)

	return lookup


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