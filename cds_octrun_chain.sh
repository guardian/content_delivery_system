#!/bin/bash

#This script is "glue" to allow cds backend to be invoked by octopus_run.
#It is called by octopus_run, setup by standard methods.
#To recap, octopus_run calls us with $1 = changed file and $2=path.
#cds_run requires paths for media and metadata files.

#For reference, if passing through a static arg from oct_run doesn't work,
#then we can get just the name of the watchfolder out of the path by doing:
LOGFILE="/Users/macadmin/cds_octrun_chain.log"
#MASTERS_REPO="/Volumes/MultiMedia1/DAM/Media Library/LIB_VIDMASTERS"
MASTERS_REPO="/Volumes/Proxies/octopus_multimedia/preview"
DATE=`date`

echo cds_octrun_chain [$DATE] started >> $LOGFILE

if [ ! -f "$2/$1" ]; then
	echo cds_octrun_chain [$DATE]: Unable to find input file "$2/$1".  This means that it has either been moved by another process, >> $LOGFILE
	echo or that it is a re-name created by this script, in which case you needn\'t worry. >> $LOGFILE
	echo Exiting. >> $LOGFILE
	exit 0
fi

ROUTENAME=`echo $2 | rev | cut -d / -f 1 | rev`

if [ ! -d /Volumes/MediaTransfer/Graveyard ]; then
	echo cds_octrun_chain [$DATE]: /Volumes/MediaTransfer/Graveyard does not exist.  Trying to create. >> $LOGFILE
	mkdir /Volumes/MediaTransfer/Graveyard >> $LOGFILE 2>&1
fi

if echo $1 | egrep \.inmeta$; then
	file_type="inmeta"
elif echo $1 | egrep \.meta$; then
	file_type="meta"
elif echo $1 | egrep \.xml$; then
	file_type="xml"
else
	file_type="media"
fi

echo cds_octrun_chain [$DATE]: Got file-type $file_type >> $LOGFILE

if [ "$file_type" == "inmeta" ]; then
	if [ ! -f `which ee_get.pl` ]; then
		echo cds_octrun_chain.sh [$DATE]: WARNING: Unable to find ee_get.pl >> $LOGFILE
	fi
	INMETA_FILE="$2/$1"
	/usr/local/bin/ee_get.pl --dump --minimal "$2/$1" meta.filename >> $LOGFILE 2>&1
	MEDIA_FILE=`/usr/local/bin/ee_get.pl --minimal "$2/$1" meta.filename 2>/dev/null`
	#MEDIA_PATH=`/usr/local/bin/ee_get.pl --minimal "$2/$1" meta.filepath 2>/dev/null`
	#if [ "$MEDIA_PATH" != "" ]; then
	#	MASTERS_REPO="$MEDIA_PATH"
	#fi
	echo cds_octrun_chain.sh: Got media filename "$MEDIA_PATH/$MEDIA_FILE" from metafile "$2/$1" >> $LOGFILE
	if [ ! -f "$MASTERS_REPO/$MEDIA_FILE" ]; then
		echo File $MASTERS_REPO/$MEDIA_FILE does not exist, falling back to looking in the current directory...
		unset MEDIA_FILE
	else
		#Episode Engine requires that the inmeta file has the same name as the media file
		mv "$INMETA_FILE"  "$2/$MEDIA_FILE.inmeta"
		INMETA_FILE="$2/$MEDIA_FILE.inmeta"
		#MEDIA_FILE=`echo $MEDIA_FILE | sed "s/\.[^\.]*$//"`
	fi
fi

#else
#	./cds_run --route "$1" --input-media "$3/$2"
#fi

echo cds_octrun_chain [$DATE]: running route $ROUTENAME.xml  on $MASTERS_REPO/$MEDIA_FILE >> $LOGFILE

if [ "$MEDIA_FILE" == "" ]; then
	echo /usr/local/bin/cds_run.pl --route "$ROUTENAME.xml" --input-$file_type "$2/$1" >> $LOGFILE
	/usr/local/bin/cds_run.pl --route "$ROUTENAME.xml" --input-$file_type "$2/$1" >> $LOGFILE 2>&1
else
	echo /usr/local/bin/cds_run.pl --route "$ROUTENAME.xml" --input-media "$MASTERS_REPO/$MEDIA_FILE" --input-$file_type "$INMETA_FILE" >> $LOGFILE
	/usr/local/bin/cds_run.pl --route "$ROUTENAME.xml" --input-media "$MASTERS_REPO/$MEDIA_FILE" --input-$file_type "$INMETA_FILE" >> $LOGFILE 2>&1
fi

if [ "$file_type" == "xml" ]; then
	#if [ -f "$2/$1" ]; then rm -f "$2/$1"; fi >> $LOGFILE 2>&1
	if [ -f "$2/$1" ]; then
		echo cds_octrun_chain [$DATE]: $file_type file "$2/$1" still exists.  Moving to graveyard in /usr/local/spool/xml. >> $LOGFILE
		mv "$2/$1" "/usr/local/spool/xml" >> $LOGFILE 2>&1
	fi
fi

if [ "$file_type" != "xml" ]; then
	if [ -f "$2/$1" ]; then
		echo cds_octrun_chain [$DATE]: $file_type file "$2/$1" still exists.  Moving to graveyard in /Volumes/MediaTransfer/Graveyard. >> $LOGFILE
		mv "$2/$1" "/Volumes/MediaTransfer/Graveyard" >> $LOGFILE 2>&1
	fi
	if [ -f "$INMETA_FILE" ]; then
		echo cds_octrun_chain [$DATE]: $file_type file "$2/$1" still exists.  Moving to graveyard in /Volumes/MediaTransfer/Graveyard. >> $LOGFILE
		mv "$2/$1" "/Volumes/MediaTransfer/Graveyard" >> $LOGFILE 2>&1
	fi
fi
