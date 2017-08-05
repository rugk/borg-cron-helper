#!/bin/sh
# Checks whether the backup is up-to-date. It is considered out-of-date when
# no backup has been created during the "critical time" shown below.
#
# LICENSE: CC0/Public Domain - To the extent possible under law, rugk has waived all copyright and related or neighboring rights to this work. This work is published from: Deutschland.

LAST_BACKUP_DIR="/var/log/borg/last"
CRITICAL_TIME=$(( 25*60*60 )) # 25h

dir_contains_files() {
	ls -A "$1"
}

wait=0
# check for borg backup notes
if [ -d "$LAST_BACKUP_DIR" ] && [ "$( dir_contains_files $LAST_BACKUP_DIR )" ]; then
	for file in $LAST_BACKUP_DIR/*; do
		name=$( basename "$file" .time )
		time=$( cat "$file" )
		relvtime=$(( $(date +%s) - time ))

		if [ "$relvtime" -ge "$CRITICAL_TIME" ]; then
			echo "WARNING: The borg backup named \"$name\" is outdated."
			echo "         Last successful execution: $( date --date=@"$time" +'%A, %F %T' )"
			wait=1
		fi
	done
else
	echo "ERROR: No borg backup 'last' dir…"
	wait=1
fi

if [ "$wait" = "1" ]; then
	echo "Press enter to continue…"
	read key
fi
