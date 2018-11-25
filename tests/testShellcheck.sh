#!/usr/bin/env sh
#
# Runs shellcheck over all .sh files to catch errors.
#
echo "Shellcheck version:"
shellcheck -V

# Run test(s) for each *.sh file
find .  -type f -iname "*.sh" -not -path "./tests/shunit2/*" -exec sh -c '
	errorCount=0
	for n in "$@"; do
		./tests/testShellcheckExec.sh "$n" || errorCount=$((errorCount + 1))
	done
	[ $errorCount -ne 0 ] && echo "Shellcheck found errors within $errorCount file(s)."
	exit $errorCount' \
	_ {} +

# find doesn't forward the return values of its sub-commands.
# Any exit code >=1 results in error code = 1.
foundErrors=$?

[ $foundErrors -eq 0 ] && echo "Finished shellcheck test(s) without error(s)."

exit $foundErrors
