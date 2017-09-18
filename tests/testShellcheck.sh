#!/usr/bin/env sh
#
# Runs shellcheck over all .sh files to catch errors.
#
set -e

echo "Shellcheck version:"
shellcheck -V

# run test for each *.sh file
find . -type f -iname "*.sh" -exec sh ./tests/testShellcheckExec.sh "{}" \;
# TODO: errors are currently ignored as find does not pass the exit code to this script.

echo "Finished shellcheck test."
