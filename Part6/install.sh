#!/bin/bash

# Install the Infor ION Grid on Ubuntu and PostgreSQL
# https://m3ideas.org/2017/06/11/building-an-infor-grid-lab-part-6/

# Pre-requisites: download the Grid installer, extract the files, and set this environment variable accordingly
export INSTALLER=~/Downloads/Grid_Installer_11.1.13.0.77.lcm_FILES

# Install PostgreSQL and verify the connection
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib
sudo -u postgres psql -c \\conninfo

# set the PostgreSQL password
sudo -u postgres psql -c "ALTER USER postgres with encrypted password 'password123';"

# Create the Grid database and tables
sudo -u postgres psql -c createdb InforIONGrid
sudo -u postgres psql -d InforIONGrid -c "
CREATE TABLE GRIDCONF (
 GRID varchar(64) NOT NULL,
 TYPE varchar(32) NOT NULL,
 NAME varchar(128) NOT NULL,
 TS numeric(20, 0) NOT NULL,
 DATA bytea NULL,
 SEQID numeric(5, 0) NOT NULL
);
INSERT INTO GRIDCONF (GRID, TYPE, NAME, TS, DATA, SEQID) VALUES ('InforIONGrid', 'runtime' , 'null', 0, '<?xml version=\"1.0\" ?>
<runtime xmlns=\"http://schemas.lawson.com/grid/configuration_v3\">
 <bindings />
 <sessionProviders />
 <routers />
 <contextRoots />
 <propertySettings />
</runtime>', 0);
INSERT INTO GRIDCONF (GRID, TYPE, NAME, TS, DATA, SEQID) VALUES ('InforIONGrid', 'topology' , 'null', 0, '<?xml version=\"1.0\" ?>
<topology xmlns=\"http://schemas.lawson.com/grid/configuration_v3\">
 <hosts>
 <host name=\"localhost\" address=\"127.0.0.1\" gridAgentPort=\"50003\" />
 </hosts>
 <registry host=\"localhost\" port=\"50004\" />
</topology>', 0);
CREATE TABLE grid.APPMAPPINGS (
    GRID varchar(256) NOT NULL,
    NAME varchar(256) NOT NULL,
    HOST varchar(256) NOT NULL,
    ID varchar(64) NULL,
    PENDINGID varchar(64) NULL,
    STATE varchar(32) NOT NULL,
    LOGNAME varchar(256) NULL,
    PROFILENAME varchar(64) NULL,
    PROFILEDATA bytea NULL,
    JVMID varchar(64) NULL
);
CREATE TABLE grid.EXISTING_GRIDS (
    GRID_NAME varchar(64) NOT NULL,
    GRID_VERSION varchar(32) NOT NULL,
    MODIFIED_BY varchar(128) NULL,
    TIMESTAMP numeric(20, 0) NOT NULL
);
INSERT INTO grid.EXISTING_GRIDS (GRID_NAME, GRID_VERSION, MODIFIED_BY, TIMESTAMP) VALUES ('InforIONGrid', 1, 'Thibaud', 0);
"

# create the Grid folder structure
cd ~
mkdir InforIONGrid
cd InforIONGrid
mkdir config
mkdir drivers
mkdir resources
mkdir secure

# copy the JAR files and JDBC driver
cp $INSTALLER/products/Infor_ION_Grid_11.1.13.0/tasks/bcmail-jdk16.jar resources/
cp $INSTALLER/products/Infor_ION_Grid_11.1.13.0/tasks/bcprov-jdk16.jar resources/
cp $INSTALLER/products/Infor_ION_Grid_11.1.13.0/tasks/grid-core.jar resources/
cp $INSTALLER/products/Infor_ION_Grid_11.1.13.0/tasks/grid.httpclient.jar resources/
cp $INSTALLER/products/Infor_ION_Grid_11.1.13.0/tasks/grid.liquibase.jar resources/
cp $INSTALLER/products/Infor_ION_Grid_11.1.13.0/tasks/javax.servlet-api.jar resources/
cp $INSTALLER/products/Infor_ION_Grid_11.1.13.0/components/postgresql-9.3-1101-jdbc41.jar drivers/

# create the XML files
echo '<?xml version="1.0" ?>
<runtime xmlns="http://schemas.lawson.com/grid/configuration_v3">
    <bindings />
    <sessionProviders />
    <routers />
    <contextRoots />
    <propertySettings />
</runtime>
' > config/runtime.xml
echo '<?xml version="1.0" ?>
<topology xmlns="http://schemas.lawson.com/grid/configuration_v3">
    <hosts>
        <host name="localhost" address="127.0.0.1" gridAgentPort="50003" />
    </hosts>
    <registry host="localhost" port="50004" />
</topology>
' > config/topology.xml

# create jdbc.properties
echo '
driverDir=$HOME/InforIONGrid/drivers/
url=jdbc:postgresql://localhost:5432/InforIONGrid
dbType=postgresql
user=postgres
encryptedPwd=cGFzc3dvcmQxMjM=
schema=public
' > config/jdbc.properties

# Create the cryptographic key material
java -cp resources/grid-core.jar:resources/bcprov-jdk16.jar:resources/bcmail-jdk16.jar com.lawson.grid.security.Certificates -create=gridcert -gridname InforIONGrid -gridpassword password123 -gridkeystore secure
java -cp resources/grid-core.jar:resources/bcprov-jdk16.jar:resources/bcmail-jdk16.jar com.lawson.grid.security.Certificates -create=hostcert -gridname InforIONGrid -gridpassword password123 -hostname localhost -gridkeystore secure -hostkeystore secure -role grid-admin -address localhost -address ::1 -address 127.0.0.1 -address example.com -unresolved
java -cp resources/grid-core.jar:resources/bcprov-jdk16.jar:resources/bcmail-jdk16.jar com.lawson.grid.security.Certificates -create=symkey -gridname InforIONGrid -gridkeystore secure -gridpassword password123 -symkeypath secure -hostkeystore secure -hostname localhost

# Start the Grid
java -cp resources/grid-core.jar:resources/bcprov-jdk16.jar:resources/bcmail-jdk16.jar:resources/grid.liquibase.jar:drivers/sqljdbc42.jar:resources/javax.servlet-api.jar:resources/grid.httpclient.jar com.lawson.grid.Startup -registry -configDir . -host localhost -logLevel ALL

# Start the Grid Management Pages
java -jar resources/grid-core.jar

# For the  Configuration Import & Edit
java -cp resources/grid-core.jar:resources/grid.liquibase.jar:drivers/sqljdbc42.jar com.lawson.grid.config.JDBCConfigAreaRuntime ~/InforIONGrid/
java -cp resources/grid-core.jar:resources/grid.liquibase.jar:drivers/sqljdbc42.jar:resources/bcprov-jdk16.jar:resources/bcmail-jdk16.jar com.lawson.grid.config.client.ui.Launch
