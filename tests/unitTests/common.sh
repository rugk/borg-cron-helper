#!/usr/bin/env sh
# shellcheck disable=SC2034
#
# Common variables/fucntions used by unit tests.
#
# LICENSE: MIT license, see LICENSE.md
#

# add trap, so tests are at least properly shut down
trapterm() {
	echo "Force shutdown…"
	tearDown 2> /dev/null
	oneTimeTearDown 2> /dev/null
	exit 2
}
trap trapterm INT TERM

escapeStringForSed(){
	# thanks https://stackoverflow.com/questions/407523/escape-a-string-for-a-sed-replace-pattern#answer-2705678
	echo "$1"|sed -e 's/[]\#$*.^|[]/\\&/g'
}
# thanks to https://stackoverflow.com/questions/16989598/bash-comparing-version-numbers#answer-24067243
version_gt() {
	test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1";
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

addConfigFileToDir(){
	# syntax: dir filename.sh "[shell commands to inject, overwrite previous ones]"
	# add static head
	{
		echo "#!/bin/sh"
		echo "RUNDIR='$1'"
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

# used for fake borg
addFakeBorg(){
	# adds a fake "borg" binary, which is a simple shell script
	mv "$CUSTOMBIN_DIR/borg" "$CUSTOMBIN_DIR/borg-disabled"||exit 1
	cp "$TEST_DIR/fakeBorg.sh" "$CUSTOMBIN_DIR/borg"||exit 1
}
removeFakeBorg(){
	# restores the original borg
	if [ -e "$CUSTOMBIN_DIR/borg-disabled" ]; then
		rm "$CUSTOMBIN_DIR/borg"
		mv "$CUSTOMBIN_DIR/borg-disabled" "$CUSTOMBIN_DIR/borg"

		# remove loggers
		[ -e "$CUSTOMBIN_DIR/counter" ] && rm "$CUSTOMBIN_DIR/counter"
		[ -e "$CUSTOMBIN_DIR/list" ] && rm "$CUSTOMBIN_DIR/list"
	fi
}
addFakeBorgCommand(){
	echo "$*" >> "$CUSTOMBIN_DIR/borg"
}
addFakeBorgCommandOnBeginning(){
	echo "#!/bin/sh
$1
$( cat "$CUSTOMBIN_DIR/borg" )" > "$CUSTOMBIN_DIR/borg"
}
resetFakeBorg(){
	# (overwrites by default)
	cp "$TEST_DIR/fakeBorg.sh" "$CUSTOMBIN_DIR/borg"
}
ignoreVersionRequestsInBorg(){
	# ignore easy -V commands for all counts
	# shellcheck disable=SC2016
	addFakeBorgCommandOnBeginning '[ "$1" = "-V" ] && exit 0'
}
ignoreLockBreakingsInBorg(){
	# ignore break-lock commands for all counts
	# shellcheck disable=SC2016
	addFakeBorgCommandOnBeginning '[ "$1" = "break-lock" ] && exit 0'
}
ignoreInfoAndListsRequestsInBorg(){
	# ignore break-lock commands for all counts
	# shellcheck disable=SC2016
	addFakeBorgCommandOnBeginning '[ "$1" = "list" ] && exit 0'
	# shellcheck disable=SC2016
	addFakeBorgCommandOnBeginning '[ "$1" = "info" ] && exit 0'
}

# used for real borg
patchConfigAdd(){
	# syntax: filename.sh string to add
	echo "$2" >> "$CONFIG_DIR/$1"
}
patchConfigDisableVar(){
	# syntax: filename.sh variable internalvar
	sed -i "s/^[[:space:]]*$2=/# $2=/g" "$CONFIG_DIR/$1"

	# run (once) recursive with export
	[ "$3" != "notRecursive" ] && patchConfigDisableVar "$1" "export $2" "notRecursive"
}
patchConfigEnableVar(){
	# syntax: filename.sh variable internalvar
	sed -i "s/^#[[:space:]]*$2=/$2=/g" "$CONFIG_DIR/$1"

	# run (once) recursive with export
	[ "$3" != "notRecursive" ] && patchConfigEnableVar "$1" "export $2" "notRecursive"
}
patchConfigSetVar(){
	# syntax: filename.sh variable value [quoteChar] internalvar
	quoteChar="'" # default quote char
	[ -n "$4" ] && quoteChar="$4"

	varEscaped="$( escapeStringForSed "$3" )"

	# automatically enable variable
	patchConfigEnableVar "$1" "$2" "notRecursive"

	sed -i "s#^[[:space:]]*$2=['\"].*['|\"]#$2=${quoteChar}${varEscaped}${quoteChar}#g" "$CONFIG_DIR/$1"

	# run (once) recursive with export
	[ "$5" != "notRecursive" ] && patchConfigSetVar "$1" "export $2" "$3" "$4" "notRecursive"
}

CURRDIR="$( get_full_path "$CURRDIR" )"
BASE_DIR="$( get_full_path "$CURRDIR/../.." )"
CUSTOMBIN_DIR="$BASE_DIR/custombin"
TEST_DIR="$BASE_DIR/tests"
CONFIG_DIR="$BASE_DIR/config"
TEST_CONFIG_FILE="$TEST_DIR/config/template.sh"
STDERR_TO_STDOUT="2>&1"
STDERR_OUTPUT_ONLY="$STDERR_TO_STDOUT >/dev/null"
