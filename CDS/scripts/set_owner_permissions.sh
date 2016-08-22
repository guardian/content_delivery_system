#!/bin/bash

#This CDS method sets the owner, group or permissions of the given file(s)
#Arguments:
# <take-files>{media|inmeta|meta|xml} - which file(s) to act on
# <new_user>blah [OPTIONAL] - user name or numeric ID to change to
# <new_group>blah [OPTIONAL] - group name or numeric ID to change to
# <new_permissions>0774 [OPTIONAL] - octal permissions mask to set
#END DOC

DATASTORE_ACCESS="/usr/local/bin/cds_datastore"

if [ "${new_user}" != "" ]; then
	REAL_USER=`${DATASTORE_ACCESS} subst "${new_user}" | sed 's/"//' | sed 's/;//'`
	echo "INFO: Changing owner to ${REAL_USER}"
	
	if [ "${cf_media_file}" != "" ]; then
		chown "${REAL_USER}" "${cf_media_file}"
	fi
	if [ "${cf_inmeta_file}" != "" ]; then
		chown "${REAL_USER}" "${cf_inmeta_file}"
	fi
	if [ "${cf_meta_file}" != "" ]; then
		chown "${REAL_USER}" "${cf_meta_file}"
	fi
	if [ "${cf_xml_file}" != "" ]; then
		chown "${REAL_USER}" "${cf_xml_file}"
	fi
fi

if [ "$?" != "0" ]; then
	echo "-ERROR: Unable to change owner"
	exit 1
fi

if [ "${new_group}" != "" ]; then
	REAL_GROUP=`${DATASTORE_ACCESS} subst "${new_group}" | sed 's/"//' | sed 's/;//'`
	echo "INFO: Changing group to ${REAL_GROUP}"
	
	if [ "${cf_media_file}" != "" ]; then
		chgrp "${REAL_GROUP}" "${cf_media_file}"
	fi
	if [ "${cf_inmeta_file}" != "" ]; then
		chgrp "${REAL_GROUP}" "${cf_inmeta_file}"
	fi
	if [ "${cf_meta_file}" != "" ]; then
		chgrp "${REAL_GROUP}" "${cf_meta_file}"
	fi
	if [ "${cf_xml_file}" != "" ]; then
		chgrp "${REAL_GROUP}" "${cf_xml_file}"
	fi
fi

if [ "$?" != "0" ]; then
	echo "-ERROR: Unable to change group"
	exit 1
fi

if [ "${new_perms}" != "" ]; then
	REAL_PERMS=`${DATASTORE_ACCESS} subst "${new_perms}" | sed 's/"//' | sed 's/;//'`
	echo "INFO: Changing group to ${REAL_PERMS}"
	
	if [ "${cf_media_file}" != "" ]; then
		chmod "${REAL_PERMS}" "${cf_media_file}"
	fi
	if [ "${cf_inmeta_file}" != "" ]; then
		chmod "${REAL_PERMS}" "${cf_inmeta_file}"
	fi
	if [ "${cf_meta_file}" != "" ]; then
		chmod "${REAL_PERMS}" "${cf_meta_file}"
	fi
	if [ "${cf_xml_file}" != "" ]; then
		chmod "${REAL_PERMS}" "${cf_xml_file}"
	fi
fi

if [ "$?" != "0" ]; then
	echo "-ERROR: Unable to change permissions"
	exit 1
fi

echo "+SUCCESS: Requested attributes changed."
exit 0
