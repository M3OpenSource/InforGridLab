#!/bin/bash

# Install the Infor ION Grid on a CentOS droplet at DigitalOcean
# https://m3ideas.org/2017/06/13/building-an-infor-grid-lab-part-7/

export INSTALLER=~/Downloads/installer-1.13.77.jar
if (test ! -f "$INSTALLER"); then
	echo -e "Missing $INSTALLER"
	exit;
fi

# install the JDK
sudo yum --assumeyes install java-1.8.0-openjdk-devel

# install PostgreSQL
sudo yum --assumeyes install postgresql-server
sudo postgresql-setup initdb

# setup password authentication for PostgreSQL
sudo sed --in-place \
-e "s/host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            md5/" \
-e "s/host    all             all             ::1\/128                 ident/host    all             all             ::1\/128                 md5/" \
/var/lib/pgsql/data/pg_hba.conf


# start and enable PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# set the PostgreSQL password
sudo -i -u postgres psql -c "ALTER USER postgres with encrypted password 'password123';"

# create the Grid database
sudo -i -u postgres createdb InforIONGrid

# create the user and group for the Grid service
sudo groupadd grid
sudo useradd -g grid grid

# get the droplet's external IP address
IPADDR=$(ifconfig eth0 | awk '/inet /{print substr($2,1)}')

# create the installer.properties
java -jar ~/Downloads/installer-1.13.77.jar -console -options-template ~/Downloads/installer.properties

# change the properties
sed --in-place \
-e "/install.path=/         s/=.*/=\/opt\/Infor\/InforIONGrid/" \
-e "/jdk.path=/             s/=.*/=\/usr\/lib\/jvm\/java-openjdk/" \
-e "/database.jdbc=/        s/=.*/=jdbc:postgresql:\/\/localhost:5432\/InforIONGrid/" \
-e "/database.username=/    s/=.*/=postgres/" \
-e "/database.password=/    s/=.*/=password123/" \
-e "/database.schema=/      s/=.*/=public/" \
-e "/grid.externaladdress=/ s/=.*/=$IPADDR/" \
-e "/grid.hostname=/        s/=.*/=$HOSTNAME/" \
-e "/grid.internaladdress=/ s/=.*/=$HOSTNAME/" \
-e "/service.username=/     s/=.*/=grid/" \
-e "/service.group=/        s/=.*/=grid/" \
~/Downloads/installer.properties

# install the Grid
sudo java -jar ~/Downloads/installer-1.13.77.jar -console -options ~/Downloads/installer.properties
