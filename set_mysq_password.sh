#!/bin/bash
logger  "reseting mysql password"
if [ -f /home/ubuntu/.my.cnf ] ; then
  exit 0
fi
export DEBIAN_FRONTEND=noninteractive
apt-get install pwgen
NEW_PW=`pwgen -1cns`
mysqladmin -u root -psupersecret password $NEW_PW
cat << EOF > /home/ubuntu/.my.cnf
[client] 
user = root
password = $NEW_PW
EOF
chown ubuntu:ubuntu /home/ubuntu/.my.cnf
logger  "mysql password reset complete"
/etc/init.d/mysql stop
grep -q  /data01 /proc/mounts
if [ $? -eq 0 ] ; then
  mkdir /data01/mysql_server
  ( cd /var/lib/; tar cf -  mysql ) | ( cd /data01/mysql_server/ ; tar xfp -)
  mv /var/lib/mysql /var/lib/mysql.old
  ln -s /data01/mysql_server/mysql /var/lib/mysql
fi
# 512MB for the OS and then 80% of the rest
INNODB=`cat /proc/meminfo | awk '/MemTotal:/ {printf("%d", .8*(($2-(512*1024)))/1024)}'`
sed -e 's/^# . InnoDB.*$/# \* InnoDB \ninnodb_buffer_pool_size = '$INNODB'M/'  -i /etc/mysql/my.cnf 
/etc/init.d/mysql start



