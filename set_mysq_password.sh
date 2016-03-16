#!/bin/bash
logger  "reseting mysql password"
if [ -f /home/ubuntu/.my.cnf ] ; then
  exit 0
fi
apt-get install pwgen
NEW_PW=`pwgen 8 1`
mysqladmin -u root -psupersecret password $NEW_PW
cat << EOF > /home/ubuntu/.my.cnf
[client] 
socket=/tmp/mysql.sock
user = root
password = $NEW_PW
EOF
chown ubuntu:ubuntu /home/ubuntu/.my.cnf
logger  "mysql password reset complete"
