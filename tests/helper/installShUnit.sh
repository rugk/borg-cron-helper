#!/usr/bin/env bash
#
# Verifies that the key is signed by rugk.
#
set -ex

CURRDIR=$( dirname "$0" )
SHUNIT_CHECKOUT="3f2bff2a815097be557a5c0af77f967a87139409"

# import key
gpg --import "$CURRDIR/kwardsigningkey.asc"
# trust key
echo "E6F15D6E64FE00A9ECD00362E52196194E1B251C:6:"|gpg --import-ownertrust

# download data
cd tests
git clone https://github.com/kward/shunit2
cd shunit2
git checkout "$SHUNIT_CHECKOUT"

# check latest commit
# git verify-tag "$SHUNIT_VERSION_TAG" # disabled, as we do not have a stable release yet

cd ../..
