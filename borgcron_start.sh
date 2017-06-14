#!/bin/sh
# header file to init a backup process with some options configured

BACKUP_NAME='good-backup'
BASE_DIR='/home/borg-backup'
REPOSITORY='ssh://user@somewhere.example:22/./dir'

# create installed list
#apt list --installed > "$BASE_DIR/backup/aptinstalled.list" 2>/dev/null

PASSPHRASE_FILE="$BASE_DIR/good-key"
BACKUP_DIRS="$BASE_DIR/good"
ARCHIVE_NAME="{hostname}-$BACKUP_NAME-{now:%Y-%m-%d}" # or %Y-%m-%dT%H:%M:%S
COMPRESSION="lz4" # lz4 | zlib,6 | lzma,9
ADD_BACKUP_PARAMS="" # --one-file-system for backing up root file dir

PRUNE_PARAMS="--keep-daily=14 --keep-weekly=8 --keep-monthly=6 --keep-yearly=0"
# for web servers (only disaster recovery:) --keep-daily=7 --keep-weekly=4 --keep-monthly=1 --keep-yearly=0

# include main script
# shellcheck disable=SC1091
. ./borgcron.sh
