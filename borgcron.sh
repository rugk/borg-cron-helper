#!/bin/sh
# Cron script to execute borg backup regularely.
#
# LICENSE: CC0/Public Domain - To the extent possible under law, rugk has waived all copyright and related or neighboring rights to this work. This work is published from: Deutschland.
#

# constants
SLEEP_TIME="5m" # the time the script should wait until trying a backup again if it failed
REPEAT_NUMS="1 2 3" # = three times
LAST_BACKUP_DIR="/var/log/borg/last"

# get passphrase
if [ -f "$PASSPHRASE_FILE" ]; then
	BORG_PASSPHRASE=$( cat "$PASSPHRASE_FILE" )
	export BORG_PASSPHRASE
else
	echo "No (valid) passphrase file given."
fi

# log
echo "Backup $BACKUP_NAME started at $( date +'%F %T' )."

for i in $REPEAT_NUMS; do
	echo "$i. try…"
	# backup dir (some variables intentionally not quoted)
	borg create -v --stats \
		--compression "$COMPRESSION" \
		$ADD_BACKUP_PARAMS \
		"$REPOSITORY::$ARCHIVE_NAME" \
		$BACKUP_DIRS

	# check return code
	errorcode="$?"
	if [ ${errorcode} = 0 ]; then
		echo "Borg has been successful."
		# save/update last backup time
		date +'%s' > "$LAST_BACKUP_DIR/$BACKUP_NAME.time"
		# get out of loop
		break;
	else
		echo "Borg exited with error ${errorcode}."
		sleep "$SLEEP_TIME"
	fi
done

# The '{hostname}-$BACKUP_NAME-' prefix makes sure only backups from
# this machine with this backup-type are touched.
# (some variables intentionally not quoted)
echo "Running prune for $BACKUP_NAME…"
borg prune -v --list "$REPOSITORY" --prefix "{hostname}-$BACKUP_NAME-" $PRUNE_PARAMS

# log
echo "Backup $BACKUP_NAME ended at $( date +'%F %T' )."
