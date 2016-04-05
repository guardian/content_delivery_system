#!/bin/bash

#This script is a quick CDS method to run the ffmpeg2theora program to generate .ogv video
#NOTE: ffmpeg2theora is not compatible with e.g. ProRes.  This methid will fail if the media file is not in a compatible format.
#OGGV should be considered a legacy format.

VERSION="$Rev: 714 $ $LastChangedDate: 2014-01-29 10:47:10 +0000 (Wed, 29 Jan 2014) $"

#Arguments:
#<take-files>media
#<videoqual>n - 'video quality' number (6-8 recommended)
#<audioqual>n - 'audio quality' number (3-4 recommended)
#<width>n - encode to this frame width
#<height>n - encode to this frame height
#<output_path>/path/to/output - output the encoded file to this local directory
# OR <preset>{preview|pro|videobin|padma|padma-stream} - select a builtin preset
#<suffix>_filesuffix - append this suffix to the filename as it's generated.
#END DOC

echo WARNING - ffmpeg2theora may not support all incoming files correctly.  It\'s recommended to use another transcoder to mp4/h.264 first and then run this method.

#FIXME - should sanitize arguments really

F2T_BIN="/usr/local/bin/ffmpeg2theora"
if [ ! -x "${F2T_BIN}" ]; then
	echo Could not find ${F2T_BIN} or it is not executable.  Please ensure that you have installed ffmpeg2theora before trying to use this method.
	echo You should be able to find it at http://v2v.cc/~j/ffmpeg2theora/
	exit 1
fi

DATASTORE_ACCESS="/usr/local/bin/cds_datastore"

F2T_ARGS=""
if [ "${videoqual}" != "" ]; then
	F2T_ARGS+="-v `${DATASTORE_ACCESS} subst "${videoqual}"` "
fi

if [ "${audioqual}" != "" ]; then
	F2T_ARGS+="-a `${DATASTORE_ACCESS} subst "${audioqual}"` "
fi

if [ "${preset}" != "" ]; then
	F2T_ARGS+="-p `${DATASTORE_ACCESS} subst "${preset}"` "
fi

if [ "${width}" != "" ]; then
        REAL_WIDTH=`${DATASTORE_ACCESS} subst "${width}"`
	F2T_ARGS+="-x ${REAL_WIDTH} "
fi

if [ "${height}" != "" ]; then
        REAL_HEIGHT=`${DATASTORE_ACCESS} subst "${height}"`
        F2T_ARGS+="-y ${REAL_HEIGHT} "
fi

if [ "${suffix}" != "" ]; then
	REAL_SUFFIX=`${DATASTORE_ACCESS} subst "${suffix}"`
fi

REAL_OUTPUT_PATH=`${DATASTORE_ACCESS} subst "${output_path}"`
FILENAME=`basename "${cf_media_file}"`
OUTPUT_FILENAME=`echo ${FILENAME} | sed -E s/\\.\[^\\.\]+$//`
FINAL_OUTPUT="${REAL_OUTPUT_PATH}/${OUTPUT_FILENAME}${REAL_SUFFIX}.ogv"

echo Executing ${F2T_BIN} ${F2T_ARGS} "${cf_media_file}" -o "${FINAL_OUTPUT}"
${F2T_BIN} ${F2T_ARGS} ${cf_media_file} -o ${FINAL_OUTPUT}

if [ "$?" == "1" ]; then
        #return code of 1 => ffmpeg2theora failed
        echo
        echo -ERROR: ffmpeg2theora failed for some reason, hopefully there is a clue in the CDS log.
        exit 1
fi

echo INFO: Outputting encoding location to ${cf_temp_file}

echo cf_media_file=${FINAL_OUTPUT} > ${cf_temp_file}
exit 0

