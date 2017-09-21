#!/usr/bin/env sh
# shellcheck disable=SC2034
#
# Common variables/fucntions used by unit tests.
#
# LICENSE: MIT license, see LICENSE.md
#

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
assertAndCatchOutput(){
	# runs a shunit2 assert, but also catches the output in "$output".
	# syntax: assertWhat message commandToExecute
	# output: $output
	outputfile="$TMPDIR/runoutput"
	output=''

	touch "$outputfile"
	$1 "$2" "$3 $STDERR_TO_STDOUT|tee '$outputfile'"

	# show output
	output=$( cat "$outputfile" )

	rm "$outputfile"
}
assertAndOutput(){
	# runs a shunit2 assert, but also shows the output in the command line.
	# Note that it can only show the output *after* the command has completed.
	# syntax: assertWhat message commandToExecute
	# output: $output, STDOUT
	assertAndCatchOutput "$@"

	echo "$output"
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
	mv "$BASE_DIR/custombin/borg" "$BASE_DIR/custombin/borg-disabled"||exit 1
	cp "$TEST_DIR/fakeBorg.sh" "$BASE_DIR/custombin/borg"||exit 1
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
doNotCountLockBreakingsInBorg(){
	# ignore break-lock commands for all counts
	# shellcheck disable=SC2016
	addFakeBorgCommandOnBeginning '[ "$1" = "break-lock" ] && exit 0'
}

CURRDIR="$( get_full_path "$CURRDIR" )"
BASE_DIR="$( get_full_path "$CURRDIR/../.." )"
TEST_DIR="$BASE_DIR/tests"
CONFIG_DIR="$BASE_DIR/config"
TEST_CONFIG_FILE="$TEST_DIR/config/template.sh"
STDERR_TO_STDOUT="2>&1"
STDERR_OUTPUT_ONLY="$STDERR_TO_STDOUT >/dev/null"
