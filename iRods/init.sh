#!/bin/bash
exec > /root/output
exec 2> /root/output2

postgres(){
cat > /root/create_user.txt<<EOF  
CREATE USER $IRODS_USER WITH PASSWORD '$DB_PASS' ;
CREATE DATABASE "$DATABASE_NAME";
GRANT ALL PRIVILEGES ON DATABASE "$DATABASE_NAME" TO $IRODS_USER;
EOF

su - postgres -c psql - < /root/create_user.txt

}

#if additional storage found then it should be mounted
#and the vault should be stored on the additional storage
#so that if the machine is destroy the data might be retained
#for a period of time
resource(){
DISK="/data1"

if [ -d "${DISK}" ]; then
mkdir -p "${DISK}"/iRODS
mkdir -p "${DISK}"/iRODS/Vault
mkdir -p "${DISK}"/iRODS/postgresql/9.3/main
su - irods -c "/var/lib/irods/iRODS/irodsctl stop"
/etc/init.d/postgresql stop
(cd /var/lib/irods/iRODS/Vault; tar cf - . ) | (cd "${DISK}"/iRODS/Vault; tar xpf -)
(cd /var/lib/postgresql/9.3/main ; tar cf - . ) | (cd "${DISK}"/iRODS/postgresql/9.3/main; tar xpf -)
rm -rf /var/lib/irods/iRODS/Vault /var/lib/postgresql/9.3/main
ln -s /data1/iRODS/postgresql/9.3/main /var/lib/postgresql/9.3/main 
ln -s /data1/iRODS/Vault /var/lib/irods/iRODS/Vault 
/etc/init.d/postgresql start 
su - irods -c "/var/lib/irods/iRODS/irodsctl start"
fi
}


create_user(){

sed -i -e 's/127.0.0.1 localhost/127.0.0.1 localhost '$(hostname)'/' /etc/hosts
yes $IRODS_PASS | sudo adduser $IRODS_USER  --gecos "" --home "/var/lib/irods/"

mkdir /home/$IRODS_USER
touch /home/$IRODS_USER/.odbc.ini

echo "iRODS Password: $IRODS_PASS" > "/home/$IRODS_USER/README_FIRST"
chmod 0600 "/home/$IRODS_USER/README_FIRST"


mkdir -p /var/lib/irods/.ssh
cat /var/tmp/irods_key.pub >> /var/lib/irods/.ssh/authorized_keys

chown -R $IRODS_USER:$IRODS_USER  /var/lib/irods/
chown -R $IRODS_USER:$IRODS_USER /home/$IRODS_USER

}

build(){

cat >> /etc/irods/service_account.config <<-EOF
IRODS_SERVICE_ACCOUNT_NAME=$IRODS_USER
IRODS_SERVICE_GROUP_NAME=$IRODS_USER
EOF


chown $IRODS_USER:$IRODS_USER -R /etc/irods/


VAULT=/var/lib/irods/iRODS/Vault

cat <<-EOF | /var/lib/irods/packaging/setup_irods.sh 
tempZone
1247
20000
20199
$VAULT


1248


$IRODS_USER
$IRODS_PASS

$(hostname)
$DB_PORT
$DATABASE_NAME
$IRODS_USER
$DB_PASS

EOF

}



DATABASE_NAME="IRODS_DB"
IRODS_USER="ubuntu"
DB_PASS=$(pwgen 8 1)
IRODS_PASS=$(pwgen 8 1)
DB_PORT=5432

main(){
create_user
postgres
build
resource
chmod 0000 $0
}

main
