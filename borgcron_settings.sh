#!/bin/sh
# Configure the options for borgcron

BACKUP_NAME='good-backup'
BASE_DIR='/home/borg-backup'
REPOSITORY='ssh://user@somewhere.example:22/./dir'
PASSPHRASE_FILE="$BASE_DIR/good-key" #specify the passphrase, if your repo is encrypted

# create installed list
#
# RPM-based:
# dnf list installed > "$BASE_DIR/backup/dnf.list" 2>/dev/null
# rpm -qa > "$BASE_DIR/backup/rpm.list" 2>/dev/null
#
# DEB-based:
# apt list --installed > "$BASE_DIR/backup/apt.list" 2>/dev/null
# dpkg --get-selections > "$BASE_DIR/backup/dpkg.list" 2>/dev/null


BACKUP_DIRS="/home /etc /srv /var/log /var/mail /var/lib /var/spool /opt /root /usr/local"
ARCHIVE_NAME="{hostname}-$BACKUP_NAME-{now:%Y-%m-%d}" # or %Y-%m-%dT%H:%M:%S
COMPRESSION="lz4" # lz4 | zlib,6 | lzma,9
ADD_BACKUP_PARAMS="" # --one-file-system for backing up root file dir

PRUNE_PARAMS="--keep-daily=14 --keep-weekly=8 --keep-monthly=6 --keep-yearly=0"
# for web servers (only disaster recovery:) --keep-daily=7 --keep-weekly=4 --keep-monthly=1 --keep-yearly=0

# shellcheck disable=SC1091
