# Tests for borg-cron-helper

This/These directory/directories contain the tests for the project.

## How to run?
Generally, please have a look at [the Travis-CI configuration file](../.travis.yml).
There are some envorimental variables, you may need to set before running the tests.

To run the shellcheck tests, you have to install [`shellcheck`](https://github.com/koalaman/shellcheck), of course.

You need to [`shunit2`](https://github.com/kward/shunit2) (clone it into this `tests/` dir) and in some cases `borg`.

All tests are usual `.sh` files. They may require a specific shell or be POSIX-compatible, just look at the [shebang](https://en.wikipedia.org/wiki/Shebang_(Unix)). If the shell is installed, the shebang should take care of it.

## Automatic execution

All tests are configured to be run on pull requests and commits automatically, [via Travis-CI](https://travis-ci.org/rugk/borg-cron-helper/builds). We use the docker container infrastructure, as it is faster.

**Current status:** 
[![Build Status](https://travis-ci.org/rugk/borg-cron-helper.svg?branch=master)](https://travis-ci.org/rugk/borg-cron-helper)