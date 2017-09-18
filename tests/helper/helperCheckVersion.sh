#!/usr/bin/env sh
set -ex

usedShell=$( ps -p$$ -ocmd= )

echo "Used shell: $usedShell"
$usedShell --version
$usedShell -v
$usedShell -V
$usedShell -?

echo "Installed Python3: $( python3 --version )"

# exit if borg is not installed
if [ "$BORG" = false ]; then exit 0; fi

echo "Installed borg version: $( borg -V )"
