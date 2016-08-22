#!/bin/bash

#THIS HAS BEEN DEPRECATED, USE PREPEND_TO_FILE OR CONFORMFILENAME
#END DOC
#This script renames the given files to the PA naming convention.
#It expects the following environment variables:
# cf_media_file
# cf_xml_file
# cf_temp_file
# dateformat
# prepend - text to pre-pend to the filename

VERSION="$Rev: 651 $ $LastChangedDate: 2014-01-01 16:57:45 +0000 (Wed, 01 Jan 2014) $"
echo MESSAGE: Shell script pa_rename invoked

DATEPORTION=`date +$dateformat`

if [ "$cf_xml_file" == "" ]; then
	echo -FATAL: pa_rename requires a metadata XML file to read the slugline from.
	exit 1;
fi

if [ ! -x `which newsml_get.pl` ]; then
	echo -FATAL: could not find newsml_get.pl, or it is not executable.  Check that it is in the PATH on this system.
	exit 2;
fi

SLUGPORTION=`/usr/local/bin/newsml_get.pl --minimal "$cf_xml_file" Components.Package.SlugLine`

echo DEBUG: pa_rename: Got slugline $SLUGPORTION from $cf_xml_file

if [ "$SLUGPORTION" == "" ]; then
	echo ERROR: Unable to determine slugline from file "$cf_xml_file".  File will not be renamed but route will continue.
	exit 0
fi

if [ "$cf_media_file" != "" ]; then
	MEDIA_FILE_BASE=`basename "$cf_media_file"`
	MEDIA_FILE_DIR=`dirname "$cf_media_file"`
	MEDIA_FILE_XTN=`echo $cf_media_file | awk -F . '{print $NF}'`

	echo DEBUG: pa_rename: Moving file $cf_media_file to $prepend.$DATEPORTION.$SLUGPORTION.$MEDIA_FILE_XTN

	mv "$cf_media_file" "$MEDIA_FILE_DIR/$prepend.$DATEPORTION.$SLUGPORTION.$MEDIA_FILE_XTN"
	echo cf_media_file=$MEDIA_FILE_DIR/$prepend.$DATEPORTION.$SLUGPORTION.$MEDIA_FILE_XTN >> "$cf_temp_file"
fi

META_FILE_BASE=`basename "$cf_xml_file"`
META_FILE_DIR=`dirname "$cf_xml_file"`
META_FILE_XTN=`echo $cf_xml_file | awk -F . '{print $NF}'`

echo DEBUG: pa_rename: Moving file $cf_xml_file to $prepend.$DATEPORTION.$SLUGPORTION.$META_FILE_XTN

mv "$cf_xml_file" "$META_FILE_DIR/$prepend.$DATEPORTION.$SLUGPORTION.$META_FILE_XTN"
echo cf_xml_file=$META_FILE_DIR/$prepend.$DATEPORTION.$SLUGPORTION.$META_FILE_XTN >> "$cf_temp_file"

exit 0

