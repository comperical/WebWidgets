#!/usr/bin/python3

import re
import os
import sys
from zipfile import ZipFile

import utility as UTIL


# Transclass is the fully qualified class name, it must be on the classpath
# This will just be called by Class.forName(...) in the driver code
def run_class(fullclass, extrainfo):
	
	assert "$" in fullclass, f"Expected to see a Java INNER class, got {fullclass}"	

	# Swap out the dollar sign for a double underscore. This is to ensure the shell
	# Does not try to interpret the $ 
	transclass = fullclass.replace("$", "__")

	classpath = UTIL.get_compile_class_path()

	runcall = f"java -cp {classpath} io.webwidgets.core.LifeCli {transclass} {extrainfo}"
	print(runcall)
	os.system(runcall)


if __name__ == "__main__":

	extrainfo = " ".join(sys.argv)	
	if len(sys.argv) <= 1:
		print("Usage: widget_runner.py <InnerClassName>")
		quit()

	shortclass = sys.argv[1]
	extraargs = sys.argv[2:]

	lookup = UTIL.build_subclass_lookup()
	classlist = lookup.get(shortclass, [])
	
	if len(classlist) == 0:
		print("Could not find any class with short name {}".format(shortclass))
		quit()
		
	if len(classlist) > 1:
		print("Found MULTIPLE fully classes with same short name: {}".format(classlist))
		print("Please rename one of them!!!")
		quit()
		
	run_class(classlist[0], " ".join(extraargs))

