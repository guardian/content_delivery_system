#!/bin/bash

VERSION="$Rev: 472 $ $LastChangedDate: 2013-08-14 14:25:30 +0100 (Wed, 14 Aug 2013) $"

#This is a simple CDS method to delete a given file.
#
# <delete_file>filename - delete this file (substitutions accpted)
#

DATASTORE_ACCESS="/usr/local/bin/cds_datastore"

echo CDS method delete_file invoked

TO_DELETE=`${DATASTORE_ACCESS} subst "${delete_file}"`

if [ ! -f "${TO_DELETE}" ]; then
	echo Requested file to delete ${TO_DELETE} does not exist.
	exit 1
fi

echo Deleting file ${TO_DELETE}
rm -f "${TO_DELETE}"
exit $?

