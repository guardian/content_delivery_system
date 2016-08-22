#!/bin/bash

#this expects the following environment variables:
# $CDS_STARTUP set to TRUE to cause the process to be set up [internal]
# $CDS_ROUTENAME set to the route name [internal]
# $WATCHED_PATH path to set watch on [config]
# $STABLE_TIME time file must be stable to trigger action [config]
# $POLL_TIME time interval between polling path [config]
# $PID_PATH path to store pid notify [config] - probably /var/run/cds_backend/

#optional:
#

VERSION="$Rev: 472 $ $LastChangedDate: 2013-08-14 14:25:30 +0100 (Wed, 14 Aug 2013) $"

#check arguments
if [ "$WATCHED_PATH" == "" ]; then
	echo "-FATAL: WATCHED_PATH not specified" >&2
	exit 1
fi
if [ "$STABLE_TIME" == "" ]; then
	echo -FATAL: STABLE_TIME not specified >&2
	exit 1
fi
if [ "$POLL_TIME" == "" ]; then
	echo -FATAL: POLL_TIME not specified >&2
	exit 1
fi
if [ "$PID_PATH" == "" ]; then
	echo -FATAL: PID_PATH not specified >&2
	exit 1
fi

#Startup => set up watcher.  We need to use an intermediate script to convert he arguments into the form that cds_run needs
if [ "$CDS_STARTUP" == "true" ]; then
	octopus_run -d -t 1 -i "$WATCHED_PATH" -s $STABLE_TIME -w $POLL_TIME -c "cds_octrun_chain.sh $CDS_ROUTENAME" &
	OCT_PID=$!
	SAFE_PATH=`echo $CDS_ROUTENAME | sed s#/#_#`
	PID_FILE="$PID_PATH/cds_octrun_$SAFE_PATH.pid"
	echo $PID_FILE
	echo $OCT_PID > $PID_FILE
	echo SUCCESS: octopus_run set up on path "$WATCHED_PATH" with PID $OCT_PID
	exit 0
fi

if [ "$CDS_KILL" == "true" ]; then
	SAFE_PATH=`echo $CDS_ROUTENAME | sed s#/#_#`
	PID_FILE="$PID_PATH/cds_octrun_$SAFE_PATH.pid"
	kill `cat $PID_FILE`
	#FIXME: we should now check that the process is actually dead, and kill -9 it if it isn't.
	echo SUCCESS: kill signal sent to octopus_run PID `cat $PID_FILE`
	exit 0
fi

