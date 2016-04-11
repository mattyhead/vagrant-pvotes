#!/bin/bash

# update / upgrade
sudo apt-get update
sudo apt-get -y upgrade
echo "Let's make sure we have a few utilities"
sudo apt-get install -y curl virtualbox-guest-utils git

# install apache2 and php5
echo "Installing nginx and PHP"
sudo apt-get install -y nginx php5 php5-fpm php5-curl php5-mcrypt php5-gmp php5-fpm php5-cli
# sudo sed -i "s/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini

# install mysql and give password to installer
echo "Install MySQL"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $PASSWORD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $PASSWORD"
sudo apt-get -y install mysql-server php5-mysql

echo "Create DB user and database"
# setup site db user
DBSETUP=$(cat <<EOF
CREATE USER '${USERNAME}'@'localhost' IDENTIFIED BY '${PASSWORD}';
GRANT USAGE ON * . * TO '${USERNAME}'@'localhost' IDENTIFIED BY '${DBPASS}' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0 ;
CREATE DATABASE IF NOT EXISTS ${USERNAME};
GRANT ALL PRIVILEGES ON ${USERNAME}.* TO '${PASSWORD}'@'localhost';
EOF
)
echo "${DBSETUP}" | mysql -uroot -p${PASSWORD}  

# install phpmyadmin and give password(s) to installer
# for simplicity I'm using the same password for mysql and phpmyadmin
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
sudo apt-get -y --no-install-recommends install phpmyadmin

# lets eat the default vhosts and pools
sudo rm -Rf /etc/nginx/sites-available/* /etc/nginx/sites-enabled/* /etc/php5/fpm/pool.d/*

HOME_DIR=$USERNAME
#echo "create database $USERNAME;grant ALL on $USERNAME.* to $USERNAME@localhost;set password for $USERNAME@localhost=password('$PASSWORD');" | mysql -u root -p

# Now we need to copy the virtual host template
CONFIG=$NGINX_CONFIG/$DOMAIN.http.conf
cp $SHARE_DIR/nginx.vhost.conf.template $CONFIG
$SED -i "s/@@HOSTNAME@@/$DOMAIN/g" $CONFIG
$SED -i "s#@@PATH@@#\/home\/"$USERNAME$PUBLIC_HTML_DIR"#g" $CONFIG
$SED -i "s/@@LOG_PATH@@/\/home\/$USERNAME\/_logs/g" $CONFIG
$SED -i "s#@@SOCKET@@#/var/run/"$USERNAME"_fpm.sock#g" $CONFIG

cp $SHARE_DIR/pool.conf.template $FPMCONF
$SED -i "s/@@USER@@/$USERNAME/g" $FPMCONF
$SED -i "s/@@HOME_DIR@@/\/home\/$USERNAME/g" $FPMCONF
$SED -i "s/@@START_SERVERS@@/$FPM_SERVERS/g" $FPMCONF
$SED -i "s/@@MIN_SERVERS@@/$MIN_SERVERS/g" $FPMCONF
$SED -i "s/@@MAX_SERVERS@@/$MAX_SERVERS/g" $FPMCONF
MAX_CHILDS=$((MAX_SERVERS+START_SERVERS))
$SED -i "s/@@MAX_CHILDS@@/$MAX_CHILDS/g" $FPMCONF

usermod -aG $USERNAME $WEB_SERVER_GROUP
chmod g+rx /home/$HOME_DIR
chmod 600 $CONFIG

ln -s $CONFIG $NGINX_SITES_ENABLED/$DOMAIN.conf

# set file perms and create required dirs!
mkdir -p /home/$HOME_DIR$PUBLIC_HTML_DIR
mkdir /home/$HOME_DIR/_logs
mkdir /home/$HOME_DIR/_sessions
chmod 750 /home/$HOME_DIR -R
chmod 700 /home/$HOME_DIR/_sessions
chmod 770 /home/$HOME_DIR/_logs
chmod 750 /home/$HOME_DIR$PUBLIC_HTML_DIR
chown $USERNAME:$USERNAME /home/$HOME_DIR/ -R

$NGINX_INIT reload
$PHP_FPM_INIT restart

ln -s /usr/share/phpmyadmin /home/$HOME_DIR/$PROJECTFOLDER/pma

# set USE_LE in config
apt-cache show letsencrypt
if [ $? ] && [ $USE_LE -gt 0 ]
then
  sudo git clone https://github.com/letsencrypt/letsencrypt /opt/letsencrypt
  sudo ln -s /opt/letsencrypt/letsencrypt-auto /usr/local/bin/letsencrypt
  letsencrypt
  if [ $? ]
  then
    echo "looks like letsencrypt is now installed.  verify additionally, eh"
  fi
else
  sudo apt-get -y install letsencrypt
fi

# install Composer
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

# eventually, we'll want to shard the above, test for success and run the following automatically
echo "If successful, run populate.sh"