#!/usr/bin/env sh
#
# Inner part for find to actually execute the shellcheck test.
#
set -e

# switch to affected directory, so that "shellcheck source" works correctly from
# current dir
cd "$( dirname "$1" )"

displayName="$1"
baseName="$( basename "$1" )"

# test file
echo "Testing $displayName…"
if shellcheck -x "$baseName"; then
	echo "Could not find errors in ""$displayName""…"
else
	exit $?
fi
