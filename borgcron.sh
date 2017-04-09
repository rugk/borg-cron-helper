#!/bin/sh
# Cron script to execute borg backup regularely.
#
# LICENSE: CC0/Public Domain - To the extent possible under law, rugk has waived all copyright and related or neighboring rights to this work. This work is published from: Deutschland.
#

# constants
SLEEP_TIME="5m" # the time the script should wait until trying a backup again if it failed
REPEAT_NUMS="1 2 3" # = three times

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
	# backup dir
	borg create -v --stats \
		--compression "$COMPRESSION" \
		"$REPOSITORY::$ARCHIVE_NAME" \
		$ADD_BACKUP_PARAMS \
		$BACKUP_DIRS

	# check return code
	errorcode="$?"
	if [ ${errorcode} = 0 ]; then
		echo "Borg exited with error ${errorcode}."
		sleep "$SLEEP_TIME"
	else
		echo "Borg has been successful."
		# get out of loop
		break;
	fi
done

# The '{hostname}-$BACKUP_NAME-' prefix makes sure only backups from
# this machine with this backup-type are touched.
echo "Running prune for $BACKUP_NAME…"
borg prune -v --list "$REPOSITORY" --prefix "{hostname}-$BACKUP_NAME-" $PRUNE_PARAMS
