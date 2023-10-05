#!/usr/bin/python3

import re
import os
import sys
from zipfile import ZipFile

import utility as UTIL


def create_main_dir_layout():



    dirlist = [UTIL.get_widget_code_dir(), UTIL.get_web_inf_dir(), UTIL.get_widget_db_dir()]
    for onedir in dirlist:
        if not os.path.exists(onedir):
            print(f"Creating directory {onedir}")
            os.mkdir(onedir)


def rebuild_symlink(filename, target, istest=False):

    webinf = UTIL.get_web_inf_dir()
    suffix = "__test" if istest else ""
    fullpath = os.path.sep.join([webinf, filename+suffix])

    if os.path.exists(fullpath):
        print(f"removed old path {fullpath}")
        os.remove(fullpath)

    os.symlink(target, fullpath)
    print(f"Build symlink {fullpath} --> {target}")

def create_web_inf_link():

    rebuild_symlink("classes", UTIL.get_java_class_dir())
    rebuild_symlink("lib", UTIL.get_jar_file_dir())


if __name__ == "__main__":

    print("going to config demo server")

    create_main_dir_layout()

    create_web_inf_link()