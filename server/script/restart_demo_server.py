#!/usr/bin/python3

import re
import os
import sys
import subprocess

import utility as UTIL



def look4Resin():
    
    pl = subprocess.Popen(['ps', 'aux'], stdout=subprocess.PIPE).communicate()[0]

    pslist = (str(pl)).split("\n")
    for item in pslist:
        if ('resin' in item) and ('caucho' in item):
            return True


    return False


def find_resin_shell():
    resindir = UTIL.find_resin_dir()
    if resindir == None:
        print("Could not find Resin directory, is it installed in the right place?")
        quit()

    return os.path.sep.join([resindir, "bin", "resin.sh"])


if __name__ == "__main__":

    print("Going to start or restart the demo server")

    foundresin = look4Resin()
    print(f"Resin is running : {foundresin}")
    commstr = "restart" if foundresin else "start"

    resinshell = find_resin_shell()
    restartcall = f"{resinshell} {commstr}"
    os.system(restartcall)
