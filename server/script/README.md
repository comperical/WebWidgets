# WWIO Server Scripts and Installation 

This folder contains Python scripts and installation instructions that can be used to install the open-core version of 
WebWidgets.

The requirements for the server are essentially Linux, Java 11, Python 3, and SQLite 3. It should be possible to get the system
to run on Windows, if the user is brave and willing to read the source code: we have endeavored to make the code multi-platform
in as many areas as possible.

The main "significant" piece of additional software required to run WWIO is a Java/JSP compatible app server. This demo version uses [Resin](http://caucho.com). The scripts included in this directory will install and configure an open-source version of Resin for you. You can find a full list of Jakarta/Java EE app servers [here](https://en.wikipedia.org/wiki/Jakarta_EE). Note that WWIO only uses a small subset of the full Jakarta spec (basically the servlet container and JSP components).

The `WwioDemoSetup.sh` shell script contains a series of commands will install a demo version of WWIO from a clean slate.





