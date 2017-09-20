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
TMPDIR="$( mktemp -d )"

# make sure, original files are backed up…
oneTimeSetUp(){
	echo "shunit2 v$SHUNIT_VERSION"
	echo "Testing borgcron_starter.sh…"
	echo
	mv "$CONFIG_DIR" "$TMPDIR"
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
	assertTrue "stops on missing config dir" \
			   "$TEST_SHELL '$BASE_DIR/borgcron_starter.sh'|grep 'No backup settings file(s) could be found'"
}
testEmptyConfigDir(){
	assertTrue "stops on empty config dir" \
			   "$TEST_SHELL '$BASE_DIR/borgcron_starter.sh'|grep 'No backup settings file(s) could be found'"
}
testShowsHelp(){
	addConfigFile "doNotExecute.sh"

	assertTrue "shows help" \
			   "$TEST_SHELL '$BASE_DIR/borgcron_starter.sh' --help|grep 'Usage:'"

	# make sure, borgcron.sh did not execute
	assertFalse "when showing help, do not execute anything else" \
			   "[ -e '$CONFIG_DIR/list' ]"

}
testExecuteSingleConfigExplicit(){
	# do specify config to run explicitly
	addConfigFile "singleConfig.sh"

	assertTrue "no error when executing" \
			   "$TEST_SHELL '$BASE_DIR/borgcron_starter.sh' singleConfig"

   assertEquals "executes only one time" \
				"1" \
				"$( cat "$CONFIG_DIR/counter" )"

	assertEquals "executes correct one config" \
				 "singleConfig.sh" \
				 "$( cat "$CONFIG_DIR/list" )"
}
testExecuteSingleConfigExplicitSH(){
	# do specify config to run explicitly using *.sh file extension
	addConfigFile "singleConfig.sh"

	assertTrue "no error when executing" \
			   "$TEST_SHELL '$BASE_DIR/borgcron_starter.sh' singleConfig.sh"

	assertEquals "executes only one time" \
				 "1" \
				 "$( cat "$CONFIG_DIR/counter" )"

	assertEquals "executes correct one config" \
				 "singleConfig.sh" \
				 "$( cat "$CONFIG_DIR/list" )"
}
testExecuteSingleConfigImplicit(){
	# does not specify file directly
	addConfigFile "singleConfig.sh"

	assertTrue "no error when executing" \
			   "$TEST_SHELL '$BASE_DIR/borgcron_starter.sh'"

	assertEquals "executes only one time" \
				 "1" \
				 "$( cat "$CONFIG_DIR/counter" )"

	assertEquals "executes correct one config" \
				 "singleConfig.sh" \
				 "$( cat "$CONFIG_DIR/list" )"
}

testExecuteMultipleConfigsAll(){
	addConfigFile "0FirstExecuteNumber.sh"
	addConfigFile "DoNotExexuteNoShellFile.jpg"
	addConfigFile "aFirstExecuteLetter.sh"
	addConfigFile "hSecondExecuteLetter.sh"
	addConfigFile "ZLastExecuteUpperLetter.sh"

	assertTrue "no error when executing" \
			   "$TEST_SHELL '$BASE_DIR/borgcron_starter.sh'"

	assertEquals "executes 3 scripts, only shell scripts" \
				 "4" \
				 "$( cat "$CONFIG_DIR/counter" )"

	case "$TEST_SHELL" in
		sh ) # sh in Travis-CI does sort files differently
			assertEquals "executes shell scripts in correct order" \
				 		"0FirstExecuteNumber.sh
ZLastExecuteUpperLetter.sh
aFirstExecuteLetter.sh
hSecondExecuteLetter.sh" \
			"$( cat "$CONFIG_DIR/list" )"
			;;
		* ) # zsh, bash
			assertEquals "executes shell scripts in correct order" \
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
	assertTrue "no error when executing" \
			   "$TEST_SHELL '$BASE_DIR/borgcron_starter.sh' h_Backup1 Z_Backup2.sh DoNotExexuteNoShellFile.jpg 0_Backup3"

	assertEquals "executes 3 scripts, only shell scripts" \
				 "3" \
				 "$( cat "$CONFIG_DIR/counter" )"

	assertEquals "executes shell scripts in correct order" \
				 "h_Backup1.sh
Z_Backup2.sh
0_Backup3.sh" \
				 "$( cat "$CONFIG_DIR/list" )"
}

# shellcheck source=../shunit2/source/2.1/src/shunit2
. "$TEST_DIR/shunit2/source/2.1/src/shunit2"
