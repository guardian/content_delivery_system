#!/bin/bash

VERSION="$Rev: 517 $ $LastChangedDate: 2013-10-07 12:07:00 +0100 (Mon, 07 Oct 2013) $"

#This script is a really simple CDS method to encode a video into WebM.  All arguments accept substitutions.
#Arguments:
#<take-files> media - use the media file.  This method does not affect other file types.
#<output_path>blah - directory to output to (it sets cf_media_file to the transcoded file on output) - substitutions allowed
#<frame_size>{width}x{height} - frame size to output at
#<video_bitrate>{rate}k - maximum bitrate, e.g. 1024k
#<audio_bitrate>{rate}k - bitrate, e.g. 128k
#<ratefactor>n - the CRF value.  Can be from 4-63, lower values mean better quality. Defaults to 10.
#<filename_append>name - append this string to the filename.  The string is appended directly so if you want e.g. _ padding, type it in the string. Substitutions allowed.  Useful for Episode Engine compatibility
#<two_pass/> - use two-pass encoding mode
#<ffmpeg_preset>blah [OPTIONAL] - use this file (under /usr/local/share/ffmpeg; not including the .ffpreset file extension) as a preset. Defaults to libvpx-720p

#END DOC

DATASTORE_ACCESS="/usr/local/bin/cds_datastore"
FFMPEG="/usr/local/bin/ffmpeg"

#FFMPEG_EXTRA_OPTS="-filter:v yadif"

if [ "${ratefactor}" == "" ]; then
	ratefactor=10
fi

REAL_OUTPUT_PATH=`${DATASTORE_ACCESS} subst "${output_path}"`
REAL_FRAME_SIZE=`${DATASTORE_ACCESS} subst "${frame_size}"`
REAL_VIDEO_BITRATE=`${DATASTORE_ACCESS} subst "${video_bitrate}"`
REAL_AUDIO_BITRATE=`${DATASTORE_ACCESS} subst "${audio_bitrate}"`
REAL_RATEFACTOR=`${DATASTORE_ACCESS} subst "${ratefactor}"`
REAL_FILENAME_APPEND=`${DATASTORE_ACCESS} subst "${filename_append}"`
FILENAME=`basename "${cf_media_file}"`

if [ "${filename_append}" != "" ]; then
	OUTPUT_FILENAME=`echo ${FILENAME} | sed -E s/\\.\[^\\.\]+$/${REAL_FILENAME_APPEND}.webm/`
else
	OUTPUT_FILENAME=`echo ${FILENAME} | sed -E s/\\.\[^\\.\]+$/.webm/`
fi

if [ "${ffmpeg_preset}" != "" ]; then
	REAL_FFMPEG_PRESET=`${DATASTORE_ACCESS} subst "${ffmpeg_preset}"`
else
	REAL_FFMPEG_PRESET=libvpx-720p
fi

FINAL_OUTPUT="${REAL_OUTPUT_PATH}/${OUTPUT_FILENAME}"

if [ "${two_pass}" != "" ]; then
	echo FIRST PASS - Encoding ${cf_media_file} to webM at ${REAL_FRAME_SIZE} ${REAL_VIDEO_BITRATE} video and ${audio_bitrate} audio into ${FINAL_OUTPUT}

	PASSLOGFILE=`basename ${cf_media_file}`
	PASSLOGFILE="/tmp/${PASSLOGFILE}_2passlog"
	${FFMPEG} -i "${cf_media_file}" ${FFMPEG_EXTRA_OPTS} -s ${REAL_FRAME_SIZE} -vpre ${REAL_FFMPEG_PRESET} -b:v ${REAL_VIDEO_BITRATE} -crf ${REAL_RATEFACTOR} -an -pass 1 -passlogfile "${PASSLOGFILE}" -auto-alt-ref -f webm -y "${FINAL_OUTPUT}" 2>&1
	echo
	echo SECOND PASS - Encoding ${cf_media_file} to webM 
	${FFMPEG} -i "${cf_media_file}" ${FFMPEG_EXTRA_OPTS} -s ${REAL_FRAME_SIZE} -vpre ${REAL_FFMPEG_PRESET} -b:v ${REAL_VIDEO_BITRATE} -crf ${REAL_RATEFACTOR} -pass 2 -passlogfile "${PASSLOGFILE}" -auto-alt-ref -acodec libvorbis -ab ${REAL_AUDIO_BITRATE} -ac 2 -f webm -y "${FINAL_OUTPUT}" 2>&1
else
	echo Encoding ${cf_media_file} to webM at ${REAL_FRAME_SIZE} ${video_bitrate} video and ${audio_bitrate} audio into ${FINAL_OUTPUT}

	${FFMPEG} -i "${cf_media_file}" ${FFMPEG_EXTRA_OPTS} -s ${REAL_FRAME_SIZE} -vpre libvpx-720p -b:v ${REAL_VIDEO_BITRATE} -crf ${REAL_RATEFACTOR} -acodec libvorbis -ab ${REAL_AUDIO_BITRATE} -ac 2 -f webm -y "${FINAL_OUTPUT}" 2>&1
fi

if [ "$?" == "1" ]; then
	#return code of 1 => ffmpeg failed
	echo 
	echo -ERROR: FFMPEG failed for some reason, hopefully there is a clue in the CDS log.
	exit 1
fi

echo INFO: Outputting encoding location to ${cf_temp_file}

echo cf_media_file=${FINAL_OUTPUT} > ${cf_temp_file}
exit 0
