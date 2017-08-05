#!/bin/sh
# Backup routine to execute borg backups.
# Should be started with the wrapper script borgcron.sh.
#
# LICENSE: MIT license, see LICENSE.md
#

BORG_BIN="borg"
LAST_BACKUP_DIR="work"
RUN_PID_DIR="/var/run/borg"

# default settings for backup
# (can be overwritten by config files)
COMPRESSION="lz4"
ADD_BACKUP_PARAMS=""
SLEEP_TIME="5m"
REPEAT_NUM="3"

info_log() {
	echo "[$( date +'%F %T' )] $*" >&2
}
is_lock() {
	# when file is not present -> unlocked
	if [ ! -f "$RUN_PID_DIR/BORG_$BACKUP_NAME.pid" ]; then
		return 1 # false
	fi
	# when PID listed in file is not running -> unlocked
	if ! pgrep -F "$RUN_PID_DIR/BORG_$BACKUP_NAME.pid" > /dev/null; then
		return 1 # false
	fi

	return 0 # true, locked
}
do_lock() {
	if [ ! -d "$RUN_PID_DIR" ]; then
		mkdir -p "$RUN_PID_DIR" || exit 2
	fi

	# write PID into file
	echo $$ > "$RUN_PID_DIR/BORG_$BACKUP_NAME.pid" || exit 2

	if ! is_lock; then
		info_log "Locking was not successful. Cancel."
		exit 2
	fi
}
rm_lock() {
	rm "$RUN_PID_DIR/BORG_$BACKUP_NAME.pid"
}

# add trap to catch backup interruptions
trapterm() {
    rm_lock 2> /dev/null
    info_log "Backup $BACKUP_NAME (PID: $$) interrupted by $1."
    exit 2
}
trap 'trapterm INT' INT
trap 'trapterm TERM' TERM

# abort, if started without backup config file as input
if [ "$1" != '' ]; then
	# shellcheck source=config/example-backup.sh
	. "$1"
else
	echo "Please pass a path of a config file to $(basename "$0")."
	exit 1
fi

# check lock
if is_lock; then
	info_log "Backup $BACKUP_NAME is locked. Prevent start."
	exit 1
fi

# check that variables are set
if [ "$BACKUP_NAME" = "" ] ||
   [ "$REPOSITORY" = "" ] ||
   [ "$ARCHIVE_NAME" = "" ] ||
   [ "$BACKUP_DIRS" = "" ]; then
	echo 'Some required variables may not be set in the config file. Cancel backup.'
	exit 1
fi

# export borg repo variable
export BORG_REPO="$REPOSITORY"

# get passphrase
if [ -f "$PASSPHRASE_FILE" ]; then
	export BORG_PASSPHRASE
	BORG_PASSPHRASE=$( cat "$PASSPHRASE_FILE" )
else
	info_log "No (valid) passphrase file given."
fi

# log
echo
info_log "Backup $BACKUP_NAME started with $( borg -V ), PID: $$."

for i in $( seq "$REPEAT_NUM" ); do
	if is_lock; then
		info_log "Backup $BACKUP_NAME is locked. Cancel."
		exit 1
	fi

	if [ "$i" -gt 1 ]; then
		info_log "$i. try…"
	fi

	# add local lock
	do_lock

	# backup dir (some variables intentionally not quoted)
	# shellcheck disable=SC2086
	$BORG_BIN create -v --stats \
		--compression "$COMPRESSION" \
		$ADD_BACKUP_PARAMS \
		"::$ARCHIVE_NAME" \
		$BACKUP_DIRS

	# check return code
	errorcode="$?"

	# remove local lock
	rm_lock

	# show output
	# see https://borgbackup.readthedocs.io/en/stable/usage.html?highlight=return%20code#return-codes
	case ${errorcode} in
		2 )
			info_log "Borg exited with fatal error." #(2)

			# wait some time to recover from the error
			info_log "Wait $SLEEP_TIME…"
			sleep "$SLEEP_TIME"

			# break-lock if backup has not locked by another process in the meantime
			if is_lock; then
				info_log "Backup $BACKUP_NAME is locked locally by other process. Cancel."
				exit 1
			fi
			info_log "Breaking lock…"
			$BORG_BIN break-lock "$REPOSITORY"

			;;
		1 )
			info_log "Borg had some WARNINGS, but everything else was okay."
			;;
		0 )
			info_log "Borg has been successful."
			;;
		* )
			info_log "Unknown error with code ${errorcode} happened."
			;;
	esac

	# exit on non-critical errors (ignore 1 = warnings)
	if [ ${errorcode} -le 1 ]; then
		# save/update last backup time
		if [ -d $LAST_BACKUP_DIR ]; then
			date +'%s' > "$LAST_BACKUP_DIR/$BACKUP_NAME.time"
		fi
		# get out of loop
		break;
	fi
done

# The '{hostname}-$BACKUP_NAME-' prefix makes sure only backups from
# this machine with this backup-type are touched.
# (some variables intentionally not quoted)

if [ "$PRUNE_PARAMS" ]; then
	echo "Running prune for $BACKUP_NAME…"
	do_lock
	# shellcheck disable=SC2086
	$BORG_BIN prune -v --list --prefix "{hostname}-$BACKUP_NAME-" $PRUNE_PARAMS
	rm_lock
fi

# log
info_log "Backup \"$BACKUP_NAME\" ended."
