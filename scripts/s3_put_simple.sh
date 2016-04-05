#!/bin/bash

#VERSION=$Rev: 595 $ $LastChangedDate: 2013-11-28 18:47:10 +0000 (Thu, 28 Nov 2013) $

#This script is a fairly simple CDS method to upload files using the s3cmd utility
#You should set up the s3cmd utility config file before running this method
#by running s3cmd --configure from the Terminal.  Otherwise it will fail because it does not
#have the relevant login keys available.
#
#You have the option to specify an alternate configuration file in the route, to support multiple
#configurations
#
#Arguments:
# <take-files>{media|meta|inmeta|xml} - upload these files
# <bucket> bucketname				- upload to this S3 bucket
# <upload_path>/upload/path/in/bucket [optional] - upload to this path within the bucket
#
# <config_file>/path/to/config	[optional]- use this config file for s3cmd
# <dry_run/>	[optional]			- runs s3cmd with the --dry-run option
# <encrypt/>	[optional]			- runs s3cmd with the --encrypt option
# <force/>		[optional]			- runs s3cmd with the --force option
# <recursive/>	[optional]			- runs s3cmd with the --recursive option
# <acl_public/>	[optional]			- runs s3cmd with the --acl-public option
# <acl_private/> [optional]			- runs s3cmd with the --acl-private option
# <mime_type>type [optional]		- tell s3cmd that the objects to upload have this MIME type
# <verbose/>	[optional]			- tell s3cmd to be verbose
# <follow_symlinks/> [optional]		- tell s3cmd to follow symlinks as files

#END DOC

#configurable parameters
DATASTORE_ACCESS=/usr/local/bin/cds_datastore.pl
S3CMD=/opt/local/bin/s3cmd
#end configurable parameters

function do_upload() {
	echo I will run ${S3CMD} ${S3_OPTS} put "$1" "s3://${S3_BUCKET}/${S3_PATH}/`basename "$1"`"
	TEMPFILE=`mktemp -t s3_put_simple`
	${S3CMD} ${S3_OPTS} put "$1" "s3://${S3_BUCKET}/${S3_PATH}/`basename "$1"`" | tee ${TEMPFILE}
	grep -e "^ERROR:" ${TEMPFILE}
	if [ "$?" == "0" ]; then
		HAD_ERROR=1
		echo "-ERROR: Problem uploading to S3"
	else
		SUCCESSFUL=$[SUCCESSFUL + 1]
	fi
}

#START MAIN
S3_BUCKET=`${DATASTORE_ACCESS} subst "${bucket}"`
S3_PATH=`${DATASTORE_ACCESS} subst "${upload_path}"`

if [ "${dry_run}" != "" ]; then
	S3_OPTS="${S3_OPTS} --dry-run"
fi
if [ "${encrypt}" != "" ]; then
	S3_OPTS="${S3_OPTS} --encrypt"
fi
if [ "${force}" != "" ]; then
	S3_OPTS="${S3_OPTS} --force"
fi
if [ "${recursive}" != "" ]; then
	S3_OPTS="${S3_OPTS} --recursive"
fi
if [ "${acl_public}" != "" ]; then
	S3_OPTS="${S3_OPTS} --acl-public"
fi
if [ "${acl_private}" != "" ]; then
	S3_OPTS="${S3_OPTS} --acl-private"
fi
if [ "${mime_type}" != "" ]; then
	REAL_MIME=`${DATASTORE_ACCESS} subst "${mime_type}"`
	S3_OPTS="${S3_OPTS} --mime-type=${REAL_MIME}"
fi
if [ "${verbose}" != "" ]; then
	S3_OPTS="${S3_OPTS} --verbose"
fi
if [ "${follow_symlinks}" != "" ]; then
	S3_OPTS="${S3_OPTS} --follow-symlinks"
fi

S3_OPTS="${S3_OPTS} --progress"

if [ "${cf_media_file}" != "" ]; then
	do_upload "${cf_media_file}"
fi

if [ "${cf_meta_file}" != "" ]; then
	do_upload "${cf_meta_file}"
fi

if [ "${cf_inmeta_file}" != "" ]; then
	do_upload "${cf_inmeta_file}"
fi

if [ "${cf_xml_file}" != "" ]; then
	do_upload "${cf_xml_file}"
fi

echo Main uploads done.

if [ "${extra_files}" != "" ]; then
	echo Uplading extra files list "${extra_files}"...
	IFS=\|
	for x in "${extra_files}"; do
		TO_UPLOAD=`${DATASTORE_ACCESS} subst "$x"`
		do_upload "${TO_UPLOAD}"
	done
fi

if [ "${HAD_ERROR}" == "1" ]; then
	echo "-ERROR: Some files failed to upload to S3.  Consult the log for more details."
	exit 1
fi

if [ "${SUCCESSFUL}" == "0" ]; then
	echo "-ERROR: No files were uploaded.  This is possibly because none were specified."
	exit 0
fi

echo "+SUCCESS: No upload errors have been reported"
exit 0
