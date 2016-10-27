#!/bin/bash
# This module uploads files to a server via Aspera.
#
# It assumes that you have Aspera client installed, licensed and working.
#
#Arguments:
# <take-files>{media|meta|inmeta|xml} - upload these files to the server.
# <host>asperaserver.hostname.com - upload to this server
# <username>blah - log in with this username
# <remote_path>/path/to/upload/ -  change to this directory to upload the file. Should end with a /.
# <password>text - Password for the Aspera server.
# <debug/> [OPTIONAL] - get more verbose output from Aspera client
#END DOC

if [ "${debug}" != "" ]; then
echo
set
echo -----------------
fi

ASCP_CMD = `which ascp`

if [ ! -x "${ASCP_CMD}" ]; then
    echo "-ERROR: Unable to find a working ascp command.  Is the Aspera client installed?"
    exit 1
fi

DATASTORE=`which cds_datastore.pl`
if [ "${DATASTORE}" == "" ]; then
	echo "-ERROR: Unable to find CDS datastore interface. Check that CDS is installed properly."
	exit 1
fi

USERNAME=`${DATASTORE} subst "$username"`
HOST=`${DATASTORE} subst "$hostname"`
if [ "$HOST" == "" ]; then
	echo "-ERROR: No hostname found. You need to specify one with the <hostname> tag in the routefile."
	exit 1
fi
PASSWORD=`${DATASTORE} subst "$password"`
if [ "$HOST" == "" ]; then HOST=$hostname; fi
REMOTEPATH=`${DATASTORE} subst "${remote_path}"`

if [ "${debug}" != "" ]; then
	EXTRAFLAGS="-v"
else
	EXTRAFLAGS=""
fi

#end configurable settings

DATE=`date "+${date_format}"`

echo Media file: ${cf_media_file}
echo XML file: ${cf_xml_file}
echo InMeta file: ${cf_inmeta_file}
echo Meta file: ${cf_meta_file}

if [ "$cf_media_file" != "" ]; then
	FILE_ONLY=`echo $cf_media_file | rev | cut -d / -f 1 | rev`
	UPLOAD_MEDIA=$FILE_ONLY
fi

if [ "$cf_meta_file" != "" ]; then
	FILE_ONLY=`echo $cf_meta_file | rev | cut -d / -f 1 | rev`
	UPLOAD_META=$FILE_ONLY
fi

if [ "$cf_inmeta_file" != "" ]; then	
    FILE_ONLY=`echo $cf_inmeta_file | rev | cut -d / -f 1 | rev`
	UPLOAD_INMETA=$FILE_ONLY
fi

if [ "$cf_xml_file" != "" ]; then
    FILE_ONLY=`echo $cf_xml_file | rev | cut -d / -f 1 | rev`	
	UPLOAD_XML=$FILE_ONLY
fi

# The line below sets an environment variable which is used by ascp for its password
export ASPERA_SCP_PASS=$PASSWORD

RESULT="0"

if [ "$cf_media_file" != "" ]; then
	ascp --host=$HOST --user=$USERNAME --mode=send $EXTRAFLAGS "$cf_media_file" "$REMOTEPATH/$UPLOAD_MEDIA"
	
	CODE=$?

	if [ "$CODE" != "0" ]; then
       echo -ERROR: Aspera encountered an error $? uploading the media file.
       $RESULT="1"
    else
		echo +SUCCESS: Aspera media file upload completed successfully.
	fi
fi

if [ "$cf_meta_file" != "" ]; then
	ascp --host=$HOST --user=$USERNAME --mode=send $EXTRAFLAGS "${cf_meta_file}" "$REMOTEPATH/$UPLOAD_META"
	
	CODE=$?

	if [ "$CODE" != "0" ]; then
       echo -ERROR: Aspera encountered an error $? uploading the meta file.
       $RESULT="1"
    else
		echo +SUCCESS: Aspera meta file upload completed successfully.
	fi
fi

if [ "$cf_inmeta_file" != "" ]; then
	ascp --host=$HOST --user=$USERNAME --mode=send $EXTRAFLAGS "$cf_inmeta_file" "$REMOTEPATH/$UPLOAD_INMETA"
	
	CODE=$?

	if [ "$CODE" != "0" ]; then
       echo -ERROR: Aspera encountered an error $? uploading the inmeta file.
       $RESULT="1"
    else
		echo +SUCCESS: Aspera inmeta file upload completed successfully.
	fi
fi

if [ "$cf_xml_file" != "" ]; then
	ascp --host=$HOST --user=$USERNAME --mode=send $EXTRAFLAGS "$cf_xml_file" "$REMOTEPATH/$UPLOAD_XML"
	
	CODE=$?

	if [ "$CODE" != "0" ]; then
       echo -ERROR: Aspera encountered an error $? uploading the XML file.
       $RESULT="1"
    else
		echo +SUCCESS: Aspera XML file upload completed successfully.
	fi
fi

if [ "$RESULT" != "0" ]; then
       echo "-FATAL: Aspera encountered an error or errors uploading the file(s)."
       exit 1
fi

echo "+SUCCESS: Aspera upload(s) completed successfully."
exit 0
