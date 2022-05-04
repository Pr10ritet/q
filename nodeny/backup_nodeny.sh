#!/bin/sh
PATH=/etc:/bin:/sbin:/usr/bin:/usr/sbin
passwd_root_mysql=`perl -e'require "/usr/local/nodeny/history.nod"; print $sql_root_pass;'`
mysql_cmd='/usr/local/bin/mysql'
mysqldump_cmd='/usr/local/bin/mysqldump'

fl=`date "+%d-%m-%Y"`
cd /var/backups/
echo show tables | ${mysql_cmd} -u root --password=${passwd_root_mysql} bill | \
  grep -v '^[stuvxyz]2' | grep -v 'traf_info' | grep -v '^Tables' | \
  xargs ${mysqldump_cmd} -R -Q --add-locks -u root --password=${passwd_root_mysql} \
  --default-character-set=cp1251 bill $1 > bill_${fl}.sql
tar -c -z -f ${fl}.tar.gz bill_${fl}.sql
rm -f bill_${fl}.sql
chmod 400 ${fl}.tar.gz
