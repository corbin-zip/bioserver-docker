#!/bin/bash

mysqld_safe --pid-file=mysqld.pid --socket=/run/mysqld/mysqld.sock --log-error=mysqld_error.log &
# sleep so mysql fully starts & we can run mysql commands in a moment
# NOTE: i could possibly utilize /var/lib/mysql/bioserver[1] to check if the commands
# successfully ran or not. if they failed, wait 1s, try again, repeat let's say 10 times.
# this might be more elegant than just a flat 5s wait
sleep 5s

# only execute these configuration settings on first run:
if [ ! -f /root/already-configured ]; then
	sed -i '26iLD_LIBRARY_PATH="/opt/openssl-1.0.2/lib:$LD_LIBRARY_PATH"' /opt/apache/bin/envvars
	# replace {{CONTAINER_IP}} & {{EXTERNAL_IP}} with hostname -i
	# NOTE: i need a way for the user to specify any IP they want
	# but i -think- that listen-address should be local? could be wrong, need to test
	sed -i "s/{{CONTAINER_IP}}/$(hostname -i)/g" /etc/dnsmasq.d/obcomsrv
	sed -i "s/{{EXTERNAL_IP}}/$(hostname -i)/g" /root/bioserver/bioserv1/config.properties
	sed -i "s/{{EXTERNAL_IP}}/$(hostname -i)/g" /root/bioserver/bioserv2/config.properties
	sed -i "s/#listen-address=/listen-address=$(hostname -i),127.0.0.1/g" /etc/dnsmasq.conf

	# use sed to uncomment these 4 lines inside of httpd.conf
	sed -i '116s/^#//; 120s/^#//; 133s/^#//; 152s/^#//' /opt/apache/conf/httpd.conf
	# also need to do a sed for User and Group:
	sed -i 's/User daemon/User www-data/g' /opt/apache/conf/httpd.conf
	sed -i 's/Group daemon/Group www-data/g' /opt/apache/conf/httpd.conf

	# dump this configuration at the end of httpd.conf:
	cat /root/end_of_httpd.conf >>/opt/apache/conf/httpd.conf

	# set up mysql
	mysql -u root </root/bioserver/bioserv1/database/bioserver.sql
	mysql -u root </root/bioserver/bioserv2/database/bioserver.sql

	# mark this container as configured (so it does not run this configuration again)
	touch /root/already-configured
fi

# start services dnsmasq, apache, and php-fpm7.4
/usr/sbin/dnsmasq --log-facility=/var/log/dnsmasq.log --log-queries --conf-file=/etc/dnsmasq.d/obcomsrv
/opt/apache/bin/apachectl -d /opt/apache/ -f /opt/apache/conf/httpd.conf -k start -e info
php-fpm7.4 -D

# start up file 1 & 2 servers
cd /root/bioserver/bioserv1/
./run_file1.sh &
cd /root/bioserver/bioserv2/
./run_file2.sh

#exec /bin/bash
