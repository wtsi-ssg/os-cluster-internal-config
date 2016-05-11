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
sed -i "s/End     Host/`hostname` !  !     1       -       -\nEnd     Host/" /opt/openlava-3.1/etc/lsf.cluster.openlava
echo "$SERVER_NAME:/home   /home  nfs defaults 0 0" >> /etc/fstab
echo "$SERVER_NAME:/opt/openlava-3.1 /opt/openlava-3.1   nfs defaults 0 0" >> /etc/fstab
mount /home
mount /opt/openlava-3.1 
sed -i "s/End     Host/`hostname` !  !     1       -       -\nEnd     Host/" /opt/openlava-3.1/etc/lsf.cluster.openlava
ln -s /opt/openlava-3.1/etc/openlava /etc/init.d
update-rc.d openlava defaults
(ip addr show dev eth0 | grep "inet " | awk '{print $2}' | awk -F/ '{printf ("%s ",$1)}' ; hostname ) |  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa ubuntu@$SERVER_NAME 'sudo tee -a /etc/hosts'
(ip addr show dev eth0 | grep "inet " | awk '{print $2}' | awk -F/ '{printf ("%s ",$1)}' ; hostname ) |  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa ubuntu@$SERVER_NAME 'sudo tee -a /etc/cloud/templates/hosts.debian.tmpl'
/opt/openlava-3.1/etc/openlava start
sleep 30
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa ubuntu@$SERVER_NAME "sudo /root/add_compute_node_on_head.sh `hostname`"
logger  "Starting cluster client complete"
lsadmin limrestart
sleep 30 
reboot
