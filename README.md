# Borg cron helper scripts

**Automate backups with borg in a more convenient and reliable way!**
These scripts are some small and handy shell scripts to automate the backup process with [BorgBackup](https://borgbackup.readthedocs.io/). They are POSIX-compatible, so they should run with all shells. You're free to modify them for your needs!

They add some convienent features around borg, regarding environments with only **one client**.

## Features
* **[Local lock system](#local-lock):** Cirumvent the issue of [stale](https://github.com/borgbackup/borg/issues/813) [lock files](https://github.com/borgbackup/borg/issues/2306).
* **[Automated retries](#less-maintenance-more-safety):** When backups [stop mid-way](https://borgbackup.readthedocs.io/en/stable/faq.html#if-a-backup-stops-mid-way-does-the-already-backed-up-data-stay-there) they are automatically restarted.
* **[Simple configuration](config/example-backup.sh):** Using shell-scripts you can configure each backup and then execute it the order/way you want.
* **[Status information](#less-maintenance-more-safety):** You can use a login script to get a notice when backups failed.
* **[Optional & adjustable](#modular-approach):** You do not have to use all features and you can adjust them in a simply way.

### Local lock (borg < v1.1.0)

When the backup process is interrupted, sometimes the remote borg repository stays locked. That's why further backups will fail.

The issue [has been addressed](https://github.com/borgbackup/borg/pull/1674) in borg **v1.1.0** (currently beta), but I have not tested it and until it works there, here is my workaround.

Borg's current PID is written into a file. As long as the file exists the backup is considered to be "locked". At the end of the backup process (no matter whether it was succesful or not), the local lock is being removed, permitting further backups to start. The "local lock" is more reliable than the "remote lock" system, currently implemented in stable versions of borg.

### Less maintenance, more safety!

Sometimes [backups stop mid-way](https://borgbackup.readthedocs.io/en/stable/faq.html#if-a-backup-stops-mid-way-does-the-already-backed-up-data-stay-there). This can have different reasons (e.g. an unreliable network). However we still want our data to be backed up.
That's why the script integrates a **retry mechanism** to retry the backup in case of a failure (for up to three times by default). Between the retry attempts the script pauses some minutes by default, to wait for your server to restart or the connection to reestablish.
This is also a workaround for the ["connection closed by remote" issue](https://github.com/borgbackup/borg/issues/636), which seems to affect some users.

Additionally the script has the ability to write stats of the last executed backup. [`cronsizecache.sh`](cronsizecache.sh) outputs the size of backups stored on the backup server. Both can be used (in conjunction with a script to check the last backup time) to **monitor your backups** and to automatically notify you, in case a backup failed/didn't work.

**Rest assured your backups are safe and recover themselve if possible.** (If they don't, you'll get to know that.)

### Modular approach

The main "work" is done by [`borgcron.sh`](borgcron.sh). This script can be used to execute a single backup.
The configuration files per repository/backup are saved in the  [`config`](config/) directory.
The file [`borgcron_starter.sh`](borgcron_starter.sh) is the file you should call from cron or when debugging manually. Using it, you can execute multiple backups by passing the config names to it.

Also, you can of course not use some features outlined here. That's why the whole functionality is broken into multiple scripts.

### More features…
* easy to understand, easy to modify
* POSIX-compatible
* pretty logs
* passphrase can be protected better, because it's saved in an external file
* pruning after the backup
* script to dump databases before backing up
* privilege-separation (login scripts can have higher privilege than backup process)
* tested in production (but no guarantees, use at your own risk! 😉)
* logging if backup is interruped by signals (e.g. at shutdown)
* more to come…

## What's in here?
* [`borgcron_starter.sh`](borgcron_starter.sh) – Interprets user input, feeds the backup routine.
* [`borgcron.sh`](borgcron.sh) Main script. Does all stuff, when a backup is triggered.
* [`config`](config/) – Directory for config files
   * [`example-backup.sh`](config/example-backup.sh) – Example configuration file for one backup. Please use this template to add your backup(s).
* [`tools`](tools/) – additional scripts
   * [`checklastbackup.sh`](tools/checklastbackup.sh) – Script, which you can execute at login (add to your `.bashrc` file or so),. It notifies you when a backup has failed. Otherwise it remains silent.
   * [`cronsizecache.sh`](tools/cronsizecache.sh) – Small one-liner to cache the size of the dir where backups are stored. (useful for remote backup servers) You can then include the result with `cat` in your login script.
   * [`databasedump.sh`](tools/databasedump.sh) – Dumps one or several databases into a dir/file. Make sure, that this script and the dump dir are only readable by your backup user. Script might have to be executed with higher privileges (i.e. root) for creating the backup.

## How to setup?

### 1. Download

1. Download the  [latest release](https://github.com/rugk/borg-cron-helper/releases) of the scripts.
2. It is suggested to verify them with my [public key](https://github.com/rugk/otherfiles/blob/master/RugkGitSoftwareSignKey.txt) and/or look through the scripts, so you know what they do and that they do not do anything malicious.
   To do so just run `gpg --verify download.zip.asc`.
3. Make sure that all script are not writable by the backup user, if it is different than root.

### 2. Enter the backup parameters

In the ['config directory'](config/) you will find an example configuration file. Set the variables according to your already initialized borg backup. Each backup has its own configuration file.

### 3. Setup statistics (optional)

To use the logging and reporting functionality, you have to create some dirs. These have to be writable by the user running the scripts.

1. For logging: Create `/var/log/borg` with appropiate permissions.
2. Create a subdirectry called `/var/log/borg/last` (configurable as [`LAST_BACKUP_DIR`](borgcron.sh#L9)). There the `.time` files will be written to containing the tiome of the last backup execution.
3. Include/add the [`tools/checklastbackup.sh`](tools/checklastbackup.sh) script to your `~/.bashrc`, `~/.zshrc` or similar, depending on your shell). It will read the `.time` files to display the time of the last execution of your backups, when you login into your shell. You may also adjust the time period ([`CRITICAL_TIME`](tools/checklastbackup.sh#L8)) in order to get a notification, if no successful backup has been made within that time.

### 4. Setup local log (optional)

By default `RUN_PID_DIR`, where the PID files are saved, is set to `/var/run`. It is configurable in `RUN_PID_DIR` in [`borgcron.sh`](borgcron.sh#L10). Note that for the system to work, the `RUN_PID_DIR` must **exist and be writable**. This is [usually done](https://askubuntu.com/questions/303120/how-folders-created-in-var-run-on-each-reboot) by init scripts or systemd, because `/var/run` is often mounted as a tempfs, so all data is deleted at shutdown and you have to recreate the dirs at the (next) startup. Of course, this does not matter, when running the backup as root, as it can easily recreate the directory itself, then. So either:
  * change the configuration to use a dir writable by the user, or
  * create a init.d script or systemd service file, which creates the dir in `/var/run`

If the given dir does not exist, the backup will not run for security reasons.
To disable this feature, set [`RUN_PID_DIR`](borgcron.sh#L10) to an empty string (`""`). This will disable the local locking system and use borg's default locking mechanism. This is useful when you run borg v1.1.0 or higher.

**Attention:** This system assumes, that you access your borg repo in a "single-user" (one client, one server) environment. As the locking is managed locally, you should ensure, that **only one client** is allowed to access the borg repository. Otherwise **data loss may occur**, as this script automatically breaks the remote lock in the borg repository, if it is not locked locally.

### 5. Setup MySQL dump (optional)

The [`databasedump.sh`](tools/databasedump.sh) script can be used to dump your database(s) into a dir before executing the backup. You can do this either directly before running the backup by including [`databasedump.sh`](tools/databasedump.sh) in your config file, or you can setup a new cron job using another user, who is allowed to dump the databases into a dir. The cron job should, of course, be executed before executing the actual backup.

### 6. Setup cron/anacron

Finally test the backup process. Then add the cron entry for the script (use the `crontab -e` command to edit the files): 
```
# daily backup at midnight
00 00 * * * /path/to/borgcron_starter.sh >> /var/log/borg/allbackups.log 2>&1
```

Or anacron creating the following file in `/etc/cron.daily`, `/etc/cron.weekly` or similar:
``` 
#!/bin/sh
/path/to/borgcron_starter.sh >> /var/log/borg/allbackups.log 2>&1
```

Do not forget to make the anacron file executable (`chmod +x`).
