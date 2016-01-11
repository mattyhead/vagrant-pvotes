#!/usr/bin/env bash
ssh citycom2@philadelphiavotes.com "cp pvotes.all.sql.gz public_html/files/"
wget http://www.philadelphiavotes.com/files/pvotes.all.sql.gz
gunzip < pvotes.all.sql.gz | sed 's/www\.philadelphiavotes\.com/192.168.33.22/g' | sed  's/philadelphiavotes\.com/192.168.33.22/g' | sed 's/\/home\/citycom2/\/var\/www/g' | mysql -u${DBUSER} -p${DBPASS} ${DBNAME}
ssh citycom2@philadelphiavotes.com "rm public_html/files/pvotes.all.sql.gz"

