#!/bin/bash

VERSION="$Rev: 651 $ $LastChangedDate: 2014-01-01 16:57:45 +0000 (Wed, 01 Jan 2014) $"

# Sends a notification email to the addresses listed in the <recipients> argument using the sendmail program.
# this script expects the following arguments (substitutions are allowed in ALL except date_format:
#   <recipients> - list of email addresses to send to
#   <message> - text of message OR
#   <message-file> - file which contains text of the message to send.  Normal substitutions are
#  valid both in the file name AND in the file contents.
#   <from> - email address to appear to be from
#   <subject> - subject line of email
#   <date_format> - format to include date.
#END DOC

echo MESSAGE: email_notify.sh invoked 

DATE_VAL=`date +"$date_format"`
DATE_VAL=`echo $DATE_VAL | sed s:/:\\\\\\\\/:g`
#echo Got date $DATE_VAL
#echo Got subject $subject, file $cf_media_file

subject=`echo $subject | sed "s/{date}/$DATE_VAL/g"`
message=`echo $message | sed "s/{date}/$DATE_VAL/g"`

#SAFE_FILE=`echo $cf_media_file | rev | cut -d / -f 1 | rev`
#SAFE_FILE=`echo $SAFE_FILE | sed s:/:\\\\\\\\/:g`
SAFE_FILE=`echo $SAFE_FILE | sed s:/:\\\\\\\\/:g`


#ENVIRO=`set`
datastore=`which cds_datastore.pl`
if [ "${datastore}" == "" ]; then
	echo -ERROR: Unable to locate datastore interface cds_datastore.pl.  Trying default location...
	datastore=/usr/local/bin/cds_datastore.pl
fi

if [ ! -x ${datastore} ]; then
	echo -ERROR: Unable to locate datastore interface cds_datastore.pl
	exit 1;
fi

if [ "${message_file}" != "" ]; then
#	message-file=${message_file};
#fi

#if [ "${message-file}" != "" ]; then
	echo INFO: Using message payload from file ${message_file}
	message=`cat "${message_file}"`
	message=`echo $message | sed "s/{recipients}/$recipients/"`;
	message=`echo $message | sed "s/{from}/$from/"`;
	message=`echo $message | sed "s/{subject}/$subject/"`;
fi

#all substitutions are now done centrally in the datastore, including {last-error} etc.
#this means we can use {meta:*} et. al.  Also new substitution {route-name}
subject=`${datastore} subst "${subject}"`;
message=`${datastore} subst "${message}"`;
recipients=`${datastore} subst "${recipients}"`;

echo $message

#exit 1

/usr/sbin/sendmail $recipients << EOF
From: $from
Subject: $subject
$message
EOF

RTN=$?
echo +SUCCESS: Notification email sent to $recipients

exit ${RTN}

