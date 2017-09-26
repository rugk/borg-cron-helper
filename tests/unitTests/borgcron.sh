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
# oneTimeTearDown(){
#
# }

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
	assertEquals "stops on missing config dir" \
				"Please pass a path of a config file to borgcron.sh." \
				"$( $TEST_SHELL "$BASE_DIR/borgcron.sh" )"
}

testWrongFilename(){
	addConfigFile "testWrongName.sh"
	assertFalse "fails with wrong filename" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath testWrongName_WRONG.sh )' "
}

testWorks(){
	# this is important for further tests below, because they would all succeed
	# if the basic test taht it "works by default" is not satisfied
	addConfigFile "testWorks.sh"
	startTime="$( date +'%s' )"
	assertTrue "works without any modification" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath testWorks.sh )' "

	# checks that last backup time exists and it's size is larger than 0 and…
	timeFile='/tmp/LAST_BACKUP_DIR/unit-test-fake-backup.time'
	assertTrue "writes/saves backup time" \
				"[ -s '$timeFile' ]"
	# …that the time is realistic (i.e. after start of script)
	assertTrue "saved backup time is realistic" \
				"[ '$( cat "$timeFile" )' -ge '$startTime' ]"
}

testFails(){
	# check that it "properly" fails
	# retry only 2 times
	addConfigFile "testFails.sh" "REPEAT_NUM=2"

	doNotCountVersionRequestsInBorg
	doNotCountLockBreakingsInBorg

	# always exit with critical error
	addFakeBorgCommand 'exit 2'

	# run
	$TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath testFails.sh )" > /dev/null 2>&1
	exitcode=$?

	assertEquals "should fail with correct exit code" \
				"2" \
				"$exitcode"

	# checks that backup time was *not* saved
	timeFile='/tmp/LAST_BACKUP_DIR/unit-test-fake-backup.time'
	assertFalse "should not save last backup time as it was not successful" \
				"[ -f '$timeFile' ]"

	assertEquals "retry exact number of times, given" \
				"2" \
				"$( cat "$BASE_DIR/custombin/counter" )"
}

testMissingVariables(){
	addConfigFile "missingVars1.sh" 'BACKUP_NAME=""'
	assertFalse "stops on missing BACKUP_NAME" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath missingVars.sh )' "

	addConfigFile "missingVars2.sh" 'ARCHIVE_NAME=""'
	assertFalse "stops on missing ARCHIVE_NAME" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath missingVars.sh )'"

	addConfigFile "missingVars3.sh" 'BACKUP_DIRS=""'
	assertFalse "stops on missing BACKUP_DIRS" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath missingVars.sh )'"
}

testMissingExportedVariables(){
	addConfigFile "missingExportedVars1.sh" 'export BORG_REPO=""'
	assertFalse "stops on missing exported BORG_REPO" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath missingExportedVars.sh )'"

	unexportCmd='export -n BORG_REPO'
	# The Travis-CI version of zsh, may not support the -n switch for "export", so we use a different way
	[ "$TEST_SHELL" = "zsh" ] && unexportCmd='unset BORG_REPO&&BORG_REPO=1234'

	addConfigFile "missingExportedVars2.sh" "$unexportCmd"
	assertFalse "stops on only locally set variable (not exported)" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath missingExportedVars.sh )'"
}

testSecurityDataLeak(){
	# This test should prevent:
	# https://github.com/rugk/borg-cron-helper/wiki/Medium-vulnerability:-Data-exposure-with-borg-cron-helper-1.0
	addConfigFile "secDataLeak.sh" 'export BORG_PASSPHRASE="1234_uniquestring_BORG_REPO"
export BORG_REPO="ssh://9876_uniquestring_BORG_REPO__user@somewhere.example:22/./dir"
'
	assertFalse "do not output passphrase" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath secDataLeak.sh )'|grep '1234_uniquestring_BORG_REPO'"
	assertFalse "do not output repo address" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath secDataLeak.sh )'|grep '9876_uniquestring_BORG_REPO'"
}

testLockDisable(){
	addConfigFile "lockTest.sh" 'RUN_PID_DIR=""'

	# PID 1 is always running
	doLock "1"

	assertTrue "does not error when locking is disabled" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath lockTest.sh )'"

	rmLock
}
testLockStopsWhenLocked(){
	addConfigFile "lockTest.sh"

	# PID 1 is always running
	doLock "1"

	assertTrue "stops when locked at start" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath lockTest.sh )' $STDERR_OUTPUT_ONLY|grep 'is locked'"

	rmLock

	# test whether a lock during the sleep period is also detected
	addFakeBorgCommand "$TEST_SHELL -c 'sleep 5s&&echo 1 > /tmp/RUN_PID_DIR/BORG_unit-test-fake-backup.pid' &"
	# let the backup fail to trigger retry
	addFakeBorgCommand 'exit 2'

	assertTrue "stops when locked during sleep period" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath lockTest.sh )' $STDERR_OUTPUT_ONLY|grep 'is locked'"

	rmLock
}
testLockPid(){
	addConfigFile "lockPidTest.sh"

	# add PID, which is not running
	doLock "123456789"

	assertTrue "ignores not running processes" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath lockPidTest.sh )'"

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

	# test whether the lock is there
	addFakeBorgCommand "lockCountFile='$lockCountFile'"
	# shellcheck disable=SC2016
	addFakeBorgCommand 'lockCount=$( cat "$lockCountFile" )'
	# shellcheck disable=SC2016
	addFakeBorgCommand '[ -f "/tmp/RUN_PID_DIR/BORG_unit-test-fake-backup.pid" ] && lockCount=$(( lockCount+1 ))'
	# shellcheck disable=SC2016
	addFakeBorgCommand 'echo $lockCount > "$lockCountFile"'

	assertTrue "process succeeds" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath runningPidTest.sh )'"

	count=$( cat "$BASE_DIR/custombin/counter" )
	lockCount=$( cat "$lockCountFile" )

	assertEquals "does lock in each case borg runs" \
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

	# altghough retry is triggered, as borg suceeds afterwards, it should return 0
	assertTrue "process succeeds" \
				"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath rmPidTest.sh )'"

	assertFalse "does remove lock when borg finished" \
				"[ -e /tmp/RUN_PID_DIR/testFail ]"

	rmLock
}

testRetry(){
	addConfigFile "retryTest.sh"

	doNotCountVersionRequestsInBorg
	doNotCountLockBreakingsInBorg

	# This emulates a signal, which terminates the borg process
	# shellcheck disable=SC2016
	addFakeBorgCommand '[ $count -eq 1 ] && exit 2'
	# checks case with exit code=1 here, it should *NOT* trigger a retry
	# shellcheck disable=SC2016
	addFakeBorgCommand '[ $count -eq 2 ] && exit 1'

	# run command
	$TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath retryTest.sh )" > /dev/null 2>&1
	exitcode=$?

	assertEquals "process returns correct exit code" \
				"1" \
				"$exitcode"

	# 2x borg create
	assertEquals "retry until backup suceeeds" \
				"2" \
				"$( cat "$BASE_DIR/custombin/counter" )"
}

testNotRetry(){
	# must not retry
	addConfigFile "notRetryTest.sh" "REPEAT_NUM=0"

	doNotCountVersionRequestsInBorg
	doNotCountLockBreakingsInBorg

	# always exit with critical error
	addFakeBorgCommand 'exit 2'

	$TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath notRetryTest.sh )" > /dev/null 2>&1
	exitcode=$?

	assertEquals "process fails" \
				"2" \
				"$exitcode"

	# must not retry backup, i.e. only call it once
	count=$( cat "$BASE_DIR/custombin/counter" )
	assertEquals "do not retry backup" \
				"1" \
				"$count"
}

# shellcheck source=../shunit2/shunit2
. "$TEST_DIR/shunit2/shunit2"
