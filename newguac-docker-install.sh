#!/bin/bash
# Newguac on CentOS7
# Depends on AWS CLI, RDS MySQL instance, Instance provisioned with NewGuac-Linux-wSTIG.yml CF template, MySQL backup file provided from existing Guac

#set variables manually
#consider secret storage alternatives
VERSION="0.9.13"
echo 
read -s -p "Enter the username that will be used for MySQL Root account: " MYSQLROOTUSERNAME 
echo
read -s -p "Enter the password that will be used for MySQL Root account: " MYSQLROOTPASSWORD
echo
read -s -p "Enter the username that will be used for the Guacamole database: " GUACDBUSERNAME
echo
read -s -p "Enter the password that will be used for the Guacamole database: " GUACDBUSERPASSWORD
echo
read -s -p "Enter the DNS name that will be used to access the Guacamole database: " GUACDBDNS
echo
# Determine best mirror, or set manually
#SERVER=$(curl -s 'https://www.apache.org/dyn/closer.cgi?as_json=1' | jq --raw-output '.preferred|rtrimstr("/")')
SERVER="http://mirrors.sonic.net/apache/"

#Install Requirements
yum makecache fast
yum -y update
yum install -y yum-utils device-mapper-persistent-data lvm2 mysql wget curl yum-cron
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

#swap firewalld to iptables
#reference https://www.digitalocean.com/community/tutorials/how-to-migrate-from-firewalld-to-iptables-on-centos-7
mkdir /var/lock/subsys
systemctl stop firewalld
systemctl disable firewalld
yum -y install iptables-services
systemctl start iptables && systemctl enable iptables

#Install Docker
yum -y install docker-ce

#set docker to use /opt/extra/docker instead of /var/lib
#reference https://linuxconfig.org/how-to-move-docker-s-default-var-lib-docker-to-another-directory-on-ubuntu-debian-linux
mkdir /opt/extra/docker
cp -R /var/lib/docker/* /opt/extra/docker/
rm -rf /var/lib/docker
ln -s /opt/extra/docker /var/lib/docker

#Start and enable docker, then set cloudwatch logging and restart docker
systemctl enable docker
systemctl start docker
aws s3 cp s3://newguac/daemon.json /etc/docker/daemon.json
systemctl restart docker

#Database setup
#Wipe existing DB and User, Create Guac DB, Guac User, Grant Privs, Restore from backup, Delete local backup file
aws s3 cp s3://newguac/backupTTEguacDB.sql /opt/extra/backupTTEguacDB.sql
mysqladmin -f -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD drop TTEGuacamoleDB
echo "drop user '$GUACDBUSERNAME'@'%';" | mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD
mysqladmin -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD create TTEGuacamoleDB
echo "create user '$GUACDBUSERNAME'@'%' identified by '$GUACDBUSERPASSWORD';" | mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD
echo "GRANT SELECT,INSERT,UPDATE,DELETE ON TTEGuacamoleDB.* TO '$GUACDBUSERNAME'@'%';" | mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD
echo "flush privileges;" | mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD
mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD TTEGuacamoleDB < backupTTEguacDB.sql
rm /opt/extra/backupTTEguacDB.sql

# Download the guacamole auth files for MySQL
cd /opt/extra
wget ${SERVER}/incubator/guacamole/${VERSION}-incubating/binary/guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
tar -xvf guacamole-auth-jdbc-${VERSION}-incubating.tar.gz

# Update the database schema to the verion of Guac being installed
cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/upgrade/upgrade-pre-0.9.10.sql | mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD TTEGuacamoleDB
cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/upgrade/upgrade-pre-0.9.11.sql | mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD TTEGuacamoleDB
cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/upgrade/upgrade-pre-0.9.13.sql | mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD TTEGuacamoleDB
#remove auth download
rm -rf guacamole-auth-jdbc-${VERSION}-incubating*

#Create guacamole home and extensions directories and populate them
mkdir -p /opt/extra/guachome/extensions
aws s3 cp s3://newguac/guac-extensions.jar /opt/extra/guachome/extensions/guac-extensions.jar
aws s3 cp s3://newguac/guacamole.properties /opt/extra/guachome/guacamole.properties
chmod 400 /opt/extra/guachome/extensions/guac-extensions.jar
chmod 400 /opt/extra/guachome/guacamole.properties

##next version, use compose to launch guac
#Launch guacd container
docker run --restart=always --name guacd -d guacamole/guacd

#Launch guacamole container
docker run --restart=always --name guacamole --link guacd:guacd -e MYSQL_HOSTNAME=$GUACDBDNS -e MYSQL_DATABASE=TTEGuacamoleDB -e MYSQL_USER=$GUACDBUSERNAME -e MYSQL_PASSWORD=$GUACDBUSERPASSWORD -v /opt/extra/guachome:/opt/extra/guachome:ro -e GUACAMOLE_HOME=/opt/extra/guachome --detach -p 8080:8080 guacamole/guacamole

#install cron job to periodically wipe tomcat webapps that may get recreated with various docker operations that rebuild the guacamole container from scratch
aws s3 cp s3://newguac/tomcatwipe.cron /etc/cron.hourly/tomcatwipe.cron
chmod 500 /etc/cron.hourly/tomcatwipe.cron

#Enable yum cron to auto apply security patches
sed -i 's/update_cmd = default/update_cmd = security/g' /etc/yum/yum-cron.conf
sed -i 's/apply_updates = no/apply_updates = yes/g' /etc/yum/yum-cron.conf
systemctl restart yum-cron.service

#Disable FIPS if enabled so that yum-cron and cloudwatch agent will work
fipsvalue=`cat /proc/sys/crypto/fips_enabled`
if [ $fipsvalue -gt 0 ]
then
  sed -i 's/fips=1/fips=0/' /etc/default/grub
  grub2-mkconfig > /boot/grub2/grub.cfg
  reboot
fi



