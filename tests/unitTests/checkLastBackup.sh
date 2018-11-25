#!/usr/bin/env sh
#
# Tests checklastbackup.sh.
# Required envorimental variables:
# * $TEST_SHELL
#
# LICENSE: MIT license, see LICENSE.md
#

CURRDIR=$( dirname "$0" )
# shellcheck source=./common.sh
. "$CURRDIR/common.sh"

# constants
TMPDIR="$( mktemp -d )"
LASTSCRIPT="$BASE_DIR/tools/checklastbackup.sh"
LAST_BACKUP_DIR="$TMPDIR/last"

oneTimeSetUp(){
	echo "shunit2 v$SHUNIT_VERSION"
	echo "Testing checklastbackup.sh…"
	echo
}

# cleanup tests to always have an empty temp dirs
setUp(){
	mkdir -p "$LAST_BACKUP_DIR"

	# backup real file
	cp "$LASTSCRIPT" "$TMPDIR/originalscript.sh"||exit 1

	# adjust basics

	# fake last backup dir
	sed -i "s#^LAST_BACKUP_DIR=['\"].*['|\"]#LAST_BACKUP_DIR='$LAST_BACKUP_DIR'#g" "$LASTSCRIPT"
	# never wait for user, as we have none (could be changed to fake input, however)
	sed -i "s#wait=1#wait=0#g" "$LASTSCRIPT"
}
tearDown(){
	rm -rf "$LAST_BACKUP_DIR"

	# restore real file
	mv -f "$TMPDIR/originalscript.sh" "$LASTSCRIPT"
}

# actual unit tests
testRemovedLastDir(){
	rm -rf "$LAST_BACKUP_DIR"

	output="$( $TEST_SHELL "$LASTSCRIPT" 2>&1 )"
	exitcode=$?

	assertEquals "does not stop on missing last dir; exited with ${exitcode}, output: ${output}" \
				"ERROR: No borg backup 'last' dir…" \
				"$output"
}
testEmptyLastDir(){
	output="$( $TEST_SHELL "$LASTSCRIPT" 2>&1 )"
	exitcode=$?

	assertEquals "does not stop on empty last dir; exited with ${exitcode}, output: ${output}" \
				"ERROR: No borg backup 'last' dir…" \
				"$output"
}
testIgnoresUpToDateBackups(){
	date --date="-23 hours" +'%s' > "$LAST_BACKUP_DIR/backup-ok-23h.time"
	date --date="-10 hours" +'%s' > "$LAST_BACKUP_DIR/backup-ok-10h.time"
	date --date="now" +'%s' > "$LAST_BACKUP_DIR/backup-ok-now.time"
	# also check future time stamps, which might happen with wrong clocks, etc.
	date --date="+1 hour" +'%s' > "$LAST_BACKUP_DIR/backup-ok-+1h.time"

	output="$( $TEST_SHELL "$LASTSCRIPT" 2>&1 )"
	exitcode=$?

	assertEquals "does not silently ignores up-to-date backups; exited with ${exitcode}, output: ${output}" \
				"" \
				"$output"
}
testShowBackupInfo(){
	date --date="-26 hours" +'%s' > "$LAST_BACKUP_DIR/backup-bad-26h.time"
	date --date="-32 hours" +'%s' > "$LAST_BACKUP_DIR/backup-bad-32h.time"
	# up-to-date backup should not be shown
	date --date="-2 hours" +'%s' > "$LAST_BACKUP_DIR/backup-bad-2h.time"
	date --date="-3 days" +'%s' > "$LAST_BACKUP_DIR/backup-bad-3d.time"

	# run it!
	output="$( $TEST_SHELL "$LASTSCRIPT" 2>&1 )"
	exitcode=$?

	# shellcheck disable=2034
	message='The borg backup named "backup-bad-26h" is outdated.'
	assertContains "does not show correct backup info; exited with ${exitcode}, output: ${output}" \
					"$output" "$message"

	# shellcheck disable=2034
	message='The borg backup named "backup-bad-32h" is outdated.'
	assertContains "does not show correct backup info; exited with ${exitcode}, output: ${output}" \
					"$output" "$message"

	# shellcheck disable=2034
	message='The borg backup named "backup-bad-2h" is outdated.'
	assertNotContains "does not show correct backup info; exited with ${exitcode}, output: ${output}" \
						"$output" "$message"


	# shellcheck disable=2034
	message='The borg backup named "backup-bad-3d" is outdated.'
	assertContains "does not show correct backup info; exited with ${exitcode}, output: ${output}" \
				"$output" "$message"

}

# shellcheck source=../shunit2/shunit2
. "$TEST_DIR/shunit2/shunit2"
