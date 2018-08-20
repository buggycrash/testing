#!/bin/bash
# Update the database in RDS
#Create Guac DB, Guac User, Restore from backup

#set variables
VERSION="0.9.13"
SERVER="http://mirrors.sonic.net/apache/"
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

# May need to test exact method for delimiting variables in quotes
aws s3 cp s3://newguac/backupTTEguacDB.sql /opt/extra/backupTTEguacDB.sql
mysqladmin -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD create TTEGuacamoleDB
echo "GRANT SELECT,INSERT,UPDATE,DELETE ON TTEGuacamoleDB.* TO '$GUACDBUSERNAME'@'%';" | mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD
mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD TTEGuacamoleDB < backupTTEguacDB.sql
rm /opt/extra/backupTTEguacDB.sql

# Download the guacamole auth files for MySQL
cd /opt/extra
wget ${SERVER}/incubator/guacamole/${VERSION}-incubating/binary/guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
tar -xvf guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
#cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/*.sql | mysql -u guac_auth -p$MYSQLROOTPASSWORD -h guac-data.cb0upjasogcj.us-gov-west-1.rds.amazonaws.com -P 3306 guacamole_db
# attempt to run then in one line, or do multiples if necessary below
#cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/upgrade-pre-0.9.[10-13].sql | mysql -h $GUACDBDNS --ssl -u $GUACDBUSERNAME -p$GUACDBUSERPASSWORD TTEGuacamoleDB

cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/upgrade/upgrade-pre-0.9.10.sql | mysql -h $GUACDBDNS --ssl -u $GUACDBUSERNAME -p$GUACDBUSERPASSWORD TTEGuacamoleDB
cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/upgrade/upgrade-pre-0.9.11.sql | mysql -h $GUACDBDNS --ssl -u $GUACDBUSERNAME -p$GUACDBUSERPASSWORD TTEGuacamoleDB
cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/upgrade/upgrade-pre-0.9.12.sql | mysql -h $GUACDBDNS --ssl -u $GUACDBUSERNAME -p$GUACDBUSERPASSWORD TTEGuacamoleDB
cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/upgrade/upgrade-pre-0.9.13.sql | mysql -h $GUACDBDNS --ssl -u $GUACDBUSERNAME -p$GUACDBUSERPASSWORD TTEGuacamoleDB
#remove auth download
rm -rf guacamole-auth-jdbc-${VERSION}-incubating*