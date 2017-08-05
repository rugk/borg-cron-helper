#!/bin/sh
# Cron script to calculate the size of all dirs/files in a dir and save it to a file in order to cache it or log it.
#
# LICENSE: CC0/Public Domain - To the extent possible under law, rugk has waived all copyright and related or neighboring rights to this work. This work is published from: Deutschland.
#

# constants
DIR='/path/to/dir'
DU_PARAMS='-shc'
CURRENT_FILE='/var/log/…/latest.stats'
LOG_FILE='/var/log/'

# log and save size of backup
du $DU_PARAMS $DIR/*|tee "$CURRENT_FILE" >> "$LOG_FILE"

# one-liner: du -shc /path/to/dir/*|tee /var/log/…/latest.stats >> /var/log/…/stats.log
# one-liner (only current): du -shc /path/to/dir/* > /var/log/…/latest.stats
