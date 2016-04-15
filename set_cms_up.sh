#!/bin/bash

if [ -f /root/.configured] ; then
  exit 0;
fi
grep -q  /data01 /proc/mounts
if [ $? -eq 0 ] ; then
  if [ -d /data01/wordpress_server ] ; then
    exit 0
  fi
  mkdir -p /data01/wordpress_server 
  /etc/init.d/apache2 stop
  ( cd /var/; tar cf -  www) | ( cd /data01/wordpress_server ; tar xfp -)
  mv /var/www /var/www.old
  ln -s /data01/wordpress_server/www /var/www
  ( cd /var/log ; tar cf -  apache2 ) | ( cd /data01/wordpress_server ; tar xfp -)
  mv /var/log/apache2 /var/log/apache2.old
  ln -s /data01/wordpress_server/apache2 /var/log/apache2
  /etc/init.d/apache2 start
  sleep 5
fi

# The following need to be pulled from the cloud-forms...
# $CMS_SYSTEM  - Type of CMS none/drupal/wordpress
# $HOST        - Web hostname
# $MAIL_DOMAIN - Mail domain
# $EMAIL       - Email address of site administrator
# $TITLE       - Web site "title"

#export CMS_SYSTEM=wordpress HOST=scion-01.sandbox.sanger.ac.uk MAIL_DOMAIN=sanger.ac.uk EMAIL=js5@sanger.ac.uk TITLE='The Village Green Preservation Society'
#export CMS_SYSTEM=drupal    HOST=scion-02.sandbox.sanger.ac.uk MAIL_DOMAIN=sanger.ac.uk EMAIL=js5@sanger.ac.uk TITLE='The Village Green Preservation Society'

export    MYSQL_PASSWORD=`pwgen -1cns`
export   CMS_DB_PASSWORD=`pwgen -1cns`;
export CMS_USER_PASSWORD=`pwgen -1cns`;

##----------------------------------------------------------------------
## Post boot - Set apache server emails...
##----------------------------------------------------------------------

cat <<EOF > /etc/apache2/conf-available/server-settings.conf
ServerAdmin  $EMAIL
ServerTokens prod
ErrorLog     ${APACHE_LOG_DIR}/error.log
CustomLog    ${APACHE_LOG_DIR}/access.log combined

EOF

a2enconf server-settings

##----------------------------------------------------------------------
## Post boot - Configure the required CMS....
##----------------------------------------------------------------------

if [[ $CMS_SYSTEM = 'drupal' ]]
then
  ## Enable drupal website...
  a2ensite drupal
  a2dissite 000-default
  /etc/init.d/apache2 restart

  ## Create database and user
  mysql -e 'create database drupal_live CHARACTER SET utf8 COLLATE utf8_general_ci;'
  mysql -e 'grant select, insert, update, delete, create, drop, index, alter, create temporary tables on drupal_live.* to "drupal_admin"@"localhost" identified by "'$CMS_DB_PASSWORD'";'

  ## Build site based on parameters passed from interface
  cd /var/www/drupal
  drush site-install standard --yes --locale=en_GB --account-mail=$EMAIL --site-mail=$EMAIL --account-name=admin --account-pass=$CMS_USER_PASSWORD --site-name="$TITLE" --db-url=mysql://drupal_admin:$CMS_DB_PASSWORD@localhost/drupal_live 

  ## Set site URL....
  echo '$base_url = '"'"'http://'$HOST"'"';' >> /var/www/drupal/sites/default/settings.php
  echo $CMS_USER_PASSWORD > /home/ubuntu/.drupal.password
  
  cat << EOF > /etc/motd
###################################################################
##                                                               ##
##  Your drupal webserver is now set up.                         ##
##                                                               ##
###################################################################
##                                                               ##
##  You will find the drupal source files in:                    ##
##                                                               ##
##    /var/www/drupal/                                           ##
##                                                               ##
##  The drupal database is "drupal_live" you can find the        ##
##  connection details of the MySQL user for this database in:   ##
##                                                               ##
##    /var/www/drupal/sites/default/settings.php                 ##
##                                                               ##
##  The apache configuration files can be found in the standard  ##
##  ubuntu location:                                             ##
##                                                               ##
##    /etc/apache/                                               ##
##                                                               ##
##  The drupal site configuration is:                            ##
##                                                               ##
##    /etc/apache2/sites-available/drupal                        ##
##                                                               ##
##  Your drupal "admin" user password can be found in the file:  ##
##                                                               ##
##    /home/ubuntu/.drupal.password                              ##
##                                                               ##
##  You can find the MySQL root password in:                     ##
##                                                               ##
##    /home/ubuntu/.my.cnf                                       ##
##                                                               ##
###################################################################

EOF

elif [[ $CMS_SYSTEM = 'wordpress' ]]
then
  ## Enable wordpress website...
  a2ensite wordpress
  a2dissite 000-default
  /etc/init.d/apache2 restart

  ## Create database and user
  mysql -e 'create database wordpress CHARACTER SET utf8 COLLATE utf8_general_ci;'
  mysql -e 'grant select,update,delete,create temporary tables,insert,alter,drop,create view,show view,create,index,lock tables,trigger on wordpress.* to "wordpress_admin"@"localhost" identified by "'$CMS_DB_PASSWORD'";'

  ## Post boot - Write wordpress configuration file
  ##-------------------------------------------------------
  ## Now we write out the wp-config file and include in it the MySQL
  ## password set up above

  cat << EOF > /var/www/wordpress/wp-config.php
<?php
/* Below are the details for the database configuration */
define('DB_NAME',     'wordpress');
define('DB_USER',     'wordpress_admin');
define('DB_PASSWORD', '$CMS_DB_PASSWORD');
define('DB_HOST',     'localhost');
define('DB_CHARSET',  'utf8');
define('DB_COLLATE',  '');

/* Table prefix (to allow multiple wp sites in one db */

\$table_prefix  = 'wp_';

/* Now for random encryption strings */

EOF

  curl https://api.wordpress.org/secret-key/1.1/salt/ >> /var/www/wordpress/wp-config.php

  cat << EOF >> /var/www/wordpress/wp-config.php
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
       --data-urlencode "admin_password=$CMS_USER_PASSWORD" \
       --data-urlencode "pass1-text=$CMS_USER_PASSWORD" \
       --data-urlencode "admin_password2=$CMS_USER_PASSWORD" \
       --data-urlencode "admin_email=$EMAIL" \
       --data-urlencode 'blog_public=0' \
       --data-urlencode 'language=en_GB' \
       'http://127.0.0.1/wp-admin/install.php?step=2'
  echo $CMS_USER_PASSWORD > /home/ubuntu/.wordpress.password
  
  cat << EOF > /etc/motd
###################################################################
##                                                               ##
##  Your wordpress webserver is now set up.                      ##
##                                                               ##
###################################################################
##                                                               ##
##  You will find the wordpress source files in:                 ##
##                                                               ##
##    /var/www/wordpress/                                        ##
##                                                               ##
##  The wordpress database is "wordpress_live" you can find the  ##
##  connection details of the MySQL user for this database in:   ##
##                                                               ##
##    /var/www/wordpress/wp-config.php                           ##
##                                                               ##
##  The apache configuration files can be found in the standard  ##
##  ubuntu location:                                             ##
##                                                               ##
##    /etc/apache/                                               ##
##                                                               ##
##  The wordpress site configuration is:                         ##
##                                                               ##
##    /etc/apache2/sites-available/wordpress                     ##
##                                                               ##
##  Your wordpress "admin" user password can be found in the     ##
##  file:                                                        ##
##                                                               ##
##    /home/ubuntu/.wordpress.password                           ##
##                                                               ##
##  You can find the MySQL root password in:                     ##
##                                                               ##
##    /home/ubuntu/.my.cnf                                       ##
##                                                               ##
###################################################################

EOF

else
 cat << EOF > /etc/motd
###################################################################
##                                                               ##
##  Your apache webserver is now set up.                         ##
##                                                               ##
###################################################################
##                                                               ##
##  You will find the HTML files in:                             ##
##                                                               ##
##    /var/www/html/                                             ##
##                                                               ##
##  The apache configuration files can be found in the standard  ##
##  ubuntu location:                                             ##
##                                                               ##
##    /etc/apache/                                               ##
##                                                               ##
##  You can find the MySQL root password in:                     ##
##                                                               ##
##    /home/ubuntu/.my.cnf                                       ##
##                                                               ##
###################################################################

EOF

fi

##----------------------------------------------------------------------
## Post boot - Set email address for unattended upgrade emails
##----------------------------------------------------------------------

cat <<EOF >> /etc/apt/apt.conf.d/51my-unattended-upgrades

Unattended-Upgrade::Mail "$EMAIL";

EOF

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


