#!/bin/sh
# Cron script to execute borg backup regularely using a local lock & retry system.
#
# LICENSE: MIT license, see LICENSE.md
#

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
	echo "Usage: "$(basename "$0")" <backup file>"
	exit
fi

for i in "$@" do
	borgcron_worker.sh "$CONFIG_DIR/$i"
done
