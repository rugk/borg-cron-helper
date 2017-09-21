#!/bin/sh

echo "fakeborg-executed"
echo "command line: $*"

CURRDIR=$( dirname "$0" )

# count execution
if [ -f "$CURRDIR/counter" ]; then
	count=$( cat "$CURRDIR/counter" )
	count=$(( count+1 ))
else
	count=1
fi

echo $count > "$CURRDIR/counter"

# log execution command line
echo "$*" >> "$CURRDIR/list"
