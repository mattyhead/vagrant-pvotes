#!/bin/bash

source /var/www/config

sudo rm -Rf "/var/www/${PROJECTFOLDER}/" "/var/www/logs" "/var/www/tmp"

# create project folder
sudo mkdir "/var/www/${PROJECTFOLDER}/"
sudo mkdir "/var/www/logs"
sudo mkdir "/var/www/tmp"
sudo echo "<php phpinfo();" > /var/www/${PROJECTFOLDER}/index.php

# update / upgrade
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get install -y curl virtualbox-guest-utils

# install apache2 and php5
sudo apt-get install -y nginx php5 php5-fpm php5-curl php5-mcrypt php5-gmp php5-fpm php5-cli git
sudo sed -i "s/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini

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
sudo apt-get -y --no-install-recommends install phpmyadmin

# setup hosts file
VHOST=$(cat <<EOF
server {
  listen 80;

  root /var/www/${PROJECTFOLDER};

  access_log /var/www/logs/error.log;
  error_log /var/www/logs//error.log;
  index index.php index.html index.htm default.html default.htm;

  location / {
    try_files $uri $uri/ /index.php?$args;
  }

  location ~* /(images|cache|media|logs|tmp)/.*\.(php|pl|py|jsp|asp|sh|cgi)$ {
    return 403;
    error_page 403 /403_error.html;
  }

  location ~ "^(.+\.php)($|/)" {
    fastcgi_split_path_info ^(.+\.php)(.*)$;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_param SCRIPT_NAME $fastcgi_script_name;
    fastcgi_param PATH_INFO $fastcgi_path_info;
    fastcgi_param SERVER_NAME $host;
    if ($uri !~ "^/uploads/") {
      fastcgi_pass   unix:@@SOCKET@@;
    }
    include        fastcgi_params;
  }

  location ~* \.(ico|pdf|flv)$ {
    expires 1y;
  }

  location ~* /(images|cache|media|logs|tmp)/.*\.(php|pl|py|jsp|asp|sh|cgi)$ {
    return 403;
    error_page 403 /403_error.html;
  }

  location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
    expires max;
    log_not_found off;
    access_log off;
  }

  location ~* \.(html|htm)$ {
    expires 30m;
  }

  location ~* /\.(ht|git|svn) {
    deny  all;
  }
}
EOF
)
echo "${VHOST}" > /etc/nginx/sites-available/000-default.conf
# lets eat the default vhosts
sudo rm -Rf /etc/nginx/sites-enabled/*
# and link the new one
ln -s /etc/nginx/sites-available/000-default.conf /etc/nginx/sites-enabled/000-default

ln -s /usr/share/phpmyadmin /var/www/$PROJECTFOLDER/pma

# restart apache
sudo service nginx restart
sudo service php5-fpm restart

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