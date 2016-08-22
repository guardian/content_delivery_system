#!/bin/bash

#Tsunami is an open-source data transfer accellerator (kinda like Aspera), using UDP techniques to overcome latency issues on long-distance transfers
# http://tsunami-udp.sourceforge.net/
#
#This method allows us to use the client program to pull a specified file from the server
#The control protocol does not allow us to investigate what files are actually there, the file name must be specified explicity.  A 'file not found' error is returned if the file does not exist.
#
#Arguments (all support substitutions):
# <host>hostname.domain.com - connect to this host or IP address
# <port>nnn [OPTIONAL] - use this port number (default 46224) - NOT IMPLEMENTED YET
# <filename>blah - pull this specific file.  Bulk pulling is not possible because of the way the protocol works.
# <cache_path>/path/to/save/file [OPTIONAL] - Output the downloaded file to this location in the filesystem
# <set_media/> [OPTIONAL] - Set the downloaded file to be the current media file
# <md5sum/> [OPTIONAL] - Calculate an MD5 checksum of the downloaded file and output it to the data store
#END DOC

TSUNAMI_CLIENT=`which tsunami`
if [ ! -x "${TSUNAMI_CLIENT}" ]; then
	echo Tsunami client program does not appear to be installed or is not in the PATH. Either download and install Tsunami from http://tsunami-udp.sourceforge.net/ or ensure that /usr/local/bin is in the PATH specifier for account ID ${UID}.
	exit 1
fi

DATASTORE="/usr/local/bin/cds_datastore.pl"

if [ "${host}" == "" ]; then
	echo You need to specify which host to connect to by defining "host" in the route file.
	exit 1
fi

REALHOST=`"${DATASTORE}" subst "${host}"`

if [ "${filename}" == "" ]; then
	echo You need to specify which file to download by defining "file" in the route file.
	exit 1
fi

REALFILE=`"${DATASTORE}" subst "${filename}"`

if [ "${cache_path}" != "" ]; then
	REALCACHE=`"${DATASTORE}" subst "${cache_path}"`
	echo "Changing to download directory '${REALCACHE}'..."
	cd "${REALCACHE}"
fi

echo Attempting to download file \'${REALFILE}\' from Tsunami server \'${REALHOST}\'...

#fire up the client program...
${TSUNAMI_CLIENT} << EOF
connect ${REALHOST}
get ${REALFILE}
exit
EOF

#tsunami client always seems to return an exit code of 1. grrr.
RTN=$?
if [ ${RTN} -ne 1 ]; then
	echo -ERROR: Tsunami client returned ${RTN}.
	exit 1
fi

if [ "${REALCACHE}" == "" ]; then
	OUTPATH=`basename "${REALFILE}"`
else
	OUTPATH=${REALCACHE}/`basename "${REALFILE}"`
fi

echo +SUCCESS: File downloaded to ${OUTPATH}.

if [ "${set_media}" != "" ]; then
	echo Outputting downloaded file location as new media file for the route...
	echo cf_media_file=${OUTPATH} >> ${cf_temp_file}
fi

