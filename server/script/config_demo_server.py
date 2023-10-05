#!/usr/bin/python3

import re
import os
import sys
from zipfile import ZipFile

import utility as UTIL


def get_resin_config_xml():


    """
<!--
   - Resin 4.0 configuration file.
  -->
<resin xmlns="http://caucho.com/ns/resin"
       xmlns:resin="urn:java:com.caucho.resin">

  <!-- property-based Resin configuration -->
  <resin:properties path="${__DIR__}/resin.properties" optional="true"/>
  <resin:properties path="cloud:/resin.properties"
                    optional="true" recover="true"/>


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
    <resin:import path="cloud:/admin-users.xml" optional="true" recover="true"/>
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
     - Configures the main application cluster.  Load-balancing configurations
     - will also have a web cluster.
    -->
  <cluster id="app">
    
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
        
        <web-app id="/" root-directory="/opt/userdata/lifecode/wwiosite">
          <welcome-file-list>index.jsp</welcome-file-list>
        </web-app>

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

  <cluster id="web">
    <!-- define the servers in the cluster -->
    <server-multi id-prefix="web-" address-list="${web_servers}" port="6810"/>

    <host id="" root-directory="web">
      <web-app id="">
        <resin:LoadBalance regexp="" cluster="app"/>
      </web-app>
      
      <web-app id="/async">
        <resin:LoadBalance regexp="" cluster="app"/>
      </web-app>
    </host>
  </cluster>

  <cluster id="memcached" xmlns:memcache="urn:java:com.caucho.memcached">
    <!-- define the servers in the cluster -->
    <server-multi id-prefix="memcached-" address-list="${memcached_servers}" port="6820">
      <!-- listen for the memcache protocol -->
      <listen port="${memcached_port?:11211}"
              keepalive-timeout="600s" socket-timeout="600s">
        <memcache:MemcachedProtocol/>
      </listen>
    </server-multi>
  </cluster>
  
  <cluster id="proxycache">
    <!-- define the servers in the cluster -->
    <server-multi id-prefix="proxycache-" address-list="${proxycache_servers}" port="6830"/>

    <host id="" root-directory="proxycache">
      <web-app id="">
        <resin:HttpProxy regexp=".*">
          <!-- backend HTTP servers to proxy to -->
          <addresses>${backend_servers}</addresses>
        </resin:HttpProxy>
      </web-app>
    </host>
  </cluster>

</resin>
    """


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