#!/bin/sh
# shellcheck disable=SC2034
# config file for the settings of this backup

# (Shellcheck cannot know that this file is sourced and variables will be used later.
#  That's why we disable this check.)

# basic, required information
BACKUP_NAME='example-backup' # name for this backup, avoid spaces
export BORG_REPO='ssh://user@somewhere.example:22/./dir'
ARCHIVE_NAME="{hostname}-$BACKUP_NAME-{now:%Y-%m-%dT%H:%M:%S}" # or %Y-%m-%d
BACKUP_DIRS="/home /etc /srv /var/log /var/mail /var/lib /var/spool /opt /root /usr/local" # path to be backed up, without spaces

# additional backup options
export BORG_PASSCOMMAND='cat "path/to/example-key"' # command to get passphrase (requires borg v1.1.0 or higher, see examples in wiki)
# export BORG_PASSPHRASE="1234" # or enter the passphrase directly
COMPRESSION="lz4" # lz4 | zlib,6 | lzma,9

PRUNE_PREFIX="{hostname}-$BACKUP_NAME-"
PRUNE_PARAMS="--keep-daily=14 --keep-weekly=8 --keep-monthly=6 --keep-yearly=0"
# for web servers (only disaster recovery): --keep-daily=7 --keep-weekly=5 --keep-monthly=2 --keep-yearly=0

# additional settings
ADD_BACKUP_PARAMS="" # --one-file-system for backing up root file dir
SLEEP_TIME="5m" # time, the script should wait until re-attempting the backup after a failed try
REPEAT_NUM="3" # = three retries after accepting a failed backup

# GUI settings
GUI_OVERWRITE_ICON="$PWD/tools/icon.png" # custom icon for notifications (needs absolute path)
# You can also overwrite the guiShow…() functions here to modify their behaviour.
# E.g. show a scary prompt if the backup fails:

# guiShowBackupError() {
# 	zenity --error --text "<b>The backup process failed.</b> See the log for more details.
#
# <small><tt>$( cat path/to/log.log )</tt></small>" \
# 		--title "BorgBackup \"$BACKUP_NAME\"" --window-icon "$GUI_OVERWRITE_ICON" \
# 		--name borg-cron-helper --class borg-cron-helper 2> /dev/null
# }

# Or interactively ask for retrying the backup. (REPEAT_NUM is a maxium number fo retries, then)

# guiTryAgain() {
# 	zenity --question --text "<b>The backup failed.</b> ($i. try) Do you want to try it again?" \
# 		--height=10 --title "BorgBackup \"$BACKUP_NAME\"" --window-icon "$GUI_OVERWRITE_ICON" \
# 		--name borg-cron-helper --class borg-cron-helper 2> /dev/null
# }

# of course, also a CLI version is possible:

# guiTryAgain() {
# 	read -rp "The backup failed. ($i. try) Do you want to try it again? [yN]: " retry
# 	if [ "$retry" = "Y" ] || [ "$retry" = "y" ]; then
# 		return 0 # (true)
# 	fi
# 	return 1 # (false)
# }

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
