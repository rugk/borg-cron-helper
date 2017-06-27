#!/bin/sh
# Dumps each database separately. Execute this (as another user with more privileges)
# before the backup is executed.
# thanks https://stackoverflow.com/questions/9497869/export-and-import-all-mysql-databases-at-one-time#answer-26096339, modified

USER="backup"
PASSWORD="password"
DIR="/root/backup/db"

if [ "$PASSWORD" ]; then
	PASSWORD="-p$PASSWORD"
fi
databases=$(mysql -u $USER $PASSWORD -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)


for db in $databases; do
	specialParams="--skip-lock-tables --single-transaction"

	# also dump special internal databases
	if [ "$db" != "information_schema" ] && [ "$db" != "performance_schema" ] && [ "$db" != "mysql" ] ; then
		specialParams="--lock-tables --flush-privileges"
	fi

	echo "Dumping database: $db"
	mysqldump -u $USER $PASSWORD $specialParams --databases "$db" > "$DIR/$db.sql"
done
