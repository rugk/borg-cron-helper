#!/bin/sh
# Dumps each database separately. Execute this (as another user with more privileges)
# before the backup is executed.
# thanks https://stackoverflow.com/questions/9497869/export-and-import-all-mysql-databases-at-one-time#answer-26096339, modified

exitcode=0
track_exitcode() {
	if [ "$1" -gt "$exitcode" ]; then
		exitcode="$1"
	fi
}

# log system
log_line() {
	echo "[$( date +'%F %T' )]"
}
info_log() {
	echo "$( log_line ) $*" >&1
}
error_log() {
	echo "$( log_line ) $*" >&2
}


USER="backup"
PASSWORD="password"
DIR="/root/backup/db"
info_log "MySQL Backup $DESCRIPTION started."
if [ "$PASSWORD" ]; then
	PASSWORD="-p$PASSWORD"
fi
databases=$(mysql -u $USER $PASSWORD -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)


for db in $databases; do
	specialParams="--skip-lock-tables --single-transaction"

	# also dump special internal databases
	if [ "$db" = "information_schema" ] || [ "$db" = "performance_schema" ] || [ "$db" = "mysql" ] ; then
		specialParams="$specialParams --flush-privileges"
	fi

	echo "Dumping database: $db"
	# (variable intentionally not quoted as it is contains custom directives)
	# shellcheck disable=SC2086
	mysqldump -u $USER $PASSWORD $specialParams --databases "$db" > "$DIR/$db.sql"
done
