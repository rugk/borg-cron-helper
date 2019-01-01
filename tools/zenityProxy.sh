#!/bin/sh
#
# Sets up the zenity proxy function, so the backup script can send notifications
# to other users through zenity. It always tries to send a notification to
# To use it, your backup script needs to have permissions to run sudo or su
# (i.e. be root or get added to /etc/sudoers.)
# You can set $FALLBACK_NOTIFICATION_USER to a fallback username to use in
# case of an error.
#

# Return info of the currently active user.
#
# Source: https://unix.stackexchange.com/a/394763/146739
#
# args: None
getActiveUserData() {
	for sessionid in $(loginctl list-sessions --no-legend | awk '{ print $1 }'); do
		loginctl show-session -p Id -p Name -p User -p State -p Type -p Remote "$sessionid" | sort
	done
};

# Return the user name of the currently active user.
#
# Source: https://unix.stackexchange.com/a/394763/146739
#
# args: None
getActiveUsername() {
	getActiveUserData | awk -F= '/Name/ { name = $2 } /User/ { user = $2 } /State/ { state = $2 } /Type/ { type = $2 } /Remote/ { remote = $2 } /User/ && remote == "no" && state == "active" && (type == "x11" || type == "wayland") { print name }'
};

# Return user ID of the currently active user.
#
# Source: https://unix.stackexchange.com/a/394763/146739
#
# args: None
getActiveUserId() {
	getActiveUserData | awk -F= '/Name/ { name = $2 } /User/ { user = $2 } /State/ { state = $2 } /Type/ { type = $2 } /Remote/ { remote = $2 } /User/ && remote == "no" && state == "active" && (type == "x11" || type == "wayland") { print user }'
};

# overwrite actual
zenityProxy() {
    if [ -z "$1" ]; then # let script verify this proxy is there
        return 0 # (true)
    fi

	# get active user
	ACTIVE_USERNAME="$( getActiveUsername )"
	ACTIVE_USERID="$( getActiveUserId )"

	if [ -z "$ACTIVE_USERNAME" ]; then
		error_log "Could not find active user to find zenity (notifications) to. Cancel notification sending."
	fi
	if [ -n "$FALLBACK_NOTIFICATION_USER" ] &&
		[ "$ACTIVE_USERNAME" = "gdm" ]; then
		ACTIVE_USERNAME="$FALLBACK_NOTIFICATION_USER"
		ACTIVE_USERID=1000 # need to hardcode/guess user ID
	fi

	# fallback to ID 1000, if needed
	if [ ! "$ACTIVE_USERID" -ge 0 ]; then
		ACTIVE_USERID=1000
	fi

	info_log "Showing zenity (notification) to $ACTIVE_USERNAME (id=$ACTIVE_USERID)."

	# create DBUS_SESSION_BUS_ADDRESS
	DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTIVE_USERID/bus"
	export DBUS_SESSION_BUS_ADDRESS

    # execute command for active user
	if command -v sudo; then
		# pass through $DBUS_SESSION_BUS_ADDRESS environment variable

		sudo -u "$ACTIVE_USERNAME" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" -- sh -c "zenity $*"
	else
		su "$ACTIVE_USERNAME" -c "zenity $*"
	fi
}
