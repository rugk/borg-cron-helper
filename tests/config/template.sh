#!/bin/sh
# shellcheck disable=SC2034
# (shebang duplicated so shellcheck can check script)

# CURRDIR is set by unit test
# FILENAME is set by unit test

# count execution
if [ -f "$CURRDIR/counter" ]; then
	count=$( cat "$CURRDIR/counter" )
	count=$(( count+1 ))
else
	count=1
fi

echo $count > "$CURRDIR/counter"
# log execution (order)
echo "$FILENAME" >> "$CURRDIR/list"

# set required variables, so borgcron.sh does not fail
BACKUP_NAME='unit-test-fake-backup'
export BORG_REPO='ssh://user@somewhere.example:22/./dir'
ARCHIVE_NAME="{hostname}-$BACKUP_NAME-{now:%Y-%m-%dT%H:%M:%S}"
BACKUP_DIRS="notExistentDir"

# speed up tests: use smaller sleep time
SLEEP_TIME=15s

# overwrite built-in variables, so dirs work
LAST_BACKUP_DIR="/tmp/LAST_BACKUP_DIR"
RUN_PID_DIR="/tmp/RUN_PID_DIR"
