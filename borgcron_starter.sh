#!/bin/sh
# Cron script to execute the borg backup.
#
# LICENSE: MIT license, see LICENSE.md
#

# dir where config files are stored
CONFIG_DIR="$( dirname "$0" )/config"

help() {
	echo "Usage:"
	echo "$( basename "$0" ) [<files>]"
	echo
	echo "files	If <files> is given, it will cycle through each given config file and"
	echo "		execute the backups exactly as given on the command line."
	echo "		If it is not given, it will just run all backups one by one."
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

# check for error if config dir is empty
if [ ! "$(  dir_contains_files "$CONFIG_DIR" )" ]; then
	echo "No backup settings file(s) could be found in the config folder \"$CONFIG_DIR\"."
	echo "To get help enter: $( basename "$0" ) --help"
fi

# parse parameters
case "$1" in
	'' ) # process all backup config files in $CONFIG_DIR
		for configfile in $CONFIG_DIR/*.sh;
		do
			./borgcron.sh "$( get_full_path "$configfile" )"
		done
		;;
	--help|-h|-? ) # show help message
		help
		exit
		;;
	*)  # specific config file(s) passed
		for configfile in "$@"; do
			if [ -e "$CONFIG_DIR/$configfile.sh" ]; then
				./borgcron.sh "$( get_full_path "$CONFIG_DIR/$configfile.sh" )"
			else
				echo "The backup settings file \"$configfile\" could not be found." >&2
			fi
		done
		;;
esac
