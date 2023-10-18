# WWIO Server Scripts and Installation 

This folder contains Python scripts and installation instructions that can be used to install the open-core version of 
WebWidgets.

The requirements for the server are essentially Linux, Java 11, Python 3, and SQLite 3. It should be possible to get the system
to run on Windows, if the user is brave and willing to read the source code: we have endeavored to make the code multi-platform
in as many areas as possible.

The main "significant" piece of additional software required to run WWIO is a Java/JSP compatible app server. This demo version uses [Resin](http://caucho.com). The scripts included in this directory will install and configure an open-source version of Resin for you. You can find a full list of Jakarta/Java EE app servers [here](https://en.wikipedia.org/wiki/Jakarta_EE). Note that WWIO only uses a small subset of the full Jakarta spec (basically the servlet container and JSP components).

The `WwioDemoSetup.sh` shell script contains a series of commands will install a demo version of WWIO from a clean slate. 
As of October 2023, this script has been tested and is known to work on Amazon Web Services. The script will create a
`testuser` account and import several widgets for that account, so the user can confirm the basic functionality is working.

The open-core version of WWIO does not include support for email, blob storage, or sync with Google docs. EMail and blob storage 
require basically simple integrations, that connect WWIO to your organization's email and blob storage services. Google Sync
is a bit more complex, we may move this into the core code at some point; please reach out if you are interested. 

The configuration for WWIO is intended to be as light as possible. You do not have to deal with any XML, JSON, or other
config files. The only info the Java code needs to know is the location of the installation directory where you checked out the 
repo. This information is inferred by the `compile_core.py` script and spliced into the Java code when it is compiled. All additional config is placed in the `system_setting` table of the main `master` database.

WWIO maintenance and administration is facilitated with a wide variety of command line tools. These are contained in the 
`CoreCommand` Java file. Each command is implemented as an inner class that extends the `ArgMapRunnable` base class
(or one of its variants like `DescRunnable`). These commands take `key=value` arguments. To invoke a WWIO command, write:

```
python3 widget_runner.py RUNNABLE_SIMPLE_CLASSNAME arg1=... arg2=...
```

For example, in the install script, there is a line that reads:
```
python3 widget_runner.py ImportWidgetFromGallery username=testuser widgetname=mroutine
```

This invokes the `ImportWidgetFromGallery` commmand with the given `username` and `widgetname` arguments.


When the demo server starts up, you should be able to browse to the following URL:
```
http://YOUR_HOST_NAME/u/testuser/index.jsp
```

You will see a bare-bones splash page that links to a few simple widgets. Clicking those links will take you to the appropriate widget. You can perform a few operations : create, edit, and delete information. When you make a change, try refreshing the page,
to confirm that the change has persisted. You can also examine the results of the changes by looking at the contents of the 
underlying SQLite files.


