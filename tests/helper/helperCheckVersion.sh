#!/usr/bin/env sh
set -ex

echo "Used shell: $TEST_SHELL"
# print version, if possible
case "$TEST_SHELL" in
	zsh|bash)
		$TEST_SHELL --version
		;;
esac

echo "Installed Python3: $( python3 --version )"

ls -la
ls -la tests/

# exit if borg is not installed
if [ "$BORG" = false ]; then exit 0; fi

echo "Installed borg version: $( borg -V )"
which borg
