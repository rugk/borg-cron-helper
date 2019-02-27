#!/bin/sh
# Dumps each database separately into a single file. Execute this (as another user with more privileges)
# before the backup is executed.
# thanks https://stackoverflow.com/questions/9497869/export-and-import-all-mysql-databses-at-one-time#answer-26096339, modified

# You can hardcode variables here.
USER="backup"
PASSWORD="password"
DESTINATION="/root/backup/db"
DATABASES=""

# _______________________________

track_exitcode() {
	if [ "$1" -gt "$exitcode" ]; then
		exitcode="$1"
	fi
}
exitcode=0
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

case "$1" in
	--help|-h|-? ) # show help message
	  echo "Usage:"
	  echo "$( basename "$0" ) [<db_name(s) …>] [<destination>] [<user>] [<passphrase>]"
	  echo
		echo "db_name(s)	– databases to backup, separated with spaces"
		echo "destination	– directory to save MySQL dumps with a per-database name"
		echo "user		– MySQL username to use for dumping databases"
		echo "passphrase	– MySQL users passphrase/password to use for dumping databases"
		echo
		echo "You can also pass the following envoriment variables to set the values:"
		echo "SQL_BACKUP_DATABASES	– database names"
		echo "SQL_BACKUP_DESTINATION	– database destination"
		echo "SQL_BACKUP_USER		– MySQL username"
		echo "SQL_BACKUP_PASSPHRASE	– MySQL password"
		echo
		echo "You can also use the special envoriment variable SQL_BACKUP_PASSCOMMAND"
		echo "as a more secure alternative to passing the password via envoriment"
		echo "variables or command-line parameters. The script $( basename "$0" ) does"
		echo "execute the specified command and takes the return value as the password."
		echo
		echo "Example:"
		echo "export SQL_BACKUP_PASSCOMMAND='cat \"/root/.mysqlPassword\"'"
		echo
		echo "Command-line parameters take precedence over the envoriment variables."
		echo "Envoriment variables take precedence over the hardcoded variables."
		exit
		;;
esac

# parse environment parameters, they may overwrite hardcoded variables
[ -n "$SQL_BACKUP_DATABASES" ] && DATABASES="$SQL_BACKUP_DATABASES"
[ -n "$SQL_BACKUP_DESTINATION" ] && DESTINATION="$SQL_BACKUP_DESTINATION"
[ -n "$SQL_BACKUP_USER" ] && USER="$SQL_BACKUP_USER"
[ -n "$SQL_BACKUP_PASSPHRASE" ] && PASSWORD="$SQL_BACKUP_PASSPHRASE"
[ -n "$SQL_BACKUP_PASSCOMMAND" ] && PASSWORD="$( $SQL_BACKUP_PASSCOMMAND )"

# parse cli parameters, they may overwrite environment parameters
[ -n "$1" ] && DATABASES="$1"
[ -n "$2" ] && DESTINATION="$2"
[ -n "$3" ] && USER="$3"
[ -n "$4" ] && PASSWORD="$4"

info_log "MySQL Backup for MySQL user \"$USER\" started."

if [ -n "$PASSWORD" ]; then
	PASSWORD="-p$PASSWORD"
fi

# use all databases if not specified
if [ -z "$DATABASES" ]; then
	DATABASES=$(mysql -u "$USER" "$PASSWORD" -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)
	track_exitcode $?
fi

for db in $DATABASES; do
	specialParams="--skip-lock-tables --single-transaction"

	# also dump special internal DATABASES
	if [ "$db" = "information_schema" ] || [ "$db" = "performance_schema" ] || [ "$db" = "mysql" ] ; then
		specialParams="$specialParams --flush-privileges"
	fi

	info_log "MySQL Backup dumping database: \"$db\""
	# (specialParams intentionally not quoted as it is contains custom directives)
	# shellcheck disable=SC2086
	mysqldump -u "$USER" "$PASSWORD" $specialParams --databases "$db" > "$DESTINATION/$db.sql"
	exitcodeDump=$?
	track_exitcode $exitcodeDump

	if [ $exitcodeDump -eq 0 ]; then
		info_log "MySQL Backup succesful for \"$db\"."
	else
		error_log "MySQL Backup not succesful for \"$db\"."
	fi
done

# log
if [ "$exitcode" -ne 0 ]; then
	error_log "MySQL Backup for user \"$USER\" was not successful."
else
	info_log "MySQL Backup for user \"$USER\" ended successfully."
fi

exit "$exitcode"
