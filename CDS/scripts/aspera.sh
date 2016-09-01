#!/bin/bash
# This module uploads files to a server via Aspera.
#
# It assumes that you have Aspera installed and working.
#
#Arguments:
# <host>sftp.hostname.com - upload to this server 
# <username>blah - log in with this username 
# <remote_path>/path/to/upload/ -  change to this directory to upload the file. Should end with a /.
# <password>text - Password for the Aspera server.
#END DOC

if [ "${debug}" != "" ]; then
echo
set
echo -----------------
fi

DATASTORE=`which cds_datastore.pl`
if [ "${DATASTORE}" == "" ]; then
	echo "-ERROR: Unable to find CDS datastore interface. Check that CDS is installed properly."
	exit 1
fi

USERNAME=`${DATASTORE} subst "$username"`
HOST=`${DATASTORE} subst "$hostname"`
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

export ASPERA_SCP_PASS=$PASSWORD

if [ "$cf_media_file" != "" ]; then
	ascp --host=$HOST --user=$USERNAME --mode=send $EXTRAFLAGS $cf_media_file $REMOTEPATH/$UPLOAD_MEDIA
fi

if [ "$cf_meta_file" != "" ]; then
	ascp --host=$HOST --user=$USERNAME --mode=send $EXTRAFLAGS $cf_meta_file $REMOTEPATH/$UPLOAD_META
fi

if [ "$cf_inmeta_file" != "" ]; then
	ascp --host=$HOST --user=$USERNAME --mode=send $EXTRAFLAGS $cf_inmeta_file $REMOTEPATH/$UPLOAD_INMETA
fi

if [ "$cf_xml_file" != "" ]; then
	ascp --host=$HOST --user=$USERNAME --mode=send $EXTRAFLAGS $cf_xml_file $REMOTEPATH/$UPLOAD_XML
fi

CODE=$?
rm -f $FLAGFILE

if [ "$CODE" != "0" ]; then
       echo -FATAL: Aspera encountered an error $? uploading the media file.
       exit 1
fi

echo +SUCCESS: Aspera upload completed successfully.
exit 0
