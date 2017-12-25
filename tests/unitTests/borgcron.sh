#!/usr/bin/env sh
#
# Simply unit tests for borgcron starter, using no borg or fake borg binaries.
# Required envorimental variables:
# * $PATH set to include custom binary path
# * $TEST_SHELL
#
# LICENSE: MIT license, see LICENSE.md
#

CURRDIR=$( dirname "$0" )
# shellcheck source=./common.sh
. "$CURRDIR/common.sh"

# constants
TMPDIR=""

# make sure, original files are backed up…
oneTimeSetUp(){
	echo "shunit2 v$SHUNIT_VERSION"
	echo "Testing borgcron.sh…"
	echo
}

# cleanup tests to always have an empty temp dirs
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

# helper functions
addConfigFile(){
	# syntax: filename.sh "[shell commands to inject, overwrite previous ones]"

	# pass to common function
	addConfigFileToDir "$TMPDIR" "$@"
}
getConfigFilePath(){
	# syntax: filename.sh
	echo "$TMPDIR/$1"
}
doLock(){
	echo "$1" > "/tmp/RUN_PID_DIR/BORG_unit-test-fake-backup.pid"
}
rmLock(){
	[ -f "/tmp/RUN_PID_DIR/BORG_unit-test-fake-backup.pid" ] && rm "/tmp/RUN_PID_DIR/BORG_unit-test-fake-backup.pid"
}

# actual unit tests
testMissingParameter(){
	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" 2>&1 )"
	exitcode=$?

	assertFalse "does not exit with correct error code when parameter is missing; exited with ${exitcode}, output: ${output}" \
				"$exitcode"

	assertTrue "does not exit with correct error message when parameter is missing; exited with ${exitcode}, output: ${output}" \
				'echo "$output"|grep "Please pass a path of a config file to borgcron.sh."'
}

testWrongFilename(){
	addConfigFile "testWrongName.sh"

	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath testWrongName_WRONG.sh )" 2>&1 )"
	exitcode=$?

	assertFalse "does not exit with failing error code when specified config file is missing; exited with ${exitcode}, output: ${output}" \
				"$output"
}

testWorks(){
	# this is important for further tests below, because they would all succeed
	# if the basic test that it "works by default" is not satisfied
	addConfigFile "testWorks.sh"
	startTime="$( date +'%s' )"

	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath testWorks.sh )" 2>&1 )"
	exitcode=$?

	assertTrue "fails with basic errorfree template config; exited with ${exitcode}, output: ${output}" \
				"$exitcode"

	# checks that last backup time exists and it's size is larger than 0 and…
	timeFile='/tmp/LAST_BACKUP_DIR/unit-test-fake-backup.time'
	assertTrue "does not write/save backup time; exited with ${exitcode}, output: ${output}" \
				"[ -s '$timeFile' ]"
	# …that the time is realistic (i.e. after start of script)
	assertTrue "saved backup time is unrealistic; exited with ${exitcode}, output: ${output}" \
				"[ '$( cat "$timeFile" )' -ge '$startTime' ]"
}

testFails(){
	# check that it "properly" fails
	# retry only 1 time
	addConfigFile "testFails.sh" "RETRY_NUM=1"

	doNotCountVersionRequestsInBorg
	doNotCountLockBreakingsInBorg
	doNotCountInfoAndListsRequestsInBorg

	# always exit with critical error
	addFakeBorgCommand 'exit 2'

	# run
	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath testFails.sh )" 2>&1 )"
	exitcode=$?

	assertEquals "returns wrong exit code; exited with ${exitcode}, output: ${output}" \
				"2" \
				"$exitcode"

	# checks that backup time was *not* saved
	timeFile='/tmp/LAST_BACKUP_DIR/unit-test-fake-backup.time'
	assertFalse "saves last backup time altghough backup was not successful; exited with ${exitcode}, output: ${output}" \
				"[ -f '$timeFile' ]"

	assertEquals "retries an incorrect number of times, given; exited with ${exitcode}, output: ${output}" \
				"2" \
				"$( cat "$BASE_DIR/custombin/counter" )"
}

testUsesBorgBin(){
	# ensures the borg binary specified in $BORG_BIN is used and not "borg" literally
	addConfigFile "testBorgBin.sh" "BORG_BIN=borg-ok"

	# add borg-ok binary doing nothing
	echo '#!/bin/sh' > "$BASE_DIR/custombin/borg-ok"
	chmod +x "$BASE_DIR/custombin/borg-ok"

	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath testBorgBin.sh )" 2>&1 )"
	exitcode=$?

	# run backup
	assertTrue "execution fails; exited with ${exitcode}, output: ${output}" \
				"$exitcode"

	# must not call the "real fake borg binary", but borg-ok.
	assertFalse "still runs the borg binary when \$BORG_BIN is set, i.e. ignores \$BORG_BIN setting; exited with ${exitcode}, output: ${output}" \
				"[ -f '$BASE_DIR/custombin/counter' ]"

	# remove borg-ok
	rm "$BASE_DIR/custombin/borg-ok"
}

testMissingVariables(){
	addConfigFile "missingVars1.sh" 'BACKUP_NAME=""'
	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath missingVars1.sh )" 2>&1 )"
	exitcode=$?
	assertFalse "does not stop on missing BACKUP_NAME; exited with ${exitcode}, output: ${output}" \
				"$exitcode"

	addConfigFile "missingVars2.sh" 'ARCHIVE_NAME=""'
	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath missingVars2.sh )" 2>&1 )"
	exitcode=$?
	assertFalse "does not stop on missing ARCHIVE_NAME; exited with ${exitcode}, output: ${output}" \
				"$exitcode"

	addConfigFile "missingVars3.sh" 'BACKUP_DIRS=""'
	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath missingVars3.sh )" 2>&1 )"
	exitcode=$?
	assertFalse "does not stop on missing BACKUP_DIRS; exited with ${exitcode}, output: ${output}" \
				"$exitcode"
}

testMissingExportedVariables(){
	addConfigFile "missingExportedVars1.sh" 'export BORG_REPO=""'
	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath missingExportedVars1.sh )" 2>&1 )"
	exitcode=$?
	assertFalse "does not stop on missing exported BORG_REPO; exited with ${exitcode}, output: ${output}" \
				"$exitcode"

	unexportCmd='export -n BORG_REPO'
	# The Travis-CI version of zsh, may not support the -n switch for "export", so we use a different way
	[ "$TEST_SHELL" = "zsh" ] && unexportCmd='unset BORG_REPO&&BORG_REPO=1234'

	addConfigFile "missingExportedVars2.sh" "$unexportCmd"
	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath missingExportedVars2.sh )" 2>&1 )"
	exitcode=$?
	assertFalse "does not stop on only locally set variable (not exported); exited with ${exitcode}, output: ${output}" \
				"$exitcode"
}

testSecurityDataLeak(){
	# This test should prevent:
	# https://github.com/rugk/borg-cron-helper/wiki/Medium-vulnerability:-Data-exposure-with-borg-cron-helper-1.0
	addConfigFile "secDataLeak.sh" 'export BORG_PASSPHRASE="1234_uniquestring_BORG_REPO"
export BORG_REPO="ssh://9876_uniquestring_BORG_REPO__user@somewhere.example:22/./dir"
'

	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath secDataLeak.sh )" 2>&1 )"
	exitcode=$?

	# shellcheck disable=SC2016
	assertFalse "does output passphrase; exited with ${exitcode}, output: ${output}" \
				'echo "$output"|grep "1234_uniquestring_BORG_REPO"'

	# shellcheck disable=SC2016
	assertFalse "does output repo address; exited with ${exitcode}, output: ${output}" \
				'echo "$output"|grep "9876_uniquestring_BORG_REPO"'
}

testLockDisable(){
	addConfigFile "lockTestDisabled.sh" 'RUN_PID_DIR=""'

	# PID 1 is always running
	doLock "1"

	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath lockTestDisabled.sh )" 2>&1 )"
	exitcode=$?

	assertTrue "fails even if locking is disabled; exited with ${exitcode}, output: ${output}" \
				"$exitcode"

	rmLock
}
testLockStopsWhenLocked(){
	addConfigFile "lockTest.sh"

	# PID 1 is always running
	doLock "1"

	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath lockTest.sh )" 2>&1 )"
	exitcode=$?

	assertFalse "does not end with error exit code when locked at start; exited with ${exitcode}, output: ${output}" \
				"$exitcode"
	# shellcheck disable=SC2016
	assertTrue "does not stop with error message when locked at start" \
				'echo "$output"|grep "is locked"'

	rmLock

	# test whether a lock during the sleep period is also detected
	addFakeBorgCommand "$TEST_SHELL -c 'sleep 5s&&echo 1 > /tmp/RUN_PID_DIR/BORG_unit-test-fake-backup.pid' &"
	# let the backup fail to trigger retry
	addFakeBorgCommand 'exit 2'

	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath lockTest.sh )" 2>&1 )"
	exitcode=$?

	assertFalse "does not end with error exit code when locked during sleep period; exited with ${exitcode}, output: ${output}" \
				"$exitcode"
	# shellcheck disable=SC2016
	assertTrue "does not stop with error message when locked during sleep period" \
				'echo "$output"|grep "is locked"'

	rmLock
}
testLockPid(){
	addConfigFile "lockPidTest.sh"

	# add PID, which is not running
	doLock "123456789"

	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath lockPidTest.sh )" 2>&1 )"
	exitcode=$?

	assertTrue "does not ignore not running processes, i.e. fails; exited with ${exitcode}, output: ${output}" \
				"$exitcode"

	rmLock
}
testLocksWhenBorgRuns(){
	# adding prune params to also test prune borg call (& lock there)
	# shellcheck disable=SC2016
	addConfigFile "runningPidTest.sh" 'PRUNE_PARAMS="--test-fake"
PRUNE_PREFIX="{hostname}-$BACKUP_NAME-"'

	lockCountFile="/tmp/RUN_PID_DIR/lockCounter"
	echo "0" > "$lockCountFile"

	doNotCountVersionRequestsInBorg
	doNotCountLockBreakingsInBorg
	doNotCountInfoAndListsRequestsInBorg

	# test whether the lock is there
	addFakeBorgCommand "lockCountFile='$lockCountFile'"
	# shellcheck disable=SC2016
	addFakeBorgCommand 'lockCount=$( cat "$lockCountFile" )'
	# shellcheck disable=SC2016
	addFakeBorgCommand '[ -f "/tmp/RUN_PID_DIR/BORG_unit-test-fake-backup.pid" ] && lockCount=$(( lockCount+1 ))'
	# shellcheck disable=SC2016
	addFakeBorgCommand 'echo $lockCount > "$lockCountFile"'

	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath runningPidTest.sh )" 2>&1 )"
	exitcode=$?

	assertTrue "backup process fails; exited with ${exitcode}, output: ${output}" \
				"$exitcode"

	count=$( cat "$BASE_DIR/custombin/counter" )
	lockCount=$( cat "$lockCountFile" )

	assertEquals "does not lock in each case borg runs; exited with ${exitcode}, output: ${output}" \
				"$count" \
				"$lockCount"
}
testLockRemoved(){
	addConfigFile "rmPidTest.sh"

	# add PID, which is not running
	doLock "123456789"

	# unless the second run of borg (i.e. after calling -V, the first "real" backup) is done, exit with 0 (ok)
	# shellcheck disable=SC2016
	addFakeBorgCommand 'if [ "$count" -le 1 ] || [ "$count" -ge 3 ]; then exit 0; fi'
	# add lock during backup/sleep process in order to test whether the lock is removed after borg ended
	addFakeBorgCommand "$TEST_SHELL -c 'sleep 5s;[ -f /tmp/RUN_PID_DIR/BORG_unit-test-fake-backup.pid ]&&echo 1 > /tmp/RUN_PID_DIR/testFail' &"
	# let the backup fail to trigger retry
	addFakeBorgCommand 'exit 2'

	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath rmPidTest.sh )" 2>&1 )"
	exitcode=$?

	# altghough retry is triggered, as borg suceeds afterwards, it should return 0
	assertTrue "process fails altghough one backup execution suceeded; exited with ${exitcode}, output: ${output}" \
				"$exitcode"

	assertFalse "does remove lock when borg finished" \
				"[ -e /tmp/RUN_PID_DIR/testFail ]"

	rmLock
}

testRetry(){
	addConfigFile "retryTest.sh"

	doNotCountVersionRequestsInBorg
	doNotCountLockBreakingsInBorg
	doNotCountInfoAndListsRequestsInBorg

	# This emulates a signal, which terminates the borg process
	# shellcheck disable=SC2016
	addFakeBorgCommand '[ $count -eq 1 ] && exit 2'
	# checks case with exit code=1 here, it should *NOT* trigger a retry
	# shellcheck disable=SC2016
	addFakeBorgCommand '[ $count -eq 2 ] && exit 1'

	# run command
	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath retryTest.sh )" 2>&1 )"
	exitcode=$?

	assertEquals "process returns wrong exit code; exited with ${exitcode}, output: ${output}" \
				"1" \
				"$exitcode"

	# 2x borg create
	assertEquals "does not retry until backup suceeeds; exited with ${exitcode}, output: ${output}" \
				"2" \
				"$( cat "$BASE_DIR/custombin/counter" )"
}

testNotRetry(){
	# must not retry
	addConfigFile "notRetryTest.sh" "RETRY_NUM=0"

	doNotCountVersionRequestsInBorg
	doNotCountLockBreakingsInBorg
	doNotCountInfoAndListsRequestsInBorg

	# always exit with critical error
	addFakeBorgCommand 'exit 2'

	output="$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath notRetryTest.sh )" 2>&1 )"
	exitcode=$?

	assertEquals "process does not fail with correct exit code; exited with ${exitcode}, output: ${output}" \
				"2" \
				"$exitcode"

	# must not retry backup, i.e. only call it once
	count=$( cat "$BASE_DIR/custombin/counter" )
	assertEquals "retries backup; exited with ${exitcode}, output: ${output}" \
				"1" \
				"$count"
}

# shellcheck source=../shunit2/shunit2
. "$TEST_DIR/shunit2/shunit2"
