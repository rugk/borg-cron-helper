#!/usr/bin/env sh
#
# Runs shellcheck over all .sh files to catch errors.
#
set -e

echo "Shellcheck version:"
shellcheck -V

# run test for each *.sh file and exit on errors
find . -type f -iname "*.sh" -not -path "./tests/shunit2/*" -exec sh -c 'for n in "$@"; do ./tests/testShellcheckExec.sh "$n" || exit 1; done' _ {} +

echo "Finished shellcheck test."
