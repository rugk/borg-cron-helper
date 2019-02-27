#!/bin/sh
# Can be used to "open" and "close" a repository on a server as quickly as possible
# after the client modified the repository.
#
# Usage: appendOnlyController.sh <open|close> [--force] repo1 [repo2] […]
#
BACKUP_OPEN_STATUS="/var/log/borg/open"
MAXIMUM_CLOSE_TIME=$(( 3*24*60*60 )) # 3 days

track_exitcode() {
	if [ "$1" -gt "$exitcode" ]; then
		exitcode="$1"
	fi
}
exitcode=0
# log system
log_line() {
	echo "[$( date +'%F %T' )]"
}
info_log() {
	echo "$( log_line ) $*" >&1
}
error_log() {
	echo "$( log_line ) $*" >&2
}

# repoGetCurrentTransactionNumber repoPath
repoGetCurrentTransactionNumber() {
	stat "$1"/integrity.* --format=%n | sed -e 's/.*[^0-9]\([0-9]\+\)[^0-9]*$/\1/'
}

# repoGetOpeningDate repoName
# returns: opening date in UNIX time in seconds
repoIsOpened() {
	[ -f "$BACKUP_OPEN_STATUS/$1.stat" ]
}

# repoGetOpeningDate repoName
# returns: opening date in UNIX time in seconds
repoGetOpeningDate() {
	file="$BACKUP_OPEN_STATUS/$1.stat"
	stat "$file" --format=%X # in seconds
}

# repoIsOverCloseTime repoName
#
# Checks if the repository has been opened such a long time ago, so that it is
# over MAXIMUM_CLOSE_TIME.
#
# returns: boolean
repoIsOverCloseTime() {
	openTime=$( repoGetOpeningDate "$1" ) # in seconds
	relvTime=$(( $(date +%s) - openTime ))

	[ "$relvTime" -ge "$MAXIMUM_CLOSE_TIME" ]
}

# repoSaveModificationStatus repoPath repoName
repoSaveModificationStatus() {
	repoGetModificationStatus "$1" > "$BACKUP_OPEN_STATUS/$2.stat"
}
# repoIsModified repoPath repoName
repoIsModified() {
	[ "$( cat "$BACKUP_OPEN_STATUS/$2.stat" )" = "$( repoGetModificationStatus "$1" )" ]
}

case "$1" in
	open ) # open repository to allow client modifications
		shift

		# iterate all other params
		while [ -n "$1" ]; do
			repoPath="$1"
			repoName=$( basename "$repoPath" )

			if repoIsOpened "$repoName"; then
				openingDate="$( repoGetOpeningDate "$repoName" )"
				error_log "Repository ${repoName} has already been opened at $( date --date=@"$openingDate" +'%A, %F %T' )."
				track_exitcode 2

				shift
				continue
			fi

			# actually open repo
			borg config "$repoPath" append_only 0
			exitcodeOpen=$?
			track_exitcode $exitcodeOpen

			if [ $exitcodeOpen -eq 0 ]; then
				repoSaveModificationStatus "$repoPath" "$repoName"

				# log success
				info_log "Repo ${repoName} has been opened."
			fi

			shift
		done
	;;
	close ) # close repository to prevent client modifications
		shift

		# ignore checks if command is forced
		if [ "$1" != "--force" ]; then
			isForced=0 # true
		else
			isForced=1 # false
			# remove --force param
			shift
		fi

		# iterate all other params
		while [ -n "$1" ]; do
			repoPath="$1"
			repoName=$( basename "$repoPath" )

			if ! $isForced; then
				if ! repoIsModified "$repoPath" "$repoName"; then
					if ! repoIsOverCloseTime "$repoName"; then
						# everything is okay, we can retry closing it later
						shift
						continue
					fi

					# kind of "timeout"
					error_log "Repository has not been modified in the maximal interval it was opened."
					error_log "It will now be force-closed."
					error_log "Please notify the owner of the repository that they have not purged or otherwise accessed their backup in the time the repository was open (append_only was disabled)."
					track_exitcode 1
				fi
			fi

			openingDate="$( repoGetOpeningDate "$repoName" )"
			closingDate="$( date +%s )"

			info_log "Repo opened at: $( date --date=@"$openingDate" +'%A, %F %T' )"

			# actually close repo
			borg config "$repoPath" append_only 1
			exitcodeClose=$?
			track_exitcode $exitcodeClose

			if [ $exitcodeClose -eq 0 ]; then
				info_log "Repo closed at: $( date --date=@"$closingDate" +'%A, %F %T' )"
			fi

			shift
		done
	;;
	--help|-h|-? ) # show help message
		echo "Usage:"
		echo "$( basename "$0" ) <open|close> [--force] repo1 [repo2] […]"
		echo "$( basename "$0" ) <--help|-h|-?>"
		echo
		echo "<open|close>	– whether to open or close the repo(s)"
		echo "--force	– if you are closing the repo(s) you can pass this to ignore"
		echo "			any checks whether the client accessed the repo and just"
		echo "			close the repo instantly."
		echo "repo1 [repo2] […]		– paths to the repos you want to change"
		echo "<--help|-h|-?>		– shows this help"
		exit
		;;
esac

exit $exitcode
