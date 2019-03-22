#!/bin/sh
# shellcheck disable=SC2034
# config file for the settings of this backup

# basic, required information
BACKUP_NAME='example-backup' # name for this backup, avoid spaces
export BORG_REPO='ssh://user@somewhere.example:22/./dir'
ARCHIVE_NAME="{hostname}-$BACKUP_NAME-{now:%Y-%m-%dT%H:%M:%S}" # or %Y-%m-%d
BACKUP_DIRS="/home /etc /srv /var/log /var/mail /var/lib /var/spool /opt /root /usr/local" # path to be backed up, without spaces

# additional backup options
export BORG_PASSCOMMAND='cat "path/to/example-key"' # command to get passphrase (requires borg v1.1.0 or higher, see examples in wiki)
# export BORG_PASSPHRASE="1234" # or enter the passphrase directly
COMPRESSION="lz4" # lz4 | zlib,6 | lzma,6

# The prefix makes sure only backups from this backup config are pruned. It is
# recommend to leave it as it is. Otherwise comment it out to disable pruning
# or – if you really want to remove the prefix – set it to an empty string.
PRUNE_PREFIX="{hostname}-$BACKUP_NAME-"
PRUNE_PARAMS="--keep-daily=14 --keep-weekly=8 --keep-monthly=6 --keep-yearly=0"
# for web servers (only disaster recovery): --keep-daily=7 --keep-weekly=5 --keep-monthly=2 --keep-yearly=0

# additional settings
ADD_BACKUP_PARAMS="" # additional parameters to pass to borg create
# examples:
# --one-file-system for backing up root file dir
# --exclude '/home/*/.cache' to exclude transient data in the home directory
# Full list at https://borgbackup.readthedocs.io/en/stable/usage/create.html
SLEEP_TIME="5m" # time, the script should wait until re-attempting the backup after a failed try
RETRY_NUM="3" # = retry after a failed backup for n number of times
# RETRY_NUM_PRUNE="1" # = use different number of retries for pruning backups

# GUI settings
GUI_OVERWRITE_ICON="$PWD/icon.png" # custom icon for notifications (needs absolute path)
# You can also overwrite the guiShow…() functions here to modify their behaviour.
# E.g.:
# guiShowBackupBegin() {
#    guiShowNotification "Backup just started."
#}

# You can include the default zenity_proxy, which sends notifications to active users.
# FALLBACK_NOTIFICATION_USER="" # user to show to usually
## shellcheck source=../tools/zenityProxy.sh
# . "$( dirname "$0" )/tools/zenityProxy.sh" # evaluate full path

# For more information, see the wiki: https://github.com/rugk/borg-cron-helper/wiki/Additional-GUI-integration

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
# dnf list installed > "/path/to/backup/dnf.list" 2>/dev/null
# rpm -qa > "/path/to/backup/rpm.list" 2>/dev/null
#
# DEB-based:
# apt list --installed > "/path/to/backup/apt.list" 2>/dev/null
# dpkg --get-selections > "/path/to/backup/dpkg.list" 2>/dev/null
#
# Flatpak:
# ref: https://www.ctrl.blog/entry/backup-flatpak
# repository metadata:
# flatpak remotes --show-details | awk '{print "echo \"echo \\\x22$(base64 --wrap=0 < $HOME/.local/share/flatpak/repo/" $1 ".trustedkeys.gpg)\\\x22 | base64 -d | flatpak remote-add --if-not-exists --gpg-import=- --prio=\\\x22"$4"\\\x22 --title=\\\x22"$2"\\\x22 --user \\\x22"$1"\\\x22 \\\x22"$3"\\\x22\""}' | sh > "/path/to/backup/flatpak-repo-config.sh" 2>/dev/null
# flatpak list --app --show-details | \
# awk '{print "flatpak install --assumeyes --user \""$2"\" \""$1}' | \
# cut -d "/" -f1 | awk '{print $0"\""}' > "/path/to/backup/flatpaks-list.sh" 2>/dev/null
# user-friendly list:
# flatpak list --app > "/path/to/backup/flatpaks-user-friendly.list" 2>/dev/null

# create MySQL dumps
# export SQL_BACKUP_USER="root"
# export SQL_BACKUP_PASSCOMMAND='cat "/root/.mysqlPassword"'
# export SQL_BACKUP_DESTINATION="/root/backup/db"

# backup specified databases, or all if you do not pass any parameter
# ../tools/databasedump.sh "db1 db2 db3"
