#!/bin/sh
# Cron script to execute borg backup regularely using a local lock & retry system.
#
# LICENSE: MIT license, see LICENSE.md
#


###########
# Default settings (see also borgcron_worker.sh)
###########
CONFIG_DIR='config'




info_log() {
	echo "[$( date +'%F %T' )] $*" >&2
}
trapterm() {
    rm_lock 2> /dev/null
    info_log "Backup (PID: $$) interrupted by $1." >&2
    exit 2
}

# add trap to catch terminating signals
trap 'trapterm INT' INT
trap 'trapterm TERM' TERM


# select action from user input

HELPTEXT="Usage:\n"$(basename "$0")" 	will execute backup(s)for every backup-config file within the configured config folder\n"$(basename "$0")" [<file>]... 	will execute only the given backup(s)"
case "$1" in
		'') # process all backup files in CONFIG_DIR
			for CONFIGFILE in $CONFIG_DIR/*;
			do
				if [ -f "$CONFIGFILE" ]; then
					./borgcron_worker.sh "$CONFIGFILE"
				else
					#user should feel "safe" with standard --help command, altough you could likewise enter some rubbish as argument
					info_log "No backup-settings file(s) found in your configured folder \"$CONFIG_DIR\". There has not been created a backup!\nFor help enter:\n"$(basename "$0")" --help\n"

				fi
			done
			;;
		--help) #show help message
			echo $HELPTEXT
			exit
				;;
		*) # config file passed
			while [ "$1" != '' ]; do
				CONFIGFILE=$1
				echo hier
				echo "$CONFIG_DIR/$CONFIGFILE"
				if [ -f "$CONFIG_DIR/$CONFIGFILE" ]; then
					echo "$CONFIG_DIR/$CONFIGFILE"
					./borgcron_worker.sh "$CONFIG_DIR/$CONFIGFILE"
				else
				info_log "Your backup-settings file(s) "$CONFIGFILE" has not been found. There has not been created a backup!\n\n$HELPTEXT"
				exit
				fi
			shift 1
			done
			;;
esac


