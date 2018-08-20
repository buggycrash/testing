VERSION="0.9.13"
GUACDBDNS="guac-mysql-db-002.cb0upjasogcj.us-gov-west-1.rds.amazonaws.com"
MYSQLROOTUSERNAME="guac_master"
MYSQLROOTPASSWORD="Qv8BNA2jeW]Z-J?q"
GUACDBUSERNAME="newguacuser"
GUACDBUSERPASSWORD="Dd+rdf!PDR?q8y*C"
SERVER="http://mirrors.sonic.net/apache/"

aws s3 cp s3://newguac/backupTTEguacDB.sql /opt/extra/backupTTEguacDB.sql
mysqladmin -f -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD drop TTEGuacamoleDB
echo "drop user '$GUACDBUSERNAME'@'%';" | mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD
mysqladmin -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD create TTEGuacamoleDB
echo "create user '$GUACDBUSERNAME'@'%' identified by '$GUACDBUSERPASSWORD';" | mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD
echo "GRANT SELECT,INSERT,UPDATE,DELETE ON TTEGuacamoleDB.* TO '$GUACDBUSERNAME'@'%';" | mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD
echo "flush privileges;" | mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD
mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD TTEGuacamoleDB < backupTTEguacDB.sql

cd /opt/extra
wget ${SERVER}/incubator/guacamole/${VERSION}-incubating/binary/guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
tar -xvf guacamole-auth-jdbc-${VERSION}-incubating.tar.gz

cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/upgrade/upgrade-pre-0.9.10.sql | mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD TTEGuacamoleDB
cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/upgrade/upgrade-pre-0.9.11.sql | mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD TTEGuacamoleDB
cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/upgrade/upgrade-pre-0.9.13.sql | mysql -h $GUACDBDNS --ssl -u $MYSQLROOTUSERNAME -p$MYSQLROOTPASSWORD TTEGuacamoleDB

