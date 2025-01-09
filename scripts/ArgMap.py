
import re, os, sys, fileinput, random

MAGIC_BAD_CODE = -912837465

class ArgMap(dict):


    # This is obviously non-Pythonic, but I found it more intuitive in some cases
    def containsKey(self, onekey):
        return onekey in self

    def put(self, mykey, myval):
        self[mykey] = myval


    # First, check that either the key or the default value is present
    # Second, check that the type of the default value is either None, or equal to the target type
    # If it does not match, compose an error message from a provided function
    # This is a vague gesture in the direction of performance; if you are calling these methods many times,
    # You ideally do not want the string formatting logic to run every time
    def __sub_check_arg(self, onekey, defval, targtype, errfunc):

        if defval == MAGIC_BAD_CODE:
            assert onekey in self, f"Required key {onekey} not found in ArgMap"
            return

        if defval == None:
            return

        if type(defval) != targtype:
            errmssg = errfunc(defval)
            assert False, errmssg


    # Check the arguments and default values
    # Then lookup the result or the default value, and cast to the target type
    def __sub_check_lookup(self, onekey, defval, targtype, errfunc):

        self.__sub_check_arg(onekey, defval, targtype, errfunc)
        rawval = self.get(onekey, defval)
        return None if rawval == None else targtype(rawval)


    def getStr(self, onekey, defval=MAGIC_BAD_CODE):
        return self.__sub_check_lookup(onekey, defval, str, lambda dv: f"Attempt to pass a non-string default value {dv} to getStr(...) method")


    def getDbl(self, onekey, defval=MAGIC_BAD_CODE):
        return self.__sub_check_lookup(onekey, defval, float, lambda dv: f"Attempt to pass a non-float default value {dv} to getDbl(...) method")


    def getInt(self, onekey, defval=MAGIC_BAD_CODE):
        return self.__sub_check_lookup(onekey, defval, int, lambda dv: f"Attempt to pass a non-int default value {dv} to getInt(...) method")



    def getBit(self, onekey, defval=MAGIC_BAD_CODE):

        self.__sub_check_arg(onekey, defval, bool, lambda dv: f"Attempt to pass a non-bool default value {dv} to getBit(...) method")

        if onekey in self:
            oneval = self[onekey].lower()
            assert oneval == 'true' or oneval == 'false', "Expected true or false value, got {}".format(oneval)
            return oneval == 'true'

        return defval


    def size(self):
        return len(self)


    def __str__(self):
        return f"ArgMap::{super().__str__()}"



def getFromArgv(argv):

    amap = ArgMap()

    for onearg in argv:
        if "=" in onearg:
            toks = onearg.split("=")
            amap.put(toks[0], toks[1])
            
    return amap
            
if __name__ == "__main__":

    amap = getFromArgv(sys.argv)
    
    print("Key xint = {}".format(amap.getInt('xint')))

