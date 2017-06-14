#!/bin/bash

# Install the Infor ION Grid on a CentOS droplet at DigitalOcean
# https://m3ideas.org/2017/06/13/building-an-infor-grid-lab-part-7/

# Usage:
# 1) Setup SSH from your computer to the droplet
# 2) From your computer, copy the Grid installer to the droplet's ~/Downloads/
#        scp ~/Downloads/Grid_Installer_11.1.13.0.77.lcm root@108.101.101.116:~/Downloads/
# 3) From your computer, execute the installation script:
#        ssh root@108.101.101.116 curl https://raw.githubusercontent.com/M3OpenSource/InforGridLab/master/Part7/install.sh | bash -s
# Note: change the droplet's public IP address accordingly, e.g. 108.101.101.116
export INSTALLER=~/Downloads/Grid_Installer_11.1.13.0.77.lcm
if (test ! -f "$INSTALLER"); then
	echo -e "Missing $INSTALLER"
	exit;
fi

# install the JDK
yum --assumeyes install java-1.8.0-openjdk-devel

# unzip the installer
cd ~/Downloads/
jar xvf $INSTALLER
cd ~

# install PostgreSQL
yum --assumeyes install postgresql-server
postgresql-setup initdb

# setup password authentication for PostgreSQL
sed --in-place \
-e "s/host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            md5/" \
-e "s/host    all             all             ::1\/128                 ident/host    all             all             ::1\/128                 md5/" \
/var/lib/pgsql/data/pg_hba.conf


# start and enable PostgreSQL
systemctl start postgresql
systemctl enable postgresql

# set the PostgreSQL password
sudo -u postgres psql -c "ALTER USER postgres with encrypted password 'password123';"

# create the Grid database
sudo -u postgres createdb InforIONGrid

# create the user and group for the Grid service
groupadd grid
useradd -g grid grid

# get the droplet's external IP address
IPADDR=$(ifconfig eth0 | awk '/inet /{print substr($2,1)}')

# create the installer.properties
java -jar ~/Downloads/products/Infor_ION_Grid_11.1.13.0/components/installer-1.13.77.jar -console -options-template ~/Downloads/installer.properties

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
java -jar ~/Downloads/products/Infor_ION_Grid_11.1.13.0/components/installer-1.13.77.jar -console -options ~/Downloads/installer.properties
