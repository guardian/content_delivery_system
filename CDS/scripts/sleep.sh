#!/bin/bash

#Simple method to pause execution for the given period.  Useful for testing and for locking.
#Arguments:
# <randomise/>	- sleep for a randomly selected amount of time.  Useful for making simultaneously triggered routes seperate themselves out e.g. for locking.
# <random_maximum>n - if randomising, sleep for a maximum of n seconds.
# <sleep_time>n - if not randomising, sleep for n seconds exactly.
#END DOC

VERSION="$Rev: 517 $ $LastChangedDate: 2013-10-07 12:07:00 +0100 (Mon, 07 Oct 2013) $"

if [ "x${randomise}" != "x" ]; then
	echo Sleeping a random amount of time
	if [ "x${random_maximum}" == "x" ]; then
		echo No random_maximum set, defaulting to 10s.
		random_maximum=10
	fi
	sleep_time=$[ ( $RANDOM % ${random_maximum} ) + 1]
fi

echo INFO: I will sleep for ${sleep_time} seconds.

sleep ${sleep_time}
exit 0

