#!/usr/bin/python3

import os 
import sys
import hashlib
from pathlib import Path

import utility as UTIL

DOWNLOAD_DATA = [
	{
		"mavenurl" : "https://repo1.maven.org/maven2/javax/servlet/javax.servlet-api/4.0.1/javax.servlet-api-4.0.1.jar",
		"md5sum" : "b80414033bf3397de334b95e892a2f44"
	}, {
		"mavenurl" : "https://repo1.maven.org/maven2/com/googlecode/json-simple/json-simple/1.1/json-simple-1.1.jar",
		"md5sum" : "eb342044fc56be9ba49fbfc9789f1bb5"
	}, {
		"mavenurl" : "https://repo1.maven.org/maven2/org/xerial/sqlite-jdbc/3.42.0.0/sqlite-jdbc-3.42.0.0.jar",
		"md5sum" : "6a46db3a6f38043ffb7e6782708cd401"
	}
]


def get_jar_dir():

	myparent = Path(__file__).parent.parent
	jardir = os.path.sep.join([str(myparent), "jarfiles"])

	assert myparent.name == "server", "Expected to be at the server directory"
	assert os.path.exists(jardir), f"Jar directory {jardir} does not exist in expected location"
	return jardir


def get_jar_filename(jaritem):
	jarurl = jaritem["mavenurl"]
	assert jarurl.endswith(".jar")
	return jarurl.split("/")[-1]


def get_jar_destination(jaritem):

	filename = get_jar_filename(jaritem)
	return os.path.sep.join([get_jar_dir(), filename])

def get_curl_command(jaritem):

	jarurl = jaritem["mavenurl"]
	destination = get_jar_destination(jaritem)

	curlcall = f"""
		curl {jarurl} -o {destination}
	"""

	return curlcall

def confirm_checksum(jaritem):

	jarpath = get_jar_destination(jaritem)

	with open(jarpath, 'rb') as fh:
		observed = hashlib.md5(fh.read()).hexdigest()
		expected = jaritem['md5sum']
		assert observed == expected, f"Problem confirming checksums, expected {expected} but observed {observed}"
		print(f"Observed MD5 hash {observed} as expected for file {get_jar_filename(jaritem)}")


if __name__ == "__main__":
	
	UTIL.od_setup_working_dir()

	for jaritem in DOWNLOAD_DATA:
		print(f"Going to grab JAR {get_jar_filename(jaritem)}")

		curlcall = get_curl_command(jaritem)
		os.system(curlcall)
		confirm_checksum(jaritem)


