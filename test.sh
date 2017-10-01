#!/bin/sh
i=1
	read -rp "The backup failed. ($i. try) Do you want to try it again? [yN]: " retry
	if [ "$retry" = "Y" ] || [ "$retry" = "y" ]; then
		return 0 # (true)
	fi
	return 1 # (false)
