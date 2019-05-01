#!/bin/sh
# Backup routine to execute borg backups.
# Should be started with the wrapper script borgcron.sh.
#
# LICENSE: MIT license, see LICENSE.md
#

# enable zsh compatibility: in ZSH word splitting is disabled by default,
# but we need it
setopt shwordsplit 2>/dev/null

BORG_BIN="borg"
LAST_BACKUP_DIR="/var/log/borg/last"
RUN_PID_DIR="/var/run/borg"

# default settings for backup
# (can be overwritten by config files)
COMPRESSION="lz4"
ADD_BACKUP_PARAMS=""
SLEEP_TIME="5m"
RETRY_NUM="3"

BATTERY_PATH="/sys/class/power_supply/BAT1"

# set placeholder/default value
PRUNE_PREFIX="null"
exitcode=0
exitcode_create=0

# Keep track oh highest exit code.
#
# args:
# $1 – number of new exit code
track_exitcode() {
	if [ "$1" -gt "$exitcode" ]; then
		exitcode="$1"
	fi
}

# Evaluate exit code of a borg run.
#
# args: none
# may exit
evaluateExitCodes() {
	# see https://borgbackup.readthedocs.io/en/stable/usage.html?highlight=return%20code#return-codes
	case $1 in
		2 )
			error_log "Borg exited with fatal error." #(2)

			# ignore last try
			if [ "$i" -lt "$RETRY_NUM" ]; then
				# wait some time to recover from the error
				info_log "Wait $SLEEP_TIME…"
				sleep "$SLEEP_TIME"

				# break-lock if backup has not locked by another process in the meantime
				if is_lock; then
					error_log "Backup \"$BACKUP_NAME\" is locked locally by other process. Cancel."
					exit 1
				fi

				if [ "$RUN_PID_DIR" != "" ]; then
					info_log "Breaking lock…"
					$BORG_BIN break-lock "$REPOSITORY"
				fi
			fi
			;;
		1 )
			error_log "Borg had some WARNINGS, but everything else was okay."
			;;
		0 )
			info_log "Borg has been successful."
			;;
		* )
			error_log "Unknown error with code $1 happened."
			;;
	esac
}

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

# Evaluate whether the backup is locked.
#
# args: none
# returns: bool
is_lock() {
	# check if locking system is disabled
	if [ "$RUN_PID_DIR" = "" ]; then
		return 1 # not locked
	fi

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

# Locks the current backup.
#
# args: none
do_lock() {
	# check if locking system is disabled
	if [ "$RUN_PID_DIR" = "" ]; then
		return
	fi

	if [ ! -d "$RUN_PID_DIR" ]; then
		mkdir -p "$RUN_PID_DIR" || exit 2
	fi

	# write PID into file
	echo $$ > "$RUN_PID_DIR/BORG_$BACKUP_NAME.pid" || exit 2

	if ! is_lock; then
		error_log "Locking was not successful. Cancel."
		exit 2
	fi
}

# Removes the lock of the current backup.
#
# args: none
rm_lock() {
	# check if locking system is disabled
	if [ "$RUN_PID_DIR" = "" ]; then
		return
	fi

	rm "$RUN_PID_DIR/BORG_$BACKUP_NAME.pid"
}

# Checks in a loop whether we need to stop the loop or not and log messages.
#
# args:
# $1 – The number of the executed try.
# may exit
backupIterationLockCheck() {
	# if locked, stop backup
	if is_lock; then
		error_log "Backup $BACKUP_NAME is locked. Cancel."
		exit 1
	fi

	# otherwise log try (if useful)
	if [ "$1" -gt 1 ]; then
		info_log "$1. try…"
	fi
}

# returns whether we are in a (low-)battery situation and need to stop the backup.
#
# args: none
# returns: bool
isRunningOnBattery() {
	# test whether battery is there
	[ ! -e "$BATTERY_PATH/type" ] && return 1 # false
	[ "$( cat "$BATTERY_PATH/type" )" != "Battery" ] && return 1 # false

	# stop when running on battery
	# [ "$( cat "$BATTERY_PATH/status" )" = "Discharging" ] && return 0 # true
	# stop when running low on battery
	[ "$( cat "$BATTERY_PATH/status" )" = "Discharging" ] && [ "$( cat "$BATTERY_PATH/capacity" )" -lt 20 ] && return 0 # true
}

# Prettifies the time display so it looks good for user.
#
# Adopted from https://unix.stackexchange.com/questions/27013/displaying-seconds-as-days-hours-mins-seconds/170299#170299
# Edited.
#
# args:
# $1 – Time in seconds.
# returns: string
prettifyTimeDisplay()
{
    t=$1

    d=$((t/60/60/24))
    h=$((t/60/60%24))
    m=$((t/60%60))
    s=$((t%60))

	# only show seconds if < 1 minute
    if [ $d = 0 ] && [ $h = 0 ] && [ $m = 0 ]; then
    	[ $s = 1 ] && printf "%d second" $s || printf "%d seconds" $s

		# can skip other if clauses
		return
    fi

	# round up minutes if needed
	if [ $s -ge 30 ]; then
		m=$(( m+1 ))
	fi

    if [ $d -gt 0 ]; then
        [ $d = 1 ] && printf "%d day " $d || printf "%d days " $d
    fi
    if [ $h -gt 0 ]; then
        [ $h = 1 ] && printf "%d hour " $h || printf "%d hours " $h
    fi
    if [ $m -gt 0 ]; then
        [ $m = 1 ] && printf "%d minute " $m || printf "%d minutes " $m
    fi
}
# Return backup info from borg.
#
# The output is returned in several variables.
#
# args:
# $1 – Archive name
getBackupInfo() {
	# get output of borg info
	borginfo=$( $BORG_BIN info "::$1" )

	# get start/end time from output
	timeStart=$( echo "$borginfo"|grep 'Time (start):'|sed -E 's/Time \(start\): (.*)/\1/g' )
	timeEnd=$( echo "$borginfo"|grep 'Time (end):'|sed -E 's/Time \(end\): (.*)/\1/g' )

	timeStartSec=$( date --date="$timeStart" +"%s" )
	timeEndSec=$( date --date="$timeEnd" +"%s" )

	# calculate the difference, i.e. the duration of backup
	durationSec=$(( timeEndSec-timeStartSec ))
	duration=$( prettifyTimeDisplay "$durationSec" | xargs ) # trim sourounding spaces

	# extract the "deduplicated/compressed" value for each size
	size=$( echo "$borginfo"|grep 'This archive:'|sed -E 's/\s{2,}/|/g'|cut -d '|' -f 4 )
	sizeTotal=$( echo "$borginfo"|grep 'All archives:'|sed -E 's/\s{2,}/|/g'|cut -d '|' -f 4 )
}
# Return backup info from the last backup..
#
# The output is returned in several variables. (see getBackupInfo())
#
# args: None
getInfoAboutLastBackup() {
	# get last archive name of new backup
	lastArchive=$( $BORG_BIN list --short ::|tail -n 1 )
	# and get info about it
	getBackupInfo "$lastArchive"
}

# GUI functions (can be overwritten in config file)
guiCanShowNotifications() {
		# exclude headless installations from desktop notifications
	if [ -z "$DISPLAY" ]; then
    	return 1
    else
		# command to get out, whether we can show notifications
		# To disable notifications in every case, you can manually set this
		# to return "false" (or 1, which is shell-speak for false)
        command -v zenity >/dev/null
    fi
}
zenityProxy() {
	sh -c "zenity $*"
}
guiShowNotification() {
	# syntax: title text icon
	title="BorgBackup: $BACKUP_NAME"
	icon="info"
	[ "$1" != "" ] && title="$1"
	[ "$3" != "" ] && icon="$3"
	[ "$GUI_OVERWRITE_ICON" != "" ] && icon="$GUI_OVERWRITE_ICON"

	# if proxy is set, use it, otherwise call zenity directly
	zenityProxy "--notification --window-icon \"$icon\" --text '$title
$2'"
}
guiShowBackupBegin() {
	: # = do nothing, so do not show any notification
}
guiShowBackupSuccess() {
	# prevent quering borg when we cannot show notifications anyway
	guiCanShowNotifications || return 1 # (false)

	getInfoAboutLastBackup
	guiShowNotification "BorgBackup: $BACKUP_NAME – Successful" \
		"It took ${duration} to backup ${size}. (total: ${sizeTotal})" \
		"info"
}
guiShowBackupWarning() {
	# prevent quering borg when we cannot show notifications anyway
	guiCanShowNotifications || return 1 # (false)

	getInfoAboutLastBackup
	guiShowNotification "BorgBackup: $BACKUP_NAME – Warning" \
		"Backup was successful, but showed some warnings. It took ${duration} to backup ${size}. (total: ${sizeTotal})" \
		"warning"
}
guiShowBackupError() {
	guiCanShowNotifications || return 1 # (false)

	guiShowNotification "BorgBackup: $BACKUP_NAME – Error" \
		"The backup process failed. See the log for more details." \
		"error"
}
guiShowBackupAbort() {
	guiCanShowNotifications || return 1 # (false)

	guiShowNotification "BorgBackup: $BACKUP_NAME – Aborted" \
		"Backup has been aborted." \
		"error"
}
guiTryAgain() {
	: # disabled by default
}

# add trap to catch backup interruptions
trapterm() {
	rm_lock 2> /dev/null
	error_log "Backup $BACKUP_NAME (PID: $$) interrupted by $1."
	guiShowBackupAbort
	exit 2
}
trap 'trapterm INT' INT
trap 'trapterm TERM' TERM

# abort, if started without backup config file as input
if [ "$1" != '' ]; then
	# shellcheck source=./config/example-backup.sh
	. "$1"
else
	error_log "Please pass a path of a config file to $(basename "$0")."
	exit 2
fi

# check lock
if is_lock; then
	error_log "Backup $BACKUP_NAME is locked. Prevent start."
	exit 1
fi

# check that variables are set
if [ "$BACKUP_NAME" = "" ] ||
   [ "$BORG_REPO" = "" ] ||
   [ "$ARCHIVE_NAME" = "" ] ||
   [ "$BACKUP_DIRS" = "" ]; then
	error_log 'Some required variables may not be set in the config file. Cancel backup.'
	exit 2
fi
if ! export|grep -q "BORG_REPO"; then
	error_log 'The BORG_REPO variable is not exported in the config file. Cancel backup.'
	exit 2
fi

# check requirements
if isRunningOnBattery; then
	error_log "Canceled backup, because device runs (low) on battery."
	exit 1
fi

# log
info_log "Backup $BACKUP_NAME started with $( $BORG_BIN -V ), helper PID: $$."
guiShowBackupBegin

for i in $( seq "$(( RETRY_NUM+1 ))" ); do
	backupIterationLockCheck "$i"

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
	exitcode_create=$?

	# remove local lock
	rm_lock

	# show output
	evaluateExitCodes "$exitcode_create" "create"

	# optional user question
	guiTryAgain "create" || break;

	# exit loop on non-critical errors (ignore 1 = warnings)
	if [ $exitcode_create -le 1 ]; then
		# save/update last backup time
		if [ -d $LAST_BACKUP_DIR ]; then
			date +'%s' > "$LAST_BACKUP_DIR/$BACKUP_NAME.time"
		fi
		# get out of loop
		break;
	fi
done

# only track latest exit code of execution, i.e. when backups fail but can be
# recovered through retrying, the last code is still 0
track_exitcode $exitcode_create

# The (optional) prefix makes sure only backups from this machine with this
# backup-type are touched.
# ($PRUNE_PARAMS intentionally not quoted)

if [ "$PRUNE_PARAMS" ] && [ "$PRUNE_PREFIX" != "null" ] && [ "$exitcode" -lt 2 ]; then
	info_log "Running prune for \"$BACKUP_NAME\"…"

	# if RETRY_NUM_PRUNE is not set, fall back to RETRY_NUM
	[ "$RETRY_NUM_PRUNE" = "" ] && RETRY_NUM_PRUNE=$RETRY_NUM

	for i in $( seq "$(( RETRY_NUM_PRUNE+1 ))" ); do
		backupIterationLockCheck "$i"

		# add local lock
		do_lock

		# run prune
		# shellcheck disable=SC2086
		$BORG_BIN prune -v --list --prefix "$PRUNE_PREFIX" $PRUNE_PARAMS

		# check return code
		exitcode_prune=$?

		# remove local lock
		rm_lock

		# show output
		evaluateExitCodes "$exitcode_prune" "prune"

		# optional user question
		guiTryAgain "prune" || break;

		# exit loop on non-critical errors (ignore 1 = warnings)
		if [ $exitcode_prune -le 1 ]; then
			# get out of loop
			break;
		fi
	done

	track_exitcode "$exitcode_prune"
fi

# log
if [ "$exitcode" -ne 0 ]; then
	error_log "Backup \"$BACKUP_NAME\" ended, but it seems something went wrong."
else
	info_log "Backup \"$BACKUP_NAME\" ended successfully."
fi

# final notification
case $exitcode in
	0) guiShowBackupSuccess ;;
	1) guiShowBackupWarning ;;
	*) guiShowBackupError "$exitcode" ;; # error code 2 or more
esac

exit "$exitcode"
