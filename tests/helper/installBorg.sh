#!/usr/bin/env bash
#
# Installs a custom borg version, if needed.
#
#
# LICENSE: MIT license, see LICENSE.md
#
set -ex

# ignore script if borg should not be installed
if [[ "$BORG" = false ]]; then exit 0; fi

# set defaults vars
[[ "$BORG_VARIANT" = "" ]] && BORG_VARIANT="borg-linux32"
[[ "$BORG_SOURCE" = "" ]] && BORG_SOURCE="binary"

# constants
CUSTOM_BINARY_DIR="$PWD/custombin"

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

		# get borg from github
		git clone -b master "https://github.com/borgbackup/borg.git"
		cd borg
		# NOTE: Currently head commits are not signed.
		# Therefore the following command for verification is disabled
		# git verify-commit HEAD

		# install borg + dependencies into virtualenv
		pip install -r requirements.d/development.txt
		pip install -r requirements.d/docs.txt # optional, to build the docs
		# pip install -r requirements.d/fuse.txt # optional, for FUSE support
		pip install -e . # in-place editable mode
		;;
	stable)
		# from the repository, this implies $BORG_SOURCE=distro
		echo "Not supported (by current Travis-CI)…"
		# The container version of Travis-CI does only allow whitelisted packages
		exit 1
		;;
	# usual version number --> download prebuilt binaries from GitHub
	[0-9]*\.[0-9]*\.[0-9]*)
		importgpgkey

		case "$BORG_SOURCE" in
			binary)
				# download prebuilt borg binaries
				wget "https://github.com/borgbackup/borg/releases/download/$BORG/$BORG_VARIANT"
				wget "https://github.com/borgbackup/borg/releases/download/$BORG/$BORG_VARIANT.asc"

				gpg --verify "$BORG_VARIANT.asc"

				# install borg
				mv "$BORG_VARIANT" "$CUSTOM_BINARY_DIR"
				chmod +x "$CUSTOM_BINARY_DIR/$BORG_VARIANT"
				ln -f -s "$CUSTOM_BINARY_DIR/$BORG_VARIANT" "$CUSTOM_BINARY_DIR/borg"

				# remove trash
				rm "$BORG_VARIANT.asc"
				;;
			git)
				echo "Not supported."
				# Why compile yourself, when you have prebuilt stuff?
				exit 2
				;;
			pip)
				pip install "borgbackup==$BORG"
				;;
			*)
				echo "Invalid input…"
				exit 2
				;;
		esac

		;;
	*)
		echo "Invalid value for borg version: $BORG"
		exit 1
		;;
esac
