#!/bin/bash

# This script installs and sets up the WWIO demo server
# It should get the server to the point where it can be used in demo mode
# The demo server uses the community version of Resin (http://www.caucho.com)
# But this codebase should work with any JSP/Java-compliant app server, such as Tomcat
# Important: this script puts the server in non-secure mode to allow testing without configuring SSL
# Obviously, you should put it into secure mode and turn on SSL for production use
# The WWIO code is intended to be used with minimal configuration
# After running this script, you should be able to access http://YOUR_HOST_NAME/u/testuser/index.jsp
# And be able to view and edit some basic Widgets (chores, links, etc)


# Create sub directory /opt/userdata
sudo mkdir /opt/userdata

# Change ownership to ec2-user
sudo chown ec2-user /opt/userdata

# Java 11 install with YUM
sudo yum install java-11-amazon-corretto -y

#Install Python3
sudo yum install python37 -y

#Forward port trick, workaround for Unix permission issue, see http://serverfault.com/questions/112795/how-can-i-run-a-server-on-linux-on-port-80-as-a-normal-user
sudo /sbin/iptables -t nat -I PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080

#Forward port trick, workaround for Unix permission issue, see http://serverfault.com/questions/112795/how-can-i-run-a-server-on-linux-on-port-80-as-a-normal-user
sudo /sbin/iptables -t nat -I PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443

#Install Unix Htop Utility
sudo yum install htop -y

# Install GIT source control package
sudo yum install git -y

# Grab WWIO core source code, contains net.danburfoot.shared package
git clone https://github.com/comperical/WebWidgets.git /opt/userdata/WebWidgetDemo

# WWIO-core does not package jars in repo, it must download them
python3 /opt/userdata/WebWidgetDemo/server/script/download_jars.py  >> download_jars.txt 2>> download_jars.err

# Compile WWIO-core packages
python3 /opt/userdata/WebWidgetDemo/server/script/compile_core.py  >> compile_core.txt 2>> compile_core.err

# Configure the WWIO demo server
python3 /opt/userdata/WebWidgetDemo/server/script/config_demo_server.py  >> config_demo_server.txt 2>> config_demo_server.err

# Configure the installation to allow insecure connections. This is off by default. Demo only, do not use in prod!
python3 /opt/userdata/WebWidgetDemo/server/script/widget_runner.py ToggleInsecureAllow fastconfirm=true >> widget_runner.txt 2>> widget_runner.err

# Setup the MASTER DB. Must do this before creating users
python3 /opt/userdata/WebWidgetDemo/server/script/widget_runner.py SetupMasterDb  >> widget_runner.txt 2>> widget_runner.err

# Pull the shared JS/CSS/etc code from the repo into the serving area
python3 /opt/userdata/WebWidgetDemo/server/script/widget_runner.py CopySharedCodeFromRepo  >> widget_runner.txt 2>> widget_runner.err

# Create a test user for demo
python3 /opt/userdata/WebWidgetDemo/server/script/widget_runner.py AddUserMasterRecord username=testuser >> widget_runner.txt 2>> widget_runner.err

# Update the password for the test user. For users running this script, skip the directpass= command
python3 /opt/userdata/WebWidgetDemo/server/script/widget_runner.py UpdateUserPassWord username=testuser directpass=NewPass1 >> widget_runner.txt 2>> widget_runner.err

# Import core widget _links_ from the gallery for test user
python3 /opt/userdata/WebWidgetDemo/server/script/widget_runner.py ImportWidgetFromGallery username=testuser widgetname=links >> widget_runner.txt 2>> widget_runner.err

# Import core widget _chores_ from the gallery for test user
python3 /opt/userdata/WebWidgetDemo/server/script/widget_runner.py ImportWidgetFromGallery username=testuser widgetname=chores >> widget_runner.txt 2>> widget_runner.err

# Import core widget _mroutine_ from the gallery for test user
python3 /opt/userdata/WebWidgetDemo/server/script/widget_runner.py ImportWidgetFromGallery username=testuser widgetname=mroutine >> widget_runner.txt 2>> widget_runner.err

# Import core widget _questions_ from the gallery for test user
python3 /opt/userdata/WebWidgetDemo/server/script/widget_runner.py ImportWidgetFromGallery username=testuser widgetname=questions >> widget_runner.txt 2>> widget_runner.err

# Import core widget _base_ from the gallery for test user
python3 /opt/userdata/WebWidgetDemo/server/script/widget_runner.py ImportWidgetFromGallery username=testuser widgetname=base >> widget_runner.txt 2>> widget_runner.err

# Show config after all the setup options
python3 /opt/userdata/WebWidgetDemo/server/script/widget_runner.py ShowBaseConfigInfo >> widget_runner.txt 2>> widget_runner.err

# Start the Resin app server
python3 /opt/userdata/WebWidgetDemo/server/script/restart_demo_server.py  >> restart_demo_server.txt 2>> restart_demo_server.err

