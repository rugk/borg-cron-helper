#!/bin/sh
# config file for the settings of this backup

# basic, required information
BACKUP_NAME='example-backup' # name for this backup, avoid spaces
export BORG_REPO='ssh://user@somewhere.example:22/./dir'
ARCHIVE_NAME="{hostname}-$BACKUP_NAME-{now:%Y-%m-%dT%H:%M:%S}" # or %Y-%m-%d
BACKUP_DIRS="/home /etc /srv /var/log /var/mail /var/lib /var/spool /opt /root /usr/local" # path to be backed up, without spaces

# additional backup options
export BORG_PASSCOMMAND='cat "path/to/example-key"' # command to get passphrase (requires borg v1.1.0 or higher)
# export BORG_PASSPHRASE="1234" # or enter the passphrase directly
COMPRESSION="lz4" # lz4 | zlib,6 | lzma,9

PRUNE_PARAMS="--keep-daily=14 --keep-weekly=8 --keep-monthly=6 --keep-yearly=0"
# for web servers (only disaster recovery): --keep-daily=7 --keep-weekly=4 --keep-monthly=1 --keep-yearly=0

# additional settings
ADD_BACKUP_PARAMS="" # --one-file-system for backing up root file dir
SLEEP_TIME="5m" # time, the script should wait until re-attempting the backup after a failed try
REPEAT_NUM="3" # = three retries after accepting a failed backup

# borg-internal settings
# (see https://borgbackup.readthedocs.io/en/stable/usage.html#environment-variables)
# export BORG_RSH="ssh -i /path/to/private.key"
# export BORG_REMOTE_PATH="/path/to/special/borg"

# export TMPDIR="/tmp"
# export BORG_KEYS_DIR="~/.config/borg/keys"
# export BORG_SECURITY_DIR="~/.config/borg/security"
# export BORG_CACHE_DIR="~/.cache/borg"

# create list of installed packages
#
# RPM-based:
# dnf list installed > "$BASE_DIR/backup/dnf.list" 2>/dev/null
# rpm -qa > "$BASE_DIR/backup/rpm.list" 2>/dev/null
#
# DEB-based:
# apt list --installed > "$BASE_DIR/backup/apt.list" 2>/dev/null
# dpkg --get-selections > "$BASE_DIR/backup/dpkg.list" 2>/dev/null
