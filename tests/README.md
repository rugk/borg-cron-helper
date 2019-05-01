# Tests for borg-cron-helper

This/These directory/directories contain the tests for the project.

## How to run?
Generally, please have a look at [the Travis-CI configuration file](../.travis.yml). The tests should, however, be able to run locally fine.
But there are some environmental variables you need to set before running the tests in order. Each test scripts mentions the required environmental variables, but basically you can `export` the ones set in the Travis-CI file.

For test involving calling borg (many, actually), you need [to adjust your `PATH` to include the custom borg binary](https://github.com/rugk/borg-cron-helper/blob/master/.travis.yml#L18). It has to be placed in `$PWD/custombin`, named borg. The script `tests/helper/installBorg.sh` can do this for you.

To run the shellcheck tests, you have to install [`shellcheck`](https://github.com/koalaman/shellcheck), of course.

You need to [`shunit2`](https://github.com/kward/shunit2) (clone it into this `/tests/shunit2` dir) and when running the tests with the "real borg" binary `borg` needs to be installed.

All tests are usual `.sh` files. They may require a specific shell or be POSIX-compatible, just look at the [shebang](https://en.wikipedia.org/wiki/Shebang_(Unix)). If the shell is installed, the shebang should take care of it.

Each tests can, however, usually run separately, i.e. you can still run the unit tests, even when you do not want to install shellcheck. However, do not try to run them in parallel. 😃

## Automatic execution

All tests are configured to be run on pull requests and commits automatically, [via Travis-CI](https://travis-ci.org/rugk/borg-cron-helper/builds). We use the docker container infrastructure, as it is faster.

**Current status:** 
[![Build Status](https://travis-ci.org/rugk/borg-cron-helper.svg?branch=master)](https://travis-ci.org/rugk/borg-cron-helper)

## Coverage/What is not tested?

Note that neither the system integration is tested, nor the small tools (like `databasedump.sh`). Everything else is more or less covered by the tests. 
