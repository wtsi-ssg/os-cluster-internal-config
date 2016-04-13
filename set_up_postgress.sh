#!/bin/bash
if [ -f /root/.configured] ; then
  exit 0;
fi
/etc/init.d/postgresql stop
grep -q  /data01 /proc/mounts
if [ $? -eq 0 ] ; then
  if [ -d /data01/postgresql ] ; then
    exit 0
  fi
  /etc/init.d/postgresql stop
  mkdir /data01/postgresql
  ( cd /var/lib/; tar cf -  postgresql ) | ( cd /data01/postgresql/ ; tar xfp -)
  mv /var/lib/postgresql /var/lib/postgresql.old
  ln -s /data01/postgresql/postgresql  /var/lib/postgresql
fi
# 512MB for the OS and then 80% of the rest
SHARED=` cat /proc/meminfo | awk '/MemTotal:/ {printf("%d", 1024*(.8*($2-(512*1024))) )   }'`
PAGE_SIZE=`getconf PAGE_SIZE`
PAGES=`echo $SHARED/$PAGE_SIZE | bc`
echo kernel.shmmax=$SHARED >> /etc/sysctl.conf 
echo kernel.shmall=$PAGES >> /etc/sysctl.conf
echo "Do not delete this file otherwise the system will be reset on reboot" > /root/.configured
reboot
