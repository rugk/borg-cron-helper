#!/bin/sh
# Cron script to execute borg backup regularely using a local lock & retry system.
#
# LICENSE: MIT license, see LICENSE.md
#

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
trapterm() {
    rm_lock 2> /dev/null
    info_log "Backup (PID: $$) interrupted by $1." >&2
    exit 2
}

# add trap to catch terminating signals
trap 'trapterm INT' INT
trap 'trapterm TERM' TERM


# default settings
COMPRESSION="lz4"
CONFIG_DIR='config'
LAST_BACKUP_DIR="work"
RUN_PID_DIR="work"
ARCHIVE_NAME="{hostname}-$BACKUP_NAME-{now:%Y-%m-%dT%H:%M:%S}"
ADD_BACKUP_PARAMS=""
SLEEP_TIME="5m"
REPEAT_NUMS="1 2 3"
BORG_BIN="borg"


# select action from user input

# help dialog
if [ "$1" = "--help" ] || [ $# = 0 ]; then
	echo "Usage: "$(basename "$0")" (--single <file>... | --all)\n\n  --all		Execute every backup, found in config-folder\n  --single <file>...	Execute given backup by filename within the configured config folder"
	exit
fi

# config file passed
if [ "$1" = "--single" ]; then
	# jump to filename, shift $2 to $1
	shift 1
	while [ "$1" != '' ]; do
		CONFIGFILE=$1
		if [ -f "$CONFIG_DIR/$CONFIGFILE" ]; then
			. "$CONFIG_DIR/$CONFIGFILE"
			. core/backup_routine.sh
		else
		info_log "Your backup-settings file(s) "$CONFIGFILE" has not been found. There has not been created a backup!"
		fi
	shift 1
	done
fi


# process all backup files in CONFIG_DIR
if [ "$1" = "--all" ]; then
	for CONFIGFILE in $CONFIG_DIR/*;
	do
		if [ -f "$CONFIGFILE" ]; then
			. $CONFIGFILE
			. core/backup_routine.sh
		else
			info_log "No backup-settings file(s) found in your configured folder \"$CONFIG_DIR\". There has not been created a backup!\n"
		fi
	done
fi
echo lol