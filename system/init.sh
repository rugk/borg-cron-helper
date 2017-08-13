#!/bin/sh

### BEGIN INIT INFO
# Provides:          borg-dir
# Required-Start:    $local_fs
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Creates the runtime dir at startup for the local lock system.
### END INIT INFO

# settings for directory
RUN_PID_DIR="/var/run/borg"
PERMISSIONS="0755"
USER="backupuser"
GROUP="backupuser"

case "$1" in
	start)
		if [ ! -d "$RUN_PID_DIR" ]; then
			mkdir -p "$RUN_PID_DIR"
			chown "$USER":"$GROUP" "$RUN_PID_DIR"
			chmod "$PERMISSIONS" "$RUN_PID_DIR"
		fi
	;;

	stop)
		[ -d "$RUN_PID_DIR" ] && rm -rf "$RUN_PID_DIR"
	;;

	*)
		echo "Usage: $N {start|stop}" >&2
		exit 1
	;;
esac

exit 0
