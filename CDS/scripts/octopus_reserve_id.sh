#!/bin/bash
#This script uses the "allocateoctopusid" command supplied by David Blishen on 17/1/13
#to create a valid Octopus ID and output it to the datastore.
#Said Octopus ID is deleted again in the Octopus system, so no data is associated with it,
#but it is "reserved" in that it will not be used for anything else
#and therefore can safely be used to key the R2 API
#
#It checks for a valid config file before running.
#Arguments:
# <output_key>blah [optional] - output the provided ID to this key in the meta section
#							of the datastore.  Default: "octopus ID".
# <no_overwrite/> - do not set a new Octopus ID if one already exists.
#END DOC

VERSION="$Rev: 651 $ $LastChangedDate: 2014-01-01 16:57:45 +0000 (Wed, 01 Jan 2014) $"

#CONFIGURABLE PART
OCTCMD=/usr/local/bin/allocateoctopusid
DATASTORE=/usr/local/bin/cds_datastore.pl

REQUIREDCONFIG=/Library/Preferences/GNL/octopus.cfg

#END CONFIG

if [ ! -x "${OCTCMD}" ]; then
	echo -FATAL: Unable to find the Octopus tool ${OCTCMD}
	exit 1
fi

if [ ! -f "${REQUIREDCONFIG}" ]; then
	echo -FATAL: Unable to locate configuration file ${REQUIREDCONFIG} which is required by the Octopus tools.
	exit 1
fi

if [ "${output_key}" == "" ]; then
	output_key="octopus ID"
fi

if [ "${no_overwrite}" != "" ]; then
	echo INFO: Checking to see if '${output_key}' is already set...
	CURRENTVALUE=`"${DATASTORE}" get meta "${output_key}"`
	if [ "${CURRENTVALUE}" != "" ]; then
		echo "+SUCCESS: Not overwriting existing value of ${CURRENTVALUE} for ${output_key}"
		exit 0
	fi
fi

NEWID=`"${OCTCMD}"`
echo INFO: Allocated octopus ID ${NEWID}
echo Outputting to datastore key meta:${output_key}
"${DATASTORE}" set meta "${output_key}" ${NEWID}

echo +SUCCESS: Succesfully allocated octopus ID
exit 0
