#!/usr/bin/python3

import re
import os
import sys
from zipfile import ZipFile

import utility as UTIL


def get_resin_config_xml():


    configxml = """
<!--
   - Resin 4.0 configuration file.
  -->
<resin xmlns="http://caucho.com/ns/resin"
       xmlns:resin="urn:java:com.caucho.resin">

  <!-- property-based Resin configuration -->
  <resin:properties path="${__DIR__}/resin.properties" optional="true"/>

  <resin:if test="${properties_import_url}">
     <resin:properties path="${properties_import_url}"
                    optional="true" recover="true"/>
  </resin:if>


  <!-- Logging configuration for the JDK logging API -->
  <log-handler name="" level="all" path="stdout:"
               timestamp="[%y-%m-%d %H:%M:%S.%s]"
               format=" {${thread}} ${log.message}"/>
               
  <!-- 
     - Alternative pseudo-TTCC log format
     -
     - <log-handler name="" level="all" path="stdout:"
     -           timestamp="%y-%m-%d %H:%M:%S.%s"
     -           format=" [${thread}] ${log.level} ${log.shortName} - ${log.message}"/>
    -->
   
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
     - health configuration
    -->
  <resin:import path="${__DIR__}/health.xml"/>

  
  <!--
     - Remote management requires at least one enabled admin user.
    -->
  <resin:AdminAuthenticator>
    <user name="${admin_user}" password="${admin_password}"/>
    
    <resin:import path="${__DIR__}/admin-users.xml" optional="true"/>
  </resin:AdminAuthenticator>

  <!--
     - For clustered systems, create a password in as cluster_system_key
    -->
  <cluster-system-key>${cluster_system_key}</cluster-system-key>

  <!--
     - For production sites, change dependency-check-interval to something
     - like 600s, so it only checks for updates every 10 minutes.
    -->
  <dependency-check-interval>${dependency_check_interval?:'2s'}</dependency-check-interval>

  <!-- For resin.properties dynamic cluster joining -->
  <home-cluster>${home_cluster}</home-cluster>
  <home-server>${home_server}</home-server>
  <elastic-server>${elastic_server}</elastic-server>
  <elastic-dns>${elastic_dns}</elastic-dns>

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

    <host-default>
      <!-- creates the webapps directory for .war expansion -->
      <web-app-deploy path="webapps"
                      expand-preserve-fileset="WEB-INF/work/**"
                      multiversion-routing="${webapp_multiversion_routing}"
                      path-suffix="${elastic_webapp?resin.id:''}"/>
    </host-default>

    <!-- auto virtual host deployment in hosts/foo.example.com/webapps -->
    <host-deploy path="hosts">
      <host-default>
        <resin:import path="host.xml" optional="true"/>
      </host-default>
    </host-deploy>

    <!-- the default host, matching any host name -->
    <host id="" root-directory=".">
      <!--
         - webapps can be overridden/extended in the resin.xml
        -->
      <web-app id="/" root-directory="webapps/ROOT"/>

    </host>
      
    <resin:if test="${resin_doc}">
      <host id="${resin_doc_host}" root-directory="${resin_doc_host}">
        <web-app id="/resin-doc" root-directory="${resin.root}/doc/resin-doc"/>
      </host>
    </resin:if>
  </cluster>

  <cluster id="web">
    <!-- define the servers in the cluster -->
    <server-multi id-prefix="web-" address-list="${web_servers}"
                  port="6810" watchdog-port="${watchdog_port}"/>

    <host id="" root-directory="web">
      <web-app id="">
        <resin:LoadBalance regexp="" cluster="app"/>
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



