#!/bin/bash

#This script renames the given files by pre-pending a string to the filename.
#Arguments:
# <dateformat> [OPTIONAL] - Format to use for the built-in {date} substitution.  This should be a format string for the unix date command.  Run "man date" from a Terminal window to get more information on this.
# <prepend>blah - text to pre-pend to the filename.  This can contain the entity {date}, or any datastore substitution.
#END DOC

VERSION="$Rev: 651 $ $LastChangedDate: 2014-01-01 16:57:45 +0000 (Wed, 01 Jan 2014) $"

echo MESSAGE: Shell script prepend_to_filename invoked

if [ "$dateformat" != "" ]; then
	DATEPORTION=`date +$dateformat`
fi

EXPANDED_PREPEND=`echo $prepend | sed s/{date}/$DATEPORTION/g`
DATASTORE=`which cds_datastore.pl`;
if [ "${DATASTORE}" != "" && -x "${DATASTORE}" ]; then
	EXPANDED_PREPEND=`${DATASTORE} subst "${EXPANDED_PREPEND}"`
else
	echo -WARNING: Unable to find cds_datastore.pl.  No substitutions made.
fi

if [ "$cf_media_file" != "" ]; then
	MEDIA_FILE_BASE=`basename "$cf_media_file"`
	MEDIA_FILE_DIR=`dirname "$cf_media_file"`
	MEDIA_FILE_XTN=`echo $cf_media_file | awk -F . '{print $NF}'`

	echo DEBUG: prepend_to_filename: Moving file $cf_media_file to $EXPANDED_PREPEND$MEDIA_FILE_BASE

	mv "$cf_media_file" "$MEDIA_FILE_DIR/$EXPANDED_PREPEND$MEDIA_FILE_BASE"
	echo cf_media_file=$MEDIA_FILE_DIR/$EXPANDED_PREPEND$MEDIA_FILE_BASE >> "$cf_temp_file"
fi

if [ "$cf_meta_file" != "" ]; then
        MEDIA_FILE_BASE=`basename "$cf_meta_file"`
        MEDIA_FILE_DIR=`dirname "$cf_meta_file"`
        MEDIA_FILE_XTN=`echo $cf_meta_file | awk -F . '{print $NF}'`

        echo DEBUG: prepend_to_filename: Moving file $cf_meta_file to $EXPANDED_PREPEND$MEDIA_FILE_BASE

        mv "$cf_meta_file" "$MEDIA_FILE_DIR/$EXPANDED_PREPEND$MEDIA_FILE_BASE"
        echo cf_meta_file=$MEDIA_FILE_DIR/$EXPANDED_PREPEND$MEDIA_FILE_BASE >> "$cf_temp_file"
fi

if [ "$cf_inmeta_file" != "" ]; then
        MEDIA_FILE_BASE=`basename "$cf_inmeta_file"`
        MEDIA_FILE_DIR=`dirname "$cf_inmeta_file"`
        MEDIA_FILE_XTN=`echo $cf_inmeta_file | awk -F . '{print $NF}'`

        echo DEBUG: prepend_to_filename: Moving file $cf_inmeta_file to $EXPANDED_PREPEND$MEDIA_FILE_BASE

        mv "$cf_inmeta_file" "$MEDIA_FILE_DIR/$EXPANDED_PREPEND$MEDIA_FILE_BASE"
        echo cf_inmeta_file=$MEDIA_FILE_DIR/$EXPANDED_PREPEND$MEDIA_FILE_BASE >> "$cf_temp_file"
fi

if [ "$cf_xml_file" != "" ]; then
        MEDIA_FILE_BASE=`basename "$cf_xml_file"`
        MEDIA_FILE_DIR=`dirname "$cf_xml_file"`
        MEDIA_FILE_XTN=`echo $cf_xml_file | awk -F . '{print $NF}'`

        echo DEBUG: prepend_to_filename: Moving file $cf_xml_file to $EXPANDED_PREPEND$MEDIA_FILE_BASE

        mv "$cf_xml_file" "$MEDIA_FILE_DIR/$EXPANDED_PREPEND$MEDIA_FILE_BASE"
        echo cf_xml_file=$MEDIA_FILE_DIR/$EXPANDED_PREPEND$MEDIA_FILE_BASE >> "$cf_temp_file"
fi




exit 0

