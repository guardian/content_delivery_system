#!/bin/bash

VERSION="$Rev: 472 $ $LastChangedDate: 2013-08-14 14:25:30 +0100 (Wed, 14 Aug 2013) $"

#This script uploads the given file(s) to a Windows SMB/CIFS server suing smbclient.
#See man smbclient for more details.
#
#It expects:
#host - the Windows/SMB server name
#share - the Windows share name
#username - username to log in as
#password - password for the user
#remote_path - path to upload files to
#domain [optional] - domain name to log in to
#port [optional] - port to connect to
#resolve-order [optional] - order to use for name resolution.  Passed unchecked to -R option.
#ip-address [optional] - IP address of server in case we can't resolve the server name.

if [ "$host" == "" ]; then
	echo You must supply a host name to connect to.
	exit 1
fi

if [ "$share" == "" ]; then
        echo You must supply a share name to connect to.
        exit 1
fi

if [ "$username" == "" ]; then
        echo You must supply a user name.
        exit 1
fi

if [ "$password" == "" ]; then
        echo You must supply a password.
        exit 1
fi

#set up auth file, so we don't need to pass passwords on the commandline
AUTHFILE=`mktemp /tmp/cds_XXXXXX`
chmod 0600 "$AUTHFILE"
echo username=$username >> $AUTHFILE
echo password=$password >> $AUTHFILE
if [ "$domain" != "" ]; then
	echo domain=$domain >> $AUTHFILE
fi

if [ "$ip_address" != "" ]; then
	EXTRA_ARGS="$EXTRA_ARGS -I $ip_address"
fi

if [ "$port" != "" ]; then
       EXTRA_ARGS="$EXTRA_ARGS -p $port"
fi  

if [ "$resolve_order" != "" ]; then
        EXTRA_ARGS="$EXTRA_ARGS -R $resolve_order"
fi

if [ "$cf_media_file" != "" ]; then
	FILE_ONLY=`echo $cf_media_file | rev | cut -d / -f 1 | rev`
	UPLOAD_MEDIA="put \"$cf_media_file\" $remote_path/$FILE_ONLY"
fi

if [ "$cf_meta_file" != "" ]; then
      FILE_ONLY=`echo $cf_meta_file | rev | cut -d / -f 1 | rev`
	UPLOAD_META="put \"$cf_meta_file\" $remote_path/$FILE_ONLY"
fi

if [ "$cf_inmeta_file" != "" ]; then	
        FILE_ONLY=`echo $cf_inmeta_file | rev | cut -d / -f 1 | rev`
	UPLOAD_INMETA="put \"$cf_inmeta_file\" $remote_path/$FILE_ONLY"
fi

if [ "$cf_xml_file" != "" ]; then
        FILE_ONLY=`echo $cf_xml_file | rev | cut -d / -f 1 | rev`	
	UPLOAD_XML="put \"$cf_xml_file\" $remote_path/$FILE_ONLY"
fi

smbclient "//$host/$share" -A "$AUTHFILE" $EXTRA_ARGS << EOF
$UPLOAD_MEDIA
$UPLOAD_XML
$UPLOAD_META
$UPLOAD_INMETA
exit
EOF

CODE=$?

rm -f "$AUTHFILE"

if [ "$CODE" != "0" ]; then
	echo A problem occurred uploading the files.  See above log trace for details - check that the login credentials are correct. 
	exit $CODE
fi

exit 0

