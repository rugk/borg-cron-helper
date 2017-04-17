#!/bin/sh
# Cron script to execute borg backup regularely using a local lock & retry system.
#
# LICENSE: CC0/Public Domain - To the extent possible under law, rugk has waived all copyright and related or neighboring rights to this work. This work is published from: Deutschland.
#

# constants
SLEEP_TIME="5m" # the time the script should wait until trying a backup again if it failed
REPEAT_NUMS="1 2 3" # = three times
LAST_BACKUP_DIR="/var/log/borg/last"
LOCAL_LOCK_DIR="$HOME/.config/borg"

is_lock() {
	[ -f "$LOCAL_LOCK_DIR/$BACKUP_NAME.lock" ]
}
do_lock() {
	touch "$LOCAL_LOCK_DIR/$BACKUP_NAME.lock"
}
rm_lock() {
	rm "$LOCAL_LOCK_DIR/$BACKUP_NAME.lock"
}

# check lock
if is_lock; then
	echo "[$( date +'%F %T' )] Backup $BACKUP_NAME is locked. Prevent start."
	exit 1
fi

# get passphrase
if [ -f "$PASSPHRASE_FILE" ]; then
	BORG_PASSPHRASE=$( cat "$PASSPHRASE_FILE" )
	export BORG_PASSPHRASE
else
	echo "No (valid) passphrase file given."
fi

# log
echo
echo "Backup $BACKUP_NAME started at $( date +'%F %T' )."

for i in $REPEAT_NUMS; do
	if is_lock; then
		echo "Backup $BACKUP_NAME is locked. Cancel."
		exit 1
	fi

	echo "$i. try…"

	# add local lock
	do_lock

	# backup dir (some variables intentionally not quoted)
	borg create -v --stats \
		--compression "$COMPRESSION" \
		$ADD_BACKUP_PARAMS \
		"$REPOSITORY::$ARCHIVE_NAME" \
		$BACKUP_DIRS

	# check return code
	errorcode="$?"

	# remove local lock
	rm_lock

	# show output
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
			borg break-lock "$REPOSITORY"

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
borg prune -v --list "$REPOSITORY" --prefix "{hostname}-$BACKUP_NAME-" $PRUNE_PARAMS

# log
echo "Backup $BACKUP_NAME ended at $( date +'%F %T' )."
