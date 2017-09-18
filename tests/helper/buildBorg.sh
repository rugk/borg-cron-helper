#!/usr/bin/env bash
#
# Installs a custom borg version, if needed.
#
set -ex

# ignore script if borg should not be installed
if [[ "$BORG" = false ]]; then exit 0; fi

# set defaults vars
[[ "$BORG" = false ]] || BORG_VARIANT="borg-linux32"

# constants
CUSTOM_BINARY_DIR="$PWD/custombin/"

if [[ -z "$BORG" ]]; then
	echo "No borg version given."
	exit 1
fi

function importgpgkey() {
	gpg --import "$CURRDIR/borgkey.asc"
	echo "6D5BEF9ADD2075805747B70F9F88FB52FAF7B393:6:"|gpg --import-ownertrust
}

CURRDIR=$( dirname "$0" )

case "$BORG" in
	nightly)
		importgpgkey

		echo "Not yet supported…" #TODO
		exit 1
		;;
	stable)
		# nothing to do, stable borgbackup should be installed by Travis
		;;
	# usual version number --> download prebuilt binaries from GitHub
	[0-9]*\.[0-9]*\.[0-9]*)
		importgpgkey

		wget "https://github.com/borgbackup/borg/releases/download/$BORG/$BORG_VARIANT"
		wget "https://github.com/borgbackup/borg/releases/download/$BORG/$BORG_VARIANT.asc"

		gpg --verify "$BORG_VARIANT.asc"

		echo "Installing borg…"
		ls -la
		mv "$BORG_VARIANT" "$PWD/$CUSTOM_BINARY_DIR"
		chmod +x "$PWD/$CUSTOM_BINARY_DIR/$BORG_VARIANT"
		;;
	*)
		echo "Invalid value for borg version: $BORG"
		exit 1
		;;
esac
