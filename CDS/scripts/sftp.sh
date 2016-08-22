#!/bin/bash
# This module uploads files to a server via secure FTP.
# In order to use this, you must generate a public/private key pair and send the public half
# to the content partner you wish to upload to.  You then specify the path to the private half
# in the <key> parameter to this method.
#
# It assumes that you have SFTP, SSH and SSL installed and working.
#
#Arguments:
# <host>sftp.hostname.com - upload to this server 
# <username>blah - log in with this username 
# <key>/path/to/privatekeyfile - use this private key to log into the server 
# <remote_path>/path/to/upload/ -  change to this directory to upload the file. Should end with a /.
# <use_dated_folder/> [OPTIONAL] - append todays date/time to the remote_path setting when creating a folder and uploading. This is required by many providers.  NOTE: to work properly you should generally ensure that remote_path ends with a /.
# <date_format>%Y%m%d_%H%M%S [OPTIONAL] - use this format for the date/time provided by use_dated_folder.  The flags are in the format required by the standard UNIX "date" utility.  See http://unixhelp.ed.ac.uk/CGI/man-cgi?date for more information.
# <port>22 [OPTIONAL] - connect to this port number for the sftp service (default 22)
# <send_flag_file/> [OPTIONAL] - many providers using SFTP require the delivery of an empty "flag" file to signify that the delivery is complete.  Specify this option to upload a blank file once all files have been sent.
# <flag_file_name>blah [OPTIONAL] [supports media-file and date substitutions]
# <extra_files>/path/to/file1|/path/to/file2|/path/to/{meta:randomfilename}|... [OPTIONAL] - upload these files in the delivery as well.
#END DOC

VERSION="$Rev: 1220 $ $LastChangedDate: 2015-05-16 12:39:03 +0100 (Sat, 16 May 2015) $"

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
if [ "$HOST" == "" ]; then HOST=$hostname; fi
REMOTEPATH=`${DATASTORE} subst "${remote_path}"`
PRIVATEKEY=`${DATASTORE} subst "${key}"`
if [ "${debug}" != "" ]; then
	EXTRAFLAGS="-vv"
else
	EXTRAFLAGS=""
fi

#end configurable settings

DATE=`date "+${date_format}"`

echo Media file: ${cf_media_file}
echo XML file: ${cf_xml_file}
echo InMeta file: ${cf_inmeta_file}
echo Meta file: ${cf_meta_file}

if [ "${port}" != "" ]; then
	PORTOPTS="-o Port=`${DATASTORE} subst ${port}`"
	if [ "${debug}" != "" ]; then
		echo Using port number ${port} instead of 22.
	fi
fi

if [ "${use_dated_folder}" != "" ]; then
	#if we've been asked to use a dated folder, work out what it is and then create the directory.
	REMOTEPATH="$REMOTEPATH$DATE"

	sftp -b - -o "IdentityFile $PRIVATEKEY" $PORTOPTS $USERNAME@$HOST << EOC
-mkdir "$REMOTEPATH"
quit
EOC
	if [ "$?" != "0" ]; then
		echo -FATAL: SFTP encountered an error setting up the dated folder.
		exit 1
	fi
	#since we set $REMOTEPATH, all of the commands below will now point to the new directory.
fi

if [ "$cf_media_file" != "" ]; then
	FILE_ONLY=`echo $cf_media_file | rev | cut -d / -f 1 | rev`
	UPLOAD_MEDIA="put \"$cf_media_file\" \"$REMOTEPATH/$FILE_ONLY\""
fi

if [ "$cf_meta_file" != "" ]; then
      FILE_ONLY=`echo $cf_meta_file | rev | cut -d / -f 1 | rev`
	UPLOAD_META="put \"$cf_meta_file\" \"$REMOTEPATH/$FILE_ONLY\""
fi

if [ "$cf_inmeta_file" != "" ]; then	
        FILE_ONLY=`echo $cf_inmeta_file | rev | cut -d / -f 1 | rev`
	UPLOAD_INMETA="put \"$cf_inmeta_file $REMOTEPATH/$FILE_ONLY\""
fi

if [ "$cf_xml_file" != "" ]; then
        FILE_ONLY=`echo $cf_xml_file | rev | cut -d / -f 1 | rev`	
	UPLOAD_XML="put \"$cf_xml_file\" \"$REMOTEPATH/$FILE_ONLY\""
fi

#note - can array split like this: IFS='|'; for x in `echo "test one|test_two|testthree"`; do echo $x; done
EXTRAFILES=`${DATASTORE} subst "${extra_files}"`
if [ "${EXTRAFILES}" != "" ]; then
	IFS='|'
	for f in "${EXTRAFILES}"; do
		echo "INFO: extra files processing adding file ${f} to list..."
		UPLOAD_EXTRA=`echo -e "${UPLOAD_EXTRA}\\n${f}"`
	done
	if [ "${debug}" != "" ]; then
		echo UPLOAD_EXTRA is ${UPLOAD_EXTRA}
	fi
fi

if [[ ! -z ${send_flag_file} ]]; then
	#FLAGFILE="/var/tmp/${flag_file_name}"
	#ensure that the flag file is unique in our file system, in case
	#we have more than one instance running.
	FLAGFILE="/var/tmp/`mktemp cds_XXXXXX`"
	FINALNAME=`echo ${flag_file_name} | sed "s/{date}/$DATE/"`
	MEDIA_NAME_ONLY=`basename "${cf_media_file}"`
	#FINALNAME=`echo $FINALNAME | sed "s/{media-file}/$MEDIA_NAME_ONLY/"`
	FINALNAME=`${DATASTORE} subst "${FINALNAME}"`
	touch $FLAGFILE
	UPLOAD_FLAGFILE="put \"$FLAGFILE\" \"$REMOTEPATH/$FINALNAME\""
fi

sftp $EXTRAFLAGS -b - -o "IdentityFile $PRIVATEKEY" $PORTOPTS $USERNAME@$HOST << EOC
$UPLOAD_MEDIA
$UPLOAD_XML
$UPLOAD_META
$UPLOAD_INMETA
$UPLOAD_EXTRA
$UPLOAD_FLAGFILE
quit

EOC

CODE=$?
rm -f $FLAGFILE

if [ "$CODE" != "0" ]; then
       echo -FATAL: SFTP encountered an error $? uploading the media file.
       exit 1
fi

echo +SUCCESS: SFTP upload completed successfully.
exit 0
