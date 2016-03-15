#!/bin/bash
SERVER_IP=$1
SERVER_NAME=$2
logger  "Starting cluster client setup"
grep -s $SERVER_NAME /etc/hosts > /dev/null 
if [ $? -eq 0 ] ; then
  exit 0
fi
sed -i -e 's/127.0.0.1 localhost//' -e 's/127.0.1.1/127.0.0.1/' /etc/cloud/templates/hosts.debian.tmpl 
echo "$SERVER_IP   $SERVER_NAME" >> /etc/hosts
echo "$SERVER_IP   $SERVER_NAME" >> /etc/cloud/templates/hosts.debian.tmpl
sed -i "s/localhost/$SERVER_NAME/" /opt/openlava-3.1/etc/lsb.hosts
sed -i "s/localhost/$SERVER_NAME !  !     1       -       -\n`hostname`/" /opt/openlava-3.1/etc/lsf.cluster.openlava
echo LSF_MASTER_LIST=\"$SERVER_NAME\" >> /opt/openlava-3.1/etc/lsf.conf 
ln -s /opt/openlava-3.1/etc/openlava /etc/init.d
update-rc.d openlava defaults
chmod -R 700 /root/.ssh /opt/openlava-3.1/work
chown -R root /root/.ssh /opt/openlava-3.1/work
echo "$SERVER_NAME:/home   /home  nfs defaults 0 0" >> /etc/fstab
mount /home
(ip addr show dev eth0 | grep "inet " | awk '{print $2}' | awk -F/ '{printf ("%s ",$1)}' ; hostname ) |  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $SERVER_NAME 'sudo tee -a /etc/hosts'
(ip addr show dev eth0 | grep "inet " | awk '{print $2}' | awk -F/ '{printf ("%s ",$1)}' ; hostname ) |  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $SERVER_NAME 'sudo tee -a/etc/cloud/templates/hosts.debian.tmpl'
echo lsaddhost  `hostname`  |  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $SERVER_NAME
logger  "Starting cluster client complete"

