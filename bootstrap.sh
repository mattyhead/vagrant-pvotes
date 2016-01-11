#!/usr/bin/env bash
DBNAME=''
DBUSER=''
DBPASS=''

# setup hosts file
DBSETUP=$(cat <<EOF
CREATE USER '${DBUSER}'@'localhost' IDENTIFIED BY '${DBPASS}';
GRANT USAGE ON * . * TO '${DBUSER}'@'localhost' IDENTIFIED BY '${DBPASS}' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0 ;
CREATE DATABASE IF NOT EXISTS ${DBNAME};
GRANT ALL PRIVILEGES ON ${DBNAME}.* TO '${DBUSER}'@'localhost';
EOF
)

# Use single quotes instead of double quotes to make it work with special-character passwords
PASSWORD='12345678'
PROJECTFOLDER='public_html'

# create project folder
sudo mkdir "/var/www/${PROJECTFOLDER}/"
sudo mkdir "/var/www/logs"
sudo mkdir "/var/www/tmp"

# update / upgrade
sudo apt-get update
sudo apt-get -y dist-upgrade
sudo apt-get install -y curl git virtualbox-guest-utils

# install apache2 and php5
sudo apt-get install -y apache2 php5 php5-curl

# a few things required by
sudo a2enmod rewrite

# install mysql and give password to installer
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $PASSWORD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $PASSWORD"
sudo apt-get -y install mysql-server php5-mysql

# install phpmyadmin and give password(s) to installer
# for simplicity I'm using the same password for mysql and phpmyadmin
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
sudo apt-get -y install phpmyadmin

echo "${DBSETUP}" | mysql -uroot -p${PASSWORD}

# setup hosts file
VHOST=$(cat <<EOF
<VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/${PROJECTFOLDER}
        <Directory />
                Options FollowSymLinks
                AllowOverride all
        </Directory>
        <Directory /var/www/${PROJECTFOLDER}/>
                Options Indexes FollowSymLinks MultiViews
                AllowOverride All
                Order allow,deny
                allow from all
        </Directory>
        ErrorLog /var/www/logs/error.log
        # Possible values include: debug, info, notice, warn, error, crit,
        # alert, emerg.
        LogLevel warn
        CustomLog /var/www/logs/access.log combined
</VirtualHost>
EOF
)
echo "${VHOST}" > /etc/apache2/sites-available/000-default.conf
# lets eat the default vhosts
sudo rm -Rf /etc/apache2/sites-enabled/*
# and link the new one
ln -s /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-enabled/000-default

# restart apache
sudo service apache2 restart

# install git
sudo apt-get -y install git

# install Composer
curl -s https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

curl -s http://www.philadelphiavotes.com/pvotes.all.sql.gz
gunzip < pvotes.all.sql.gz | sed 's/www\.philadelphiavotes\.com/192.168.33.22/g' | sed  's/philadelphiavotes\.com/192.168.33.22/g' | sed 's/\/home\/citycom2/\/var\/www/g' | mysql -u${DBUSER} -p${DBPASS} ${DBNAME}
