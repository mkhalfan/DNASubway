#!/bin/sh

# 1. stop webserver
#/etc/init.d/httpd stop

# 2. nicely stop all the workers

# 3. see if we can stop gearmanworker
#/etc/init.d/gearmanworker stop

# 4. restart postgresql, to close any opened clients
#/etc/init.d/postgresql restart

# 5. do clean up
# 5.1 remove guest accounts
/var/www/bin/remove-guest-accounts.pl

# 5.2. vacuum each db
	# psql -h green.cshl.edu -p 5432 -U $USER -c "VACUUM FULL ANALYSE;" $DB
for db in `psql -h green.cshl.edu -p 5432 -U cornel -A -t -l|grep -E -v "guest|chado|templ|rice"|cut -d"|" -f1`; 
do 
	echo $db;
	#psql -h green.cshl.edu -p 5432 -U cornel -c "VACUUM ANALYSE;" $db;
	vacuumdb -f -z -h green.cshl.edu -p 5432 -U cornel $db
	reindexdb -q -e -h green.cshl.edu -p 5432 -U cornel $db 2>/dev/null
done



