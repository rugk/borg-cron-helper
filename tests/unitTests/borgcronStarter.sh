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
# Here the temp dir saves the original config files as backup.
TMPDIR="$( mktemp -d )"

# make sure, original files are backed up…
oneTimeSetUp(){
	echo "shunit2 v$SHUNIT_VERSION"
	echo "Testing borgcron_starter.sh…"
	echo
	mv "$CONFIG_DIR" "$TMPDIR"||exit 1
}
oneTimeTearDown(){
	mv "$TMPDIR/config" "$BASE_DIR"

	# cleanup TMPDIR
	rm -rf "$TMPDIR"
}

# cleanup tests to always have an empty config dir
setUp(){
	# create dir if it does not exist
	mkdir "$CONFIG_DIR" 2> /dev/null

	addFakeBorg
	# simplify fakeborg to always exit with 0
	addFakeBorgCommandOnBeginning 'exit 0'

	# create fake dirs, needed for execution of borgcron.sh
	# (they are later "injected" by the fake config file)
	mkdir "/tmp/LAST_BACKUP_DIR"
	mkdir "/tmp/RUN_PID_DIR"
}
tearDown(){
	removeFakeBorg

	# remove propbably remaining config files
	rm -rf "$CONFIG_DIR" 2> /dev/null

	# remove fake dirs
	rm -rf "/tmp/LAST_BACKUP_DIR"
	rm -rf "/tmp/RUN_PID_DIR"
}

# helpers for tests
addConfigFile(){
	# syntax: filename.sh "[shell commands to inject, overwrite previous ones]"

	# pass to common function
	addConfigFileToDir "$CONFIG_DIR" "$@"
}

# actual unit tests
testRemovedConfigDir(){
	tearDown

	output=$( $TEST_SHELL "$BASE_DIR/borgcron_starter.sh" 2>&1 )
	exitcode=$?

	assertFalse "does not stop on missing config dir; exited with ${exitcode}, output: ${output}" \
				"$exitcode"

	assertContains "does not show correct error message; exited with ${exitcode}, output: ${output}" \
				"$output" "No backup settings file(s) could be found"
}
testEmptyConfigDir(){
	output=$( $TEST_SHELL "$BASE_DIR/borgcron_starter.sh" 2>&1 )
	exitcode=$?

	assertFalse "does not stop on empty config dir; exited with ${exitcode}, output: ${output}" \
				"$exitcode"

	assertContains "stops on empty config dir; exited with ${exitcode}, output: ${output}" \
				"$output"  "No backup settings file(s) could be found"

}
testShowsHelp(){
	addConfigFile "doNotExecute.sh"

	output=$( $TEST_SHELL "$BASE_DIR/borgcron_starter.sh" --help 2>&1 )
	exitcode=$?

	assertContains "does not show help; exited with ${exitcode}, output: ${output}" \
				"$output"  "Usage:"

	# make sure, borgcron.sh did not execute
	assertFalse "it did execute backup something else than just showing the help; exited with ${exitcode}, output: ${output}" \
				"[ -e '$CONFIG_DIR/list' ]"

}
testExecuteSingleConfigExplicit(){
	# do specify config to run explicitly
	addConfigFile "singleConfig.sh"

	output=$( $TEST_SHELL "$BASE_DIR/borgcron_starter.sh" singleConfig 2>&1 )
	exitcode=$?

	assertTrue "failed when executing; exited with ${exitcode}, output: ${output}" \
				"$exitcode"

	assertEquals "did execute backup more or less than one time; exited with ${exitcode}, output: ${output}" \
				"1" \
				"$( cat "$CONFIG_DIR/counter" )"

	assertEquals "did execute incorrect config(s); exited with ${exitcode}, output: ${output}" \
				"singleConfig.sh" \
				"$( cat "$CONFIG_DIR/list" )"
}
testExecuteSingleConfigExplicitSH(){
	# do specify config to run explicitly using *.sh file extension
	addConfigFile "singleConfig.sh"

	output=$( $TEST_SHELL "$BASE_DIR/borgcron_starter.sh" singleConfig.sh 2>&1 )
	exitcode=$?

	assertTrue "failed when executing; exited with ${exitcode}, output: ${output}" \
				"$exitcode"

	assertEquals "did execute backup more or less than one time; exited with ${exitcode}, output: ${output}" \
				"1" \
				"$( cat "$CONFIG_DIR/counter" )"

	assertEquals "did execute incorrect config(s); exited with ${exitcode}, output: ${output}" \
				"singleConfig.sh" \
				"$( cat "$CONFIG_DIR/list" )"
}
testExecuteSingleConfigImplicit(){
	# does not specify file directly
	addConfigFile "singleConfig.sh"

	output=$( $TEST_SHELL "$BASE_DIR/borgcron_starter.sh" 2>&1 )
	exitcode=$?

	assertTrue "failed when executing; exited with ${exitcode}, output: ${output}" \
				"$exitcode"

	assertEquals "did execute more or less than one time; exited with ${exitcode}, output: ${output}" \
				"1" \
				"$( cat "$CONFIG_DIR/counter" )"

	assertEquals "did execute incorrect config(s); exited with ${exitcode}, output: ${output}" \
				"singleConfig.sh" \
				"$( cat "$CONFIG_DIR/list" )"
}

testExecuteMultipleConfigsAll(){
	addConfigFile "0FirstExecuteNumber.sh"
	addConfigFile "DoNotExexuteNoShellFile.jpg"
	addConfigFile "aFirstExecuteLetter.sh"
	addConfigFile "hSecondExecuteLetter.sh"
	addConfigFile "ZLastExecuteUpperLetter.sh"

	output=$( $TEST_SHELL "$BASE_DIR/borgcron_starter.sh" 2>&1 )
	exitcode=$?

	assertTrue "failed when executing; exited with ${exitcode}, output: ${output}" \
				"$exitcode"

	assertEquals "did not only execute the 4 shell scripts, but also the JPG file(?); exited with ${exitcode}, output: ${output}" \
				"4" \
				"$( cat "$CONFIG_DIR/counter" )"

	case "$TEST_SHELL" in
		sh ) # sh in Travis-CI does sort files differently
			assertEquals "executed shell scripts in incorrect order; exited with ${exitcode}, output: ${output}" \
						"0FirstExecuteNumber.sh
ZLastExecuteUpperLetter.sh
aFirstExecuteLetter.sh
hSecondExecuteLetter.sh" \
			"$( cat "$CONFIG_DIR/list" )"
			;;
		* ) # zsh, bash
			assertEquals "executed shell scripts in incorrect order; exited with ${exitcode}, output: ${output}" \
						"0FirstExecuteNumber.sh
aFirstExecuteLetter.sh
hSecondExecuteLetter.sh
ZLastExecuteUpperLetter.sh" \
			"$( cat "$CONFIG_DIR/list" )"
			;;
	esac
}

testExecuteMultipleConfigsPartially(){
	addConfigFile "0_Backup3.sh"
	addConfigFile "DoNotExexuteNoShellFile.jpg" # should still not be executed
	addConfigFile "aFirstExecuteLetter.sh"
	addConfigFile "h_Backup1.sh"
	addConfigFile "Z_Backup2.sh"

	# note this again tests different ways of passing the file names
	output="$( $TEST_SHELL "$BASE_DIR/borgcron_starter.sh" h_Backup1 Z_Backup2.sh DoNotExexuteNoShellFile.jpg 0_Backup3 2>&1 )"
	exitcode=$?

	assertEquals "did not exit with 1, as it should to indicate that a wrong filename has been passed; exited with ${exitcode}, output: ${output}" \
				"1" \
				"$exitcode"

	assertEquals "did not only execute the 3 shell scripts, which where explicitly passed; exited with ${exitcode}, output: ${output}" \
				"3" \
				"$( cat "$CONFIG_DIR/counter" )"

	assertEquals "executed shell scripts in incorrect order; exited with ${exitcode}, output: ${output}" \
				"h_Backup1.sh
Z_Backup2.sh
0_Backup3.sh" \
				"$( cat "$CONFIG_DIR/list" )"
}

testExitcodePropagation(){
	# test that the highest error code from borgcron.sh runs is exited

	addConfigFile "2.sh" "exit 2"
	addConfigFile "1.sh" "exit 1"
	addConfigFile "0.sh" "exit 0"
	# test run
	output="$( $TEST_SHELL "$BASE_DIR/borgcron_starter.sh" 1 2 0 2>&1 )"
	exitcode=$?
	# check exit code
	assertEquals "did not exit with correct exit code 2; exited with ${exitcode}, output: ${output}" \
				"2" \
				"$exitcode"


	addConfigFile "100.sh" "exit 100"
	# test run
	output="$( $TEST_SHELL "$BASE_DIR/borgcron_starter.sh" 100 1 2 2>&1 )"
	exitcode=$?
	# check exit code
	assertEquals "did not exit with correct exit code 100; exited with ${exitcode}, output: ${output}" \
				"100" \
				"$exitcode"

	addConfigFile "202.sh" "exit 202"
	addConfigFile "203.sh" "exit 203"
	addConfigFile "9.sh" "exit 9"
	# test run
	output="$( $TEST_SHELL "$BASE_DIR/borgcron_starter.sh" 2>&1 )"
	exitcode=$?
	# check exit code
	assertEquals "did not exit with correct exit code 203; exited with ${exitcode}, output: ${output}" \
				"203" \
				"$exitcode"
}

# shellcheck source=../shunit2/shunit2
. "$TEST_DIR/shunit2/shunit2"
