#!/usr/bin/env sh
#
# Inner part for find to actually execute the shellcheck test.
#
set -e

echo "Testing $1…"
if shellcheck -x "$1"; then
	echo "Could not find errors in ""$1""…"
else
	exit $?
fi
