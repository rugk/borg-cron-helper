# Borg cron helper scripts

[![Build Status](https://travis-ci.org/rugk/borg-cron-helper.svg?branch=master)](https://travis-ci.org/rugk/borg-cron-helper)

**Automate backups with borg in a more convenient and reliable way!** These scripts are some small and handy shell scripts to automate the backup process with [BorgBackup](https://borgbackup.readthedocs.io/). They are POSIX-compatible, so they should run with all shells. You're free to modify them for your needs!

They add some convienent features around borg, regarding environments with only **one client**.

## Features

- **[Local lock system](#local-lock-borg--v110):** Cirumvent the issue of [stale](https://github.com/borgbackup/borg/issues/813) [lock files](https://github.com/borgbackup/borg/issues/2306).
- **[Automated retries](#less-maintenance-more-safety):** When backups [stop mid-way](https://borgbackup.readthedocs.io/en/stable/faq.html#if-a-backup-stops-mid-way-does-the-already-backed-up-data-stay-there) they are automatically restarted.
- **[Simple configuration](config/example-backup.sh):** Using shell-scripts you can configure each backup and then execute it the order/way you want.
- **[Status information](#less-maintenance-more-safety):** You can use a login script to get a notice when backups failed.
- **[For servers & desktops](#desktop-integration):** The script is also uable on desktops. But rest assured: We'll never forget servers.
- **[Optional & adjustable](#modular-approach):** You do not have to use all features and you can adjust them in a simply way.

### Local lock (borg < v1.1.0)

When the backup process is interrupted, sometimes the remote borg repository stays locked. That's why further backups will fail.

The issue [has been addressed](https://github.com/borgbackup/borg/pull/1674) in borg **v1.1.0** (currently beta), but I have not tested it and until it works there, here is my workaround.

Borg's current PID is written into a file. As long as the file exists the backup is considered to be "locked". At the end of the backup process (no matter whether it was succesful or not), the local lock is being removed, permitting further backups to start. The "local lock" is more reliable than the "remote lock" system, currently implemented in stable versions of borg.

### Less maintenance, more safety!

Sometimes [backups stop mid-way](https://borgbackup.readthedocs.io/en/stable/faq.html#if-a-backup-stops-mid-way-does-the-already-backed-up-data-stay-there). This can have different reasons (e.g. an unreliable network). However we still want our data to be backed up. That's why the script integrates a **retry mechanism** to retry the backup in case of a failure (for up to three times by default). Between the retry attempts the script pauses some minutes by default, to wait for your server to restart or the connection to reestablish. This is also a workaround for the ["connection closed by remote" issue](https://github.com/borgbackup/borg/issues/636), which seems to affect some users.

Additionally the script has the ability to write stats of the last executed backup. [`cronsizecache.sh`](cronsizecache.sh) outputs the size of backups stored on the backup server. Both can be used (in conjunction with a script to check the last backup time) to **monitor your backups** and to automatically notify you, in case a backup failed/didn't work.

**Rest assured your backups are safe and recover themselve if possible.** (If they don't, you'll get to know that.)

### Desktop integration

![GNOME desktop notification: BorgBackup "example-backup" – BorgBackup has been successful](https://raw.githubusercontent.com/wiki/rugk/borg-cron-helper/notification.png)

The whole script can, of course, run on servers, but some features making it also suitable for desktops. It can display notifications about started and finished backups, including its result and it can even ask the user, whether to retry the backup in case it failed. Or you ask the user about **the password for your backup** interactively, in a GUI window.

It has been tested with GNOME, but should work on any system, where `zenity` is installed. And: You can always easily adjust it to work with a different program.

It is even possible to configure it to show the notification as a "standard" user while the backup is actually running as root.

For examples, see [the wiki page about more ways for GUI integration](https://github.com/rugk/borg-cron-helper/wiki/Additional-GUI-integration).

### Modular approach

The main "work" is done by [`borgcron.sh`](borgcron.sh). This script can be used to execute a single backup. The configuration files per repository/backup are saved in the [`config`](config/) directory. The file [`borgcron_starter.sh`](borgcron_starter.sh) is the file you should call from cron or when debugging manually. Using it, you can execute multiple backups by passing the config names to it.

Also, you can of course not use some features outlined here. That's why the whole functionality is broken into multiple scripts and configurable in a single config file per backup.

### More features...

- easy to understand, easy to modify
- POSIX-compatible
- pretty logs
- passphrase can be protected better, because it's saved in an external file
- pruning after the backup
- script to dump databases before backing up
- privilege-separation (login scripts can have higher privilege than backup process)
- tested in production (but no guarantees, use at your own risk! 😉)
- logging if backup is interruped by signals (e.g. at shutdown)
- tested with **more than 30** automated unit tests (see Travis-CI badge above)
- more to come...

## What's in here?

- [`borgcron_starter.sh`](borgcron_starter.sh) – Cycles through backup files and interprets passed parameters.
- [`borgcron.sh`](borgcron.sh) Main script. Actually executes the backup and runs borg.
- [`config`](config/) – Directory for config files

  - [`example-backup.sh`](config/example-backup.sh) – Example configuration file for a backup. Please use this template to add your backup(s).

- [`tools`](tools/) – additional scripts

  - [`checklastbackup.sh`](tools/checklastbackup.sh) – Script, which you can execute at login (add it to your `.bashrc` file or so). It notifies you when a backup has failed. Otherwise it remains silent.
  - [`cronsizecache.sh`](tools/cronsizecache.sh) – Small one-liner to cache the size of the dir where backups are stored. (useful for remote backup servers) You can then include the result with `cat` in your login script.
  - [`databasedump.sh`](tools/databasedump.sh) – Dumps one or several databases into a dir/file. Make sure that this script and the dump dir are only readable by your backup user. Script might have to be executed with higher privileges (i.e. root) for creating the backup.

- [`system`](system/) – Various system scripts, you may need for your setup.

- [`tests`](tests/) – Scripts for unit testing, etc. See Readme inside of it, not needed in production.

## How to setup?

Setup instructions can be found [in the wiki](https://github.com/rugk/borg-cron-helper/wiki/How-to-setup%3F).

## Vulnerability reporting

If you find a vulnerability drop me a mail at [my mail address listed in my GitHub profile](https://github.com/rugk). You can find my [public key here](https://keys.mailvelope.com/pks/lookup?op=get&search=0x8F162AE44088F1BE) and [on keybase.io](https://keybase.io/rugk). My fingerprint is `7046 C1B2 8644 9EAF 9F3F F5C1 8F16 2AE4 4088 F1BE`.

## Donations

[![Donate using Liberapay](https://liberapay.com/assets/widgets/donate.svg)](https://liberapay.com/rugk/donate)
