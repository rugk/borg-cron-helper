#!/bin/sh
# Cron script to execute the borg backup.
#
# LICENSE: MIT license, see LICENSE.md
#

CURRENT_DIR="$( dirname "$0" )"
# dir where config files are stored
CONFIG_DIR="$CURRENT_DIR/config"

# basic functions
track_exitcode() {
	if [ "$1" -gt "$exitcode" ]; then
		exitcode="$1"
	fi
}
dir_contains_files() {
	ls -A "$1"
}
get_full_path() {
	# thanks https://stackoverflow.com/questions/5265702/how-to-get-full-path-of-a-file
	# use realpath command, if it exists
	if command -v realpath >/dev/null 2>&1; then
		realpath "$1"
	else
		readlink -f "$1"
	fi
}

cli_help() {
	echo "Usage:"
	echo "$( basename "$0" ) [<files>]"
	echo
	echo "files	If <files> is given, it will cycle through each given config file and"
	echo "		execute the backups exactly as given on the command line."
	echo "		If it is not given, it will just run all backups one by one."
}

exitcode=0 #exitcode on zero :)

# check for error if config dir is empty
if [ ! -d "$CONFIG_DIR" ] || [ ! "$( dir_contains_files "$CONFIG_DIR" )" ]; then
	echo "No backup settings file(s) could be found in the config folder \"$CONFIG_DIR\"."
	echo "To get help enter: $( basename "$0" ) --help"
	exit 1
fi

# parse parameters
case "$1" in
	'' ) # process all backup config files in $CONFIG_DIR
		for configfile in "$CONFIG_DIR"/*.sh;
		do
			"$CURRENT_DIR/borgcron.sh" "$( get_full_path "$configfile" )"
			track_exitcode "$?"
		done
		;;
	--help|-h|-? ) # show help message
		cli_help
		exit
		;;
	*) # specific config file(s) passed
		for configfile in "$@"; do
			# remove possible ".sh" ending
			configfile="$( echo "$configfile"|sed 's/.sh$//')"

			if [ -e "$CONFIG_DIR/$configfile.sh" ]; then
				"$CURRENT_DIR/borgcron.sh" "$( get_full_path "$CONFIG_DIR/$configfile.sh" )"
				track_exitcode "$?"
			else
				echo "The backup settings file \"$configfile.sh\" could not be found." >&2
				track_exitcode 1 # custom exit code for "file not found" warning
			fi
		done
		;;
esac

exit "$exitcode"
