#!/usr/bin/env sh
#
# Executes final unit tests using the real borg binary.
# Required envorimental variables:
# * $TEST_SHELL
# * $BORG
#
# LICENSE: MIT license, see LICENSE.md
#

CURRDIR=$( dirname "$0" )
# shellcheck source=./common.sh
. "$CURRDIR/common.sh"

# constants
TMPDIR="$( mktemp -d )"
BORGREPO_PRESET_OLD="$TEST_DIR/borgdata/oldbackups-prefix1and2"

# make sure, original files are backed up…
oneTimeSetUp(){
	echo "shunit2 v$SHUNIT_VERSION"
	echo "Testing with real borg…"
	echo
	mv "$CONFIG_DIR" "$TMPDIR"||exit 1

	# set variables, so when borg is called here, it also uses the correct dirs
	export BORG_KEYS_DIR="$TMPDIR/borg/keys"
	export BORG_SECURITY_DIR="$TMPDIR/borg/security"
	export BORG_CACHE_DIR="$TMPDIR/borg/cache"
}
oneTimeTearDown(){
	mv "$TMPDIR/config" "$BASE_DIR"

	# cleanup TMPDIR
	rm -rf "$TMPDIR"
}

# cleanup tests to always have an empty temp dirs
setUp(){
	# create fake dirs, needed for execution of borgcron.sh
	# (they are later "injected" by the fake config file)
	mkdir "/tmp/LAST_BACKUP_DIR"
	mkdir "/tmp/RUN_PID_DIR"
	mkdir "/tmp/borg_repodir"

	# create dir for borg-internal stuff
	mkdir -p "$TMPDIR/borg"

	# create dir if it does not exist
	mkdir "$CONFIG_DIR" 2> /dev/null

	# add real example file
	cp "$TMPDIR/config/example-backup.sh" "$CONFIG_DIR/exampleTest.sh"

	# patch example file, so it works
	patchConfigSetVar "exampleTest.sh" 'BACKUP_NAME' "unit-test-fake-backup"
	patchConfigSetVar "exampleTest.sh" 'BORG_REPO' "/tmp/borg_repodir"
	# IMPORTANT NOTE: As also mentioned in the example config, these paths **must not**
	# have spaces. Otherwise some tests may fail.
	patchConfigSetVar "exampleTest.sh" 'BACKUP_DIRS' "$BASE_DIR/.git $TEST_DIR/shunit2/.git" '"'
	patchConfigSetVar "exampleTest.sh" 'SLEEP_TIME' "5m" '"'

	# shellcheck disable=SC2016
	patchConfigAdd "exampleTest.sh" "
# overwrite built-in variables, so dirs work
LAST_BACKUP_DIR='/tmp/LAST_BACKUP_DIR'
RUN_PID_DIR='/tmp/RUN_PID_DIR'

# disable notifications, which just annoy in unit tests
guiShowNotification() { :; }

# make tests faster, use small sleep time
SLEEP_TIME='20s'

# use temp variables, so no trash remains on the system
export BORG_KEYS_DIR='$TMPDIR/borg/keys'
export BORG_SECURITY_DIR='$TMPDIR/borg/security'
export BORG_CACHE_DIR='$TMPDIR/borg/cache'
"
}
tearDown(){
	# remove fake dirs
	rm -rf "/tmp/LAST_BACKUP_DIR"
	rm -rf "/tmp/RUN_PID_DIR"
	rm -rf "/tmp/borg_repodir"

	rm -rf "$TMPDIR/borg"

	# remove propbably remaining config files
	rm -rf "$CONFIG_DIR" 2> /dev/null
}

# helper functions
getConfigFilePath(){
	# syntax: filename.sh
	echo "$CONFIG_DIR/$1"
}
doLock(){
	echo "$1" > "/tmp/RUN_PID_DIR/BORG_unit-test-fake-backup.pid"
}
rmLock(){
	[ -f "/tmp/RUN_PID_DIR/BORG_unit-test-fake-backup.pid" ] && rm "/tmp/RUN_PID_DIR/BORG_unit-test-fake-backup.pid"
}

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
createBackup(){
	# syntax: repo prefix name suffix
	borg create "$1::$2$3-$4" "$BASE_DIR/icon.png" # > /dev/null 2>&1
	# output name of backup
	echo "$2$3-$4"
}

# actual unit tests
testBorgUnencrypted(){
	# borg init to create repo
	borg init --encryption=none "/tmp/borg_repodir"

	patchConfigDisableVar "exampleTest.sh" 'BORG_PASSCOMMAND'
	patchConfigDisableVar "exampleTest.sh" 'BORG_PASSPHRASE'

	# set unique name
	# shellcheck disable=2016
	patchConfigSetVar "exampleTest.sh" 'ARCHIVE_NAME' '{hostname}-$BACKUP_NAME-{now:%Y-%m-%d}-UNIQUESTRING-for-test918' '"'

	# also test prune
	patchConfigEnableVar "exampleTest.sh" 'PRUNE_PARAMS'

	HOSTNAME="$( uname -n )"
	# workaround for borg < v1.0.4
	if ! version_gt "$BORG" "v1.0.3"; then
		patchConfigSetVar "exampleTest.sh" 'PRUNE_PREFIX' "$HOSTNAME-unit-test-fake-backup-"
	fi

	startTime=$( date +%s )
	# shellcheck disable=SC2034
	output=$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath exampleTest.sh )" 2>&1 )
	exitcode=$?
	endTime=$( date +%s )

	# show output
	echo "$output"

	# check whether backup is sucessful
	assertEquals "backup finishes without error" \
				"0" \
				"$exitcode"

	# when it took more than 15 seconds, it likely retried the backup (sleep time: 20s)
	# or did similar stupid things
	# shellcheck disable=SC2016
	assertTrue "borg backup was in time" \
				"[ $(( endTime-startTime )) -le 15 ]"

	archiveName="$HOSTNAME-unit-test-fake-backup-$( date +"%F" )-UNIQUESTRING-for-test918"
	# and to really verify, look for borg output
	# shellcheck disable=SC2016
	assertTrue "backup shows backup name" \
				'echo "$output"|grep "Archive name: $archiveName"'

	# also list backup content again to check whether archive really contains expected stuff
	# shellcheck disable=SC2034
	archiveContent=$( $TEST_SHELL -c "borg list '/tmp/borg_repodir::$archiveName'" )
	# shellcheck disable=SC2016
	assertTrue "has (correct) content" \
				'echo "$archiveContent"|grep ".git/"'

	# also check that prune executed
	# shellcheck disable=SC2016
	assertTrue "prune executed" \
				'echo "$output"|grep "Keeping archive"'
}

testBorgEncrypted(){
	# first tests that backup fails with wrong password and then that it works with correct pasphrase

	# borg init to create repo
	BORG_PASSPHRASE="123456789" borg init --encryption=repokey "/tmp/borg_repodir" >/dev/null 2>/dev/null

	# altghough encrypted, first let it fail and give it a wrong passphrase
	patchConfigDisableVar "exampleTest.sh" 'BORG_PASSCOMMAND'
	patchConfigSetVar "exampleTest.sh" 'BORG_PASSPHRASE' 'wrongpassword000'

	# shellcheck disable=2016
	patchConfigSetVar "exampleTest.sh" 'ARCHIVE_NAME' '$BACKUP_NAME-{now:%Y-%m-%d}-broken' '"'

	# no prune
	patchConfigDisableVar "exampleTest.sh" 'PRUNE_PARAMS'

	# no retry
	patchConfigSetVar "exampleTest.sh" 'REPEAT_NUM' '0'

	startTime=$( date +%s )
	# shellcheck disable=SC2034
	output=$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath exampleTest.sh )" 2>&1 )
	exitcode=$?
	endTime=$( date +%s )

	# show output
	echo "$output"

	# check whether backup is fails due to missing passphrase
	# TODO: check for correct exit code (borg returns 2 for missing passphrase) instead
	assertEquals "backup finishes without error" \
				"0" \
				"$exitcode"

	# as it fails it can "wait" one time (20s), but not more (2*20=40s)
	# TODO: do not wait in this case, see https://github.com/rugk/borg-cron-helper/issues/29
	# shellcheck disable=SC2016
	assertTrue "borg backup did not retry" \
				"[ $(( endTime-startTime )) -le 35 ]"

	# 2nd try: set passphrase/password

	# shellcheck disable=2016
	patchConfigSetVar "exampleTest.sh" 'ARCHIVE_NAME' '$BACKUP_NAME-{now:%Y-%m-%d}-working' '"'

	# for >= v1.1.0 use BORG_PASSCOMMAND with a file instead, otherwise fallback to BORG_PASSPHRASE
	if version_gt "$BORG" "1.0.99"; then
		echo "123456789" > "$TMPDIR/borg/passphrase.key"
		patchConfigSetVar "exampleTest.sh" 'BORG_PASSCOMMAND' "cat '$TMPDIR/borg/passphrase.key'"
		patchConfigDisableVar "exampleTest.sh" 'BORG_PASSPHRASE'
	else
		patchConfigSetVar "exampleTest.sh" 'BORG_PASSPHRASE' "123456789"
		patchConfigDisableVar "exampleTest.sh" 'BORG_PASSCOMMAND'
	fi

	startTime=$( date +%s )
	# shellcheck disable=SC2034
	output=$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath exampleTest.sh )" $STDERR_TO_STDOUT )
	exitcode=$?
	endTime=$( date +%s )

	# now it should have finished without an error
	assertEquals "backup finishes without error" \
				"0" \
				"$exitcode"

	archivePrefix="unit-test-fake-backup-$( date +"%F" )"
	# also list backup content again to check that only the second backup was successful
	archiveList=$( $TEST_SHELL -c "BORG_PASSPHRASE='123456789' borg list --short '/tmp/borg_repodir'" )
	assertEquals "has (correct) content" \
				"$archivePrefix-working" \
				"$archiveList"
}

testBorgPrune(){
	# test simple prune actions

	# copy old backup repo to location
	cp -r "$BORGREPO_PRESET_OLD/security/." "$BORG_SECURITY_DIR"
	cp -r "$BORGREPO_PRESET_OLD/cache/." "$BORG_CACHE_DIR"
	cp -r "$BORGREPO_PRESET_OLD/repo/." "/tmp/borg_repodir"

	patchConfigDisableVar "exampleTest.sh" 'BORG_PASSCOMMAND'
	patchConfigDisableVar "exampleTest.sh" 'BORG_PASSPHRASE'

	# new backup created when running gets a different prefix
	# shellcheck disable=2016
	patchConfigSetVar "exampleTest.sh" 'ARCHIVE_NAME' 'prefix3_$BACKUP_NAME-manual1-{now:%Y-%m-%dT%H:%M:%S}' '"'

	# enable prune
	patchConfigSetVar "exampleTest.sh" 'PRUNE_PARAMS' "--keep-within=1H" # it won't apply as backups were created a long time ago
	# should delete all prefix2 backups
	patchConfigSetVar "exampleTest.sh" 'PRUNE_PREFIX' "prefix2_"

	# borg 1.1. shows this warning when accessing the old repo, ignore it
	export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes

	startTime=$( date +%s )
	# shellcheck disable=SC2034
	output=$( $TEST_SHELL "$BASE_DIR/borgcron.sh" "$( getConfigFilePath exampleTest.sh )" 2>&1 )
	exitcode=$?
	endTime=$( date +%s )

	# check whether backup is sucessful
	assertEquals "backup finishes without error" \
				"0" \
				"$exitcode"

	# when it took more than 15 seconds, it likely retried the backup (sleep time: 20s)
	# or did similar stupid things
	# shellcheck disable=SC2016
	assertTrue "borg run was in time" \
				"[ $(( endTime-startTime )) -le 15 ]"

	# check that prune deleted prefix2_ and showed that in output
	# shellcheck disable=SC2016
	assertTrue "Prune should delete prefix2." \
				'echo "$output"|grep "Pruning archive: prefix2_"'

	# check that prefix1_ and newly created prefix3_ are still there (not prefixed versions are not shown in prune output)
	# shellcheck disable=SC2034
	archiveList=$( $TEST_SHELL -c "borg list --short '/tmp/borg_repodir'" )
	# shellcheck disable=SC2016
	assertTrue "Prune should keep prefix1." \
				'echo "$archiveList"|grep "^prefix1_"'
	# shellcheck disable=SC2016
	assertTrue "Prune should keep prefix3." \
				'echo "$archiveList"|grep "^prefix3_"'
}

# shellcheck source=../shunit2/shunit2
. "$TEST_DIR/shunit2/shunit2"
