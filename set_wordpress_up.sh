#!/bin/bash
# The following need to be pulled from the cloud-forms...
# $HOST        - Web hostname
# $MAIL_DOMAIN - Mail domain
# $EMAIL       - Email address of site administrator
# $TITLE       - Web site "title"

export          MYSQL_PASSWORD=`pwgen -1cns`
export   WORDPRESS_DB_PASSWORD=`pwgen -1cns`;
export WORDPRESS_USER_PASSWORD=`pwgen -1cns`;

if [ -f /root/.configured] ; then
  exit 0;
fi
##----------------------------------------------------------------------
## Post boot - Create the wordpress database with a random password!
##----------------------------------------------------------------------

echo 'create database wordpress' | mysql
echo 'grant select,update,delete,create temporary tables,insert,alter,drop,create view,show view,create,index,lock tables,trigger on wordpress.* to "wordpress_admin"@"%" identified by "'$WORDPRESS_DB_PASSWORD'";' | mysql

##----------------------------------------------------------------------
## Post boot - Write wordpress configuration file
##----------------------------------------------------------------------

## Now we write out the wp-config file and include in it the MySQL
## password set up above

cat << EOF > /var/www/html/wp-config.php
<?php
/* Below are the details for the database configuration */
define('DB_NAME',     'wordpress');
define('DB_USER',     'wordpress_admin');
define('DB_PASSWORD', '$WORDPRESS_DB_PASSWORD');
define('DB_HOST',     'localhost');
define('DB_CHARSET',  'utf8');
define('DB_COLLATE',  '');


/* Table prefix (to allow multiple wp sites in one db */

\$table_prefix  = 'wp_';

/* Now for random encryption strings */

EOF

curl https://api.wordpress.org/secret-key/1.1/salt/ >> /var/www/html/wp-config.php

cat << EOF >> /var/www/html/wp-config.php
/* Note: to invalidate all sessions you replace this
   section of the configuration file with new output from:
     https://api.worpress.org/secret-key/1.1/salt/

/* Turn off debug output... set to true to turn on */

define('WP_DEBUG', false);

/* Don't touch below this line - include other settings */

if ( !defined('ABSPATH') ) {
  define('ABSPATH', dirname(__FILE__) . '/');
}

require_once(ABSPATH . 'wp-settings.php');

EOF


##----------------------------------------------------------------------
## Post boot - Perform first reboot configuration of wordpress....
##----------------------------------------------------------------------

curl --header 'Host: '$HOST \
     --data-urlencode "weblog_title=$TITLE" \
     --data-urlencode 'user_name=admin' \
     --data-urlencode "admin_password=$WORDPRESS_USER_PASSWORD" \
     --data-urlencode "pass1-text=$WORDPRESS_USER_PASSWORD" \
     --data-urlencode "admin_password2=$WORDPRESS_USER_PASSWORD" \
     --data-urlencode "admin_email=$EMAIL" \
     --data-urlencode 'blog_public=0' \
     --data-urlencode 'language=en_GB' \
     'http://127.0.0.1/wp-admin/install.php?step=2'

echo $WORDPRESS_USER_PASSWORD > /home/ubuntu/.wordpress.password
echo "Do not delete this file otherwise the system will be reset on reboot" > /root/.configured

##----------------------------------------------------------------------
## Post boot - Reconfigure postfix domain....
##----------------------------------------------------------------------

sed -i s/my_testserver/$MAIL_DOMAIN/ /etc/postfix/main.cf
/etc/init.d/postfix restart 

##----------------------------------------------------------------------
## Post boot - set MySQL password....
##----------------------------------------------------------------------

mysqladmin password $MYSQL_PASSWORD
## Now we set the generated password..
## Store password in /home/ubuntu/.my.cnf so:
## (a) User can log in as root with no password
## (b) Know what password is to set/reset it....

cat << EOF > /home/ubuntu/.my.cnf
[client]
user = root
password = $MYSQL_PASSWORD

; To change your password you can run

;    mysqladmin password

; It is not good policy to leave the root password in this file

EOF

## Make it read write by user only so that it can't be read by others!
chmod 600 /home/ubuntu/.my.cnf
chown ubuntu: /home/ubuntu/.my.cnf

## Write out the motd - with information on how to get db details etc
## and let people know what has been set up

cat << EOF > /etc/motd
###################################################################
##                                                               ##
##  Your wordpress webserver is now set up. To configure it      ##
##  go to the website in your browser and enter the name of      ##
##  the site, and your email address                             ##
##                                                               ##
##  You will find the wordpress source files in:                 ##
##                                                               ##
##    /var/www/html/                                             ##
##                                                               ##
##  The wordpress database is "wordpress" you can find the       ##
##  connection details of the MySQL user for this database in:   ##
##                                                               ##
##    /var/www/html/wp-config.php                                ##
##                                                               ##
##  Your wordpress admin user password can be found in the file  ##
##                                                               ##
##    /home/ubuntu/.wordpress.password                           ##
##                                                               ##
##  You can find the general MySQL passwords in                  ##
##                                                               ##
##    /home/ubuntu/.my.cnf                                       ##
##                                                               ##
###################################################################

EOF
