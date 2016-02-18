#!/bin/bash

source /var/www/config
echo "dumping and pulling db"
date
ssh citycom2@philadelphiavotes.com "bin/dump-exclude-one.sh jos_rt_cold_data;tar czf - pvotes.no-jos_rt_cold_data.sql.gz" | tar xzfm - 
date 
echo "done \ncreating local DB and user"
# setup site db user
DBSETUP=$(cat <<EOF
CREATE USER '${DBUSER}'@'localhost' IDENTIFIED BY '${DBPASS}';
GRANT USAGE ON * . * TO '${DBUSER}'@'localhost' IDENTIFIED BY '${DBPASS}' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0 ;
CREATE DATABASE IF NOT EXISTS ${DBNAME};
GRANT ALL PRIVILEGES ON ${DBNAME}.* TO '${DBUSER}'@'localhost';
EOF
)
echo "${DBSETUP}" | mysql -uroot -p${PASSWORD}
echo "importing DB"
date
gunzip < pvotes.no-jos_rt_cold_data.sql.gz | sed 's/www\.philadelphiavotes\.com/192.168.33.22/g' | sed  's/philadelphiavotes\.com/192.168.33.22/g' | sed 's/\/home\/citycom2/\/var\/www/g' | mysql -u${DBUSER} -p${DBPASS} ${DBNAME}
date
echo "done"

echo "getting site (excluding public_html/files/*)"
ssh citycom2@philadelphiavotes.com "tar --exclude='public_html/files/*' czf - public_html" | "tar - xzf"
