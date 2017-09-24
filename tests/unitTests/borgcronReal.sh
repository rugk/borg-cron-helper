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
	sed -i "s/^$2=/# $2=/g" "$CONFIG_DIR/$1"

	# run (once) recursive with export
	[ "$3" != "notRecursive" ] && patchConfigDisableVar "$1" "export $2" "notRecursive"
}
patchConfigEnableVar(){
	# syntax: filename.sh variable internalvar
	sed -i "s/^#\h*$2=/$2=/g" "$CONFIG_DIR/$1"

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

	sed -i "s#^$2=['\"].*['|\"]#$2=${quoteChar}${varEscaped}${quoteChar}#g" "$CONFIG_DIR/$1"

	# run (once) recursive with export
	[ "$5" != "notRecursive" ] && patchConfigSetVar "$1" "export $2" "$3" "$4" "notRecursive"
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

	# check whether backup is sucessful
	startTime=$( date +%s )
	assertAndOutput	assertTrue \
					"backup finishes without error" \
					"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath exampleTest.sh )'"
	endTime=$( date +%s )

	# when it took more than 2 minutes, it likely retried the backup (sleep time: 5m)
	# or did similar stupid things
	# shellcheck disable=SC2016
	assertTrue "borg backup was in time" \
				"[ $(( endTime-startTime )) -le 120 ]"

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

# shellcheck source=../shunit2/shunit2
. "$TEST_DIR/shunit2/shunit2"
