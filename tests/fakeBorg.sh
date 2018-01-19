#!/bin/sh

CURRDIR=$( dirname "$0" )
FAKEBORG_WRITE_DIR="$CURRDIR/run"

# count execution
if [ -f "$FAKEBORG_WRITE_DIR/counter" ]; then
	count=$( cat "$FAKEBORG_WRITE_DIR/counter" )
	count=$(( count+1 ))
else
	count=1
fi

echo "fakeborg-executed ($count time)"
echo "command line: $*"

echo $count > "$FAKEBORG_WRITE_DIR/counter"

# log execution command line
echo "$*" >> "$FAKEBORG_WRITE_DIR/list"

# log execution of main commands
echo "$1" >> "$FAKEBORG_WRITE_DIR/maincommand"
