#!/usr/bin/env sh
#
# Executes final unit tests using the real borg binary.
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
TMPDIR="$( mktemp -d )"

# make sure, original files are backed up…
oneTimeSetUp(){
	echo "shunit2 v$SHUNIT_VERSION"
	echo "Testing with real borg…"
	echo
	mv "$CONFIG_DIR" "$TMPDIR"

	# set variables, so when borg is called here, it also uss the correct dirs
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
	patchConfigSetVar "exampleTest.sh" 'BORG_REPO' "/tmp/borg_repodir/"
	patchConfigSetVar "exampleTest.sh" 'BACKUP_DIRS' "$BASE_DIR/.git $TEST_DIR/shunit2/.git"

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

escapeStringForSed(){
	# thanks https://stackoverflow.com/questions/407523/escape-a-string-for-a-sed-replace-pattern#answer-2705678
	echo "$1"|sed -e 's/[]\#$*.^|[]/\\&/g'
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
	borg init --encryption=none '/tmp/borg_repodir/'

	patchConfigDisableVar "exampleTest.sh" 'BORG_PASSCOMMAND'
	patchConfigDisableVar "exampleTest.sh" 'BORG_PASSPHRASE'

	# set unique name
	# shellcheck disable=2016
	patchConfigSetVar "exampleTest.sh" 'ARCHIVE_NAME' '{hostname}-$BACKUP_NAME-{now:%Y-%m-%d}-UNIQUESTRING-for-test918' '"'

	# also test prune
	patchConfigEnableVar "exampleTest.sh" 'PRUNE_PARAMS'

	# check whether backup is sucessful
	assertAndOutput	assertTrue \
					"backup finishes without error" \
					"$TEST_SHELL '$BASE_DIR/borgcron.sh' '$( getConfigFilePath exampleTest.sh )'"

	# and to really verify, look for borg output
	# shellcheck disable=SC2016
	assertTrue "backup shows backup name" \
			   'echo "$output"|grep "Archive name: $HOSTNAME-unit-test-fake-backup-$( date +"%F" )-UNIQUESTRING-for-test918"'

	# also check that prune executed
	# shellcheck disable=SC2016
	assertTrue "prune executed" \
			   'echo "$output"|grep "Keeping archive"'
}

# shellcheck source=../shunit2/source/2.1/src/shunit2
. "$TEST_DIR/shunit2/source/2.1/src/shunit2"
