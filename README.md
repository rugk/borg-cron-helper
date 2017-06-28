# Borg cron helper scripts with local lock system

**Automate backups with borg in a more convenient and reliable way!**

This scripts are some small and handy shell scripts (POSIX-compatible, so they should run with all shells) to automate the backup process with [BorgBackup](https://borgbackup.readthedocs.io/). Take them and modify them for your needs!

They add some convienent features around borg.

## Local lock
The local lock system cirumvents the issue of [stale](https://github.com/borgbackup/borg/issues/813) [lock files](https://github.com/borgbackup/borg/issues/2306). When the backup process is interrupted it can happen that the remote borg repository is still locked and any later tries to (re)start (another) backup will fail.
Obviously this is bad for an automated system and it should deal with these issues themselve. Especially when we talk about backup software.

This issue [has been addressed](https://github.com/borgbackup/borg/pull/1674) in borg **v1.1.0** (currently beta), but I have not tested it and until it works there this here is my workaround.

Basically the local lock system writes it's PID into a `/var/run` dir (configurable in `RUN_PID_DIR` in [`borgcron.sh`](borgcron.sh#L11)) and asd long as the PID is there, the backup is considered to be "locked". When the backup process ends (even when it ends with an error), this lock is removed, so that further backups can start. As the whole thing is done locally, this is considered to be more reliable than the "remote lock" system currently implemented in stable versions of borg.
**For the system to work, the `RUN_PID_DIR` must exist and be writable by the user executing the script.** So please create it before executing the script and adjust the permissions.

**Attention:** As the name implies, this system assumes a "single-user" (one client, one server) mode of the borg repository. As the locking is managed locally, it should be satisfied that **only one client** can access respectively accesses the borg repository. Otherwise **data loss may occur**, as this script automatically breaks the remote lock in the borg repository, if it is not locked locally.

## Less maintenance, more safety!

Sometimes [backups stop mid-way](https://borgbackup.readthedocs.io/en/stable/faq.html#if-a-backup-stops-mid-way-does-the-already-backed-up-data-stay-there). This can have different reasons such as an unreliable network connection or a server restart. In any case it is not always avoidable and you do not want to see your backup having failed three days in a row, when you suddenly need it.

That's why the script integrates an **retry mechanism** to retry the backups in case of a failure for up to three times (by default). It also waits a certain amount of time in between, in case the issue needs some minutes to go away. (in case of a server restart e.g.)

Additionally the script has the ability to write stats of the last executed backup and there is another script to check the size of backups stored on the backup server. Both can be used (in conjunction with a script to check the last backup time) to **monitor your backups** and be automatically notified when a backup failed and
something does not work.

**Rest assured your backups are safe and recover themselve if possible.** (If they don't, you'll get to know that.)

## Modularity for multiple backups

The main "work" is done by [`borgcron.sh`](borgcron.sh).
However, for easier configuration and in order to setup multiple backup cron processes, the "configuration" and other backup/repository-specific stuff is done in the header file [`borgcron_start.sh`](borgcron_start.sh), which you can copy and rename as you want. It is also the file, which you have to start, when you want to start a backup process. (So put this into cron!)

Also, you can of course not use some features outlined here. That's why the whole functionality is broken into multiple scripts.


## Other features
* easy to understand, easy to modify (main script with less than 120 LOC)
* POSIX-compatible
* logging-friendly
* passphrase saved in external file, which you may protect in a better way
* pruning included
* privilege-separation (login scripts can have higher privilege than backup process)
* also a good idea: dump your database before backing up
* tested in production (but no guarantees, use at your own risk! 😉)
* more to come…

## What's in here?
* [`borgcron.sh`](borgcron.sh) – Main "runner script". Does all stuff when a backup is triggered.
* [`borgcron_start.sh`](borgcron_start.sh) – Header file with config options for a specific backup. This calls [`borgcron.sh`](borgcron.sh) internally.
* [`checklastbackup.sh`](checklastbackup.sh) – Script, which you can execute at login (Add to your `.bashrc` file or so), which notifies you when a backup has failed. Otherwise it remains silent.
* [`cronsizecache.sh`](cronsizecache.sh) – Small one-liner to cache the size of the dir where backups are stored. (useful for remote backup servers) You can then include the result with `cat` in your login script.
* [`databasedump.sh`](databasedump.sh) – Dumps your database into a dir/file. Make sure, this script and the dump dir is only readable by your backup process. Can be executed with higher privileges (i.e. root) brefore creating the backup than your backup script afterwards.
