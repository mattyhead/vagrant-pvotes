#!/usr/bin/env bash
ssh citycom2@philadelphiavotes.com "cp pvotes.all.sql.gz public_html/"
curl -s http://www.philadelphiavotes.com/pvotes.all.sql.gz
gunzip < pvotes.all.sql.gz | sed 's/www\.philadelphiavotes\.com/192.168.33.22/g' | sed  's/philadelphiavotes\.com/192.168.33.22/g' | sed 's/\/home\/citycom2/\/var\/www/g' | mysql -u${DBUSER} -p${DBPASS} ${DBNAME}
ssh citycom2@philadelphiavotes.com "rm public_html/pvotes.all.sql.gz"
