#!/bin/sh
# Cron script to execute borg backup regularely using a local lock & retry system.
#
# LICENSE: CC0/Public Domain - To the extent possible under law, rugk has waived all copyright and related or neighboring rights to this work. This work is published from: Deutschland.
#

# include settings file
. ./borgcron_settings.sh

# optional settings
SLEEP_TIME="5m" # time, the script should wait until re-attempting the backup after a failed one
REPEAT_NUMS="1 2 3" # = three times
BORG_BIN="borg" # the binary
LAST_BACKUP_DIR="/var/log/borg/last" # the dir, where stats about latest execution are saved
RUN_PID_DIR="/var/run/borg" # dir for "locking" backups

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
		mkdir -p "$RUN_PID_DIR" | exit 2
	fi

	# write PID into file
	echo $$ > "$RUN_PID_DIR/BORG_$BACKUP_NAME.pid" | exit 2
}
rm_lock() {
	rm "$RUN_PID_DIR/BORG_$BACKUP_NAME.pid"
}
trapterm() {
    rm_lock
    echo "[$( date +'%F %T' )] Backup (PID: $$) interrupted." >&2
    exit 2
}

# add trap to catch terminating signals
trap trapterm INT TERM

# check lock
if is_lock; then
	echo "[$( date +'%F %T' )] Backup $BACKUP_NAME is locked. Prevent start."
	exit 1
fi

# export borg repo variable
export BORG_REPO="$REPOSITORY"

# get passphrase
export BORG_PASSPHRASE=$( cat "$PASSPHRASE_FILE" )

# log
echo
echo "Backup $BACKUP_NAME started at $( date +'%F %T' ) with $( borg -V ), PID: $$."

for i in $REPEAT_NUMS; do
	if is_lock; then
		echo "Backup $BACKUP_NAME is locked. Cancel."
		exit 1
	fi

	echo "$i. try…"

	# add local lock
	do_lock

	# backup dir (some variables intentionally not quoted)
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
			echo "Borg exited with fatal error." #(2)

			# wait some time to recover from the error
			echo "Wait $SLEEP_TIME…"
			sleep "$SLEEP_TIME"

			# break-lock if backup has not locked by another process in the meantime
			if is_lock; then
				echo "Backup $BACKUP_NAME is locked locally by other process. Cancel."
				exit 1
			fi
			echo "Breaking lock…"
			$BORG_BIN break-lock "$REPOSITORY"

			;;
		1 )
			echo "Borg had some WARNINGS, but everything else was okay."
			;;
		0 )
			echo "Borg has been successful."
			;;
		* )
			echo "Unknown error with code ${errorcode} happened."
			;;
	esac

	# exit on non-critical errors (ignore 1 = warnings)
	if [ ${errorcode} -le 1 ]; then
		# save/update last backup time
		date +'%s' > "$LAST_BACKUP_DIR/$BACKUP_NAME.time"
		# get out of loop
		break;
	fi
done

# The '{hostname}-$BACKUP_NAME-' prefix makes sure only backups from
# this machine with this backup-type are touched.
# (some variables intentionally not quoted)
echo "Running prune for $BACKUP_NAME…"
do_lock
$BORG_BIN prune -v --list --prefix "{hostname}-$BACKUP_NAME-" $PRUNE_PARAMS
rm_lock

# log
echo "Backup $BACKUP_NAME ended at $( date +'%F %T' )."
