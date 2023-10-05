#!/usr/bin/python3

import re
import os
import sys
from zipfile import ZipFile

import utility as UTIL


def get_resin_config_xml():


    configxml = """
<resin xmlns="http://caucho.com/ns/resin" xmlns:resin="urn:java:com.caucho.resin">

  <!-- property-based Resin configuration -->
  <resin:properties path="${__DIR__}/resin.properties" optional="true"/>

  <!-- Logging configuration for the JDK logging API -->
  <log-handler name="" level="all" path="stdout:" timestamp="[%y-%m-%d %H:%M:%S.%s]" format=" {${thread}} ${log.message}"/>
   
  <!--
     - level='info' for production
     - 'fine' or 'finer' for development and troubleshooting
    -->
  <logger name="" level="${log_level?:'info'}"/>

  <logger name="com.caucho.java" level="config"/>
  <logger name="com.caucho.loader" level="config"/>

  <!--
     - Default configuration applied to all clusters, including
     - HTTP, HTTPS, and /resin-admin configuration.
    -->
  <resin:import path="${__DIR__}/cluster-default.xml"/>
  
  <!--
     - For production sites, change dependency-check-interval to something
     - like 600s, so it only checks for updates every 10 minutes.
    -->
  <dependency-check-interval>${dependency_check_interval?:'2s'}</dependency-check-interval>

  <!--
     - JSSE default properties
    -->
  <system-property
    jdk.tls.ephemeralDHKeySize="2048"
    jdk.tls.rejectClientInitiatedRenegotiation="true"
    sun.security.ssl.allowUnsafeRenegotiation="false"
    sun.security.ssl.allowLegacyHelloMessages="false"/>
     

  <!--
     - Configures the main application cluster.  Load-balancing configurations
     - will also have a web cluster.
    -->
  <cluster id="app">
    <!-- define the servers in the cluster -->
    <server-multi id-prefix="app-" address-list="${app_servers}"
                  port="6800" watchdog-port="${watchdog_port}"/>


    <!-- the default host, matching any host name -->
    <host id="" root-directory=".">
        <web-app id="/" root-directory="/opt/userdata/lifecode/wwiosite">
          <welcome-file-list>index.jsp</welcome-file-list>
        </web-app>

        <!-- new, all-user generic webapp -->
        <web-app id="/u" root-directory="/opt/userdata/widgetserve">
            <!-- this is the main callback servlet. At some point we will probably have to change this path -->
            <servlet-mapping url-pattern="/callback" servlet-class="io.webwidgets.core.CallBack2Me" />
            
            <!-- this is the main entry point to the extension operations. All non-core Widget operations lead from here -->
            <servlet-mapping url-pattern="/extend" servlet-class="io.webwidgets.extend.ExtensionServe" />
            
            <!-- Blob storage servlet, see private doccode about Blob Data -->
            <servlet-mapping url-pattern="/blobstore" servlet-class="io.webwidgets.core.BlobDataManager$BlobStorageServlet" />
            <servlet-mapping url-pattern="/push2me" servlet-class="io.webwidgets.core.ActionJackson$Push2Me" />
            <servlet-mapping url-pattern="/pull2you" servlet-class="io.webwidgets.core.ActionJackson$Pull2You" />   
            <servlet-mapping url-pattern="/convert2excel" servlet-class="io.webwidgets.core.ActionJackson$ConvertGrabExcel" />  
        </web-app>
    </host>
  </cluster>
</resin>
    """

    return configxml

def write_resin_xml():

    resinpath = UTIL.get_resin_dir()
    resinxml = os.path.sep.join([resinpath, "conf", "resin.xml"])

    with open(resinxml, 'w') as fh:
        fh.write(get_resin_config_xml())

    print(f"Wrote Resin XML to path {resinxml}")

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

    write_resin_xml()



