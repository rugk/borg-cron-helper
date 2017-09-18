#!/usr/bin/env sh
set -ex

echo "Installed shell: $SHELL"
$SHELL --version

echo "Installed Python3: $( python3 --version )"

# exit if borg is not installed
if [ "$BORG" = false ]; then exit 0; fi

echo "Installed borg version: $( borg -V )"
