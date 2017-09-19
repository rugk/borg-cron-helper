#!/usr/bin/env sh
#
# Simply unit tests for borgcron starter, using no borg or fake borg binaries.
# Required envorimental variables:
# * $PATH set to include custom binary path
# * $TEST_SHELL
#

CURRDIR=$( dirname "$0" )
# shellcheck source=./common.sh
. "$CURRDIR/common.sh"

# constants
TMPDIR=""
TEST_CONFIG_FILE="$TEST_DIR/config/borgcron.sh"

# make sure, original files are backed up…
oneTimeSetUp(){
	echo "shunit2 v$SHUNIT_VERSION"
	echo "Testing borgcron.sh…"
	echo
}
# oneTimeTearDown(){
#
# }

# cleanup tests to always have an empty config dir
setUp(){
	addFakeBorg

	# create fake dirs, needed for execution of borgcron.sh
	# (they are later "injected" by the fake config file)
	mkdir "/tmp/LAST_BACKUP_DIR"
	mkdir "/tmp/RUN_PID_DIR"

	TMPDIR="$( mktemp -d )"
}
tearDown(){
	removeFakeBorg

	# remove fake dirs
	rm -rf "/tmp/LAST_BACKUP_DIR"
	rm -rf "/tmp/RUN_PID_DIR"

	rm -rf "$TMPDIR"
}

addConfigFile(){
	# syntax: filename.sh "[shell commands to inject, overwrite previous ones]"

	# pass to common function
	addConfigFileToDir "$TMPDIR" "$@"
}
getConfigFilePath(){
	# syntax: filename.sh
	echo "$TMPDIR/$1"
}

# actual unit tests
testMissingParameter(){
	assertEquals "stops on missing config dir" \
				 "Please pass a path of a config file to borgcron.sh." \
				 "$( $TEST_SHELL "$BASE_DIR/borgcron.sh" )"
}

testMissingVariables(){
	addConfigFile "missingVars.sh" 'BACKUP_NAME=""'
	assertFalse "stops on missing BACKUP_NAME" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath missingVars.sh )' "

	addConfigFile "missingVars.sh" 'ARCHIVE_NAME=""'
	assertFalse "stops on missing ARCHIVE_NAME" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath missingVars.sh )'"

	addConfigFile "missingVars.sh" 'BACKUP_DIRS=""'
	assertFalse "stops on missing BACKUP_DIRS" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath missingVars.sh )'"
}

testMissingExportedVariables(){
	addConfigFile "missingExportedVars.sh" 'export BORG_REPO=""'
	assertFalse "stops on missing exported BORG_REPO" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath missingExportedVars.sh )'"

	addConfigFile "missingExportedVars.sh" 'export -n BORG_REPO'
	assertFalse "stops on only locally set variable (not exported)" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath missingExportedVars.sh )'"
}

testSecurityDataLeak(){
	# This test should prevent:
	# https://github.com/rugk/borg-cron-helper/wiki/Minor-vulnerability:-Data-exposure-with-borg-cron-helper-1.0
	addConfigFile "secDataLeak.sh" 'export BORG_PASSPHRASE="1234_uniquestring_BORG_REPO"
export BORG_REPO="ssh://9876_uniquestring_BORG_REPO__user@somewhere.example:22/./dir"
'
	assertFalse "do not output passphrase" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath secDataLeak.sh )'|grep '1234_uniquestring_BORG_REPO'"
	assertFalse "do not output repo address" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath secDataLeak.sh )'|grep '9876_uniquestring_BORG_REPO'"
}

# shellcheck source=../shunit2/source/2.1/src/shunit2
. "$TEST_DIR/shunit2/source/2.1/src/shunit2"
