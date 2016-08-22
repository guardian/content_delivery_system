#!/bin/bash

VERSION="$Rev: 515 $ $LastChangedDate: 2013-09-24 13:18:15 +0100 (Tue, 24 Sep 2013) $"
#This CDS method simply concatenates the given line(s) of text into the provided file
#Substitutions are not only welcomed but encouraged
#
#<text>blah - append this text.  Substitutions are allowed.
#<output_file>	}
#<file>			} the file path to output to. Substitutions are allowed.
#END DOC

DATASTORE_ACCESS="/usr/local/bin/cds_datastore"

REAL_TEXT=`${DATASTORE_ACCESS} subst "${text}"`

if [ "${output_file}" != "" ]; then
	REAL_FILE=`${DATASTORE_ACCESS} subst "${output_file}"`
fi

if [ "${file}" != "" ]; then
	REAL_FILE=`${DATASTORE_ACCESS} subst "${file}"`
fi

if [ "${REAL_FILE}" == "" ]; then
	echo You must specify <output_file> in the CDS route
	exit 1
fi

echo ${REAL_TEXT} >> "${REAL_FILE}"
