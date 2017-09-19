#!/usr/bin/env sh
# shellcheck disable=SC2034
#
# Common variables/fucntions used by unit tests.
#

get_full_path() {
	# thanks https://stackoverflow.com/questions/5265702/how-to-get-full-path-of-a-file
	# use realpath command, if it exists
	if command -v realpath >/dev/null 2>&1; then
		realpath "$1"
	else
		readlink -f "$1"
	fi
}

addConfigFileToDir(){
	# syntax: dir filename.sh "[shell commands to inject, overwrite previous ones]"
	# add static head
	{
		echo "#!/bin/sh"
		echo "CURRDIR='$1'"
		echo "FILENAME='$2'"
	} > "$1/$2"

	# add template
	cat "$TEST_CONFIG_FILE" >> "$1/$2"

	if [ "$3" != "" ]; then
		{
			echo
			echo "# Custom adjustments, overwrites by test script"
			echo "$3"
		} >> "$1/$2"
	fi
}
addFakeBorg(){
	# adds a fake "borg" binary, which is a simple shell script
	mv "$BASE_DIR/custombin/borg" "$BASE_DIR/custombin/borg-disabled"
	cp "$TEST_DIR/fakeBorg.sh" "$BASE_DIR/custombin/borg"
}
removeFakeBorg(){
	# restores the original borg
	if [ -e "$BASE_DIR/custombin/borg-disabled" ]; then
		rm "$BASE_DIR/custombin/borg"
		mv "$BASE_DIR/custombin/borg-disabled" "$BASE_DIR/custombin/borg"

		# remove loggers
		[ -e "$BASE_DIR/custombin/counter" ] && rm "$BASE_DIR/custombin/counter"
		[ -e "$BASE_DIR/custombin/list" ] && rm "$BASE_DIR/custombin/list"
	fi
}
addFakeBorgCommand(){
	echo "$*" >> "$BASE_DIR/custombin/borg"
}
addFakeBorgCommandOnBeginning(){
	echo "#!/bin/sh
$1
$( cat "$BASE_DIR/custombin/borg" )" > "$BASE_DIR/custombin/borg"
}
resetFakeBorg(){
	# (overwrites by default)
	cp "$TEST_DIR/fakeBorg.sh" "$BASE_DIR/custombin/borg"
}
doNotCountVersionRequestsInBorg(){
	# ignore easy -V commands for all counts
	# shellcheck disable=SC2016
	addFakeBorgCommandOnBeginning '[ "$1" = "-V" ] && exit 0'
}

CURRDIR="$( get_full_path "$CURRDIR" )"
BASE_DIR="$( get_full_path "$CURRDIR/../.." )"
TEST_DIR="$BASE_DIR/tests"
CONFIG_DIR="$BASE_DIR/config"
TEST_CONFIG_FILE="$TEST_DIR/config/template.sh"
PIPE_STDERR="2>&1"
PIPE_STDERR_ONLY="$PIPE_STDERR >/dev/null"
