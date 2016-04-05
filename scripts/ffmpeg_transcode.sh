#!/bin/bash

VERSION="$Rev: 1745 $ $LastChangedDate: 2016-03-20 17:51:47 +0000 (Sun, 20 Mar 2016) $"

#Simple method to transcode media using ffmpeg.  You need to ensure that you have ffmpeg installed on your system, and that your version is compatible with the media formats you want encoded.
#Arguments:
# <take-files>media - you need to tell this method to act on the media.
# <output_path>/path/to/output - output the transcoded file to this location.  You must specify this location.  If a file with the given name already exists here, the new file will be given a non-clashing name such as filename-2.mp4.
# <format>formatname - output to the specified file format, e.g. mp4 or webm.  Run ffmpeg -formats from your commandline to see the formats that your ffmpeg supports.  This will also be used as the file extension of the transcoded file.
# <vcodec>videocodec - use the specified video codec to encode.  Run ffmpeg -codecs from your commandline to see the codecs that your ffmpeg supports.
# <acodec>audiocodec - use the specified audio codec to encode.  Run ffmpeg -codecs from your commandline to see the codecs that your ffmpeg supports.
# <scale>widthxheight - scale the output to the given width and height
# <audioonly/> - assume that 'format' is an audio-only format and do not pass video options
# <videofilters> [OPTIONAL] - set of videofilters arguments that are passed to ffmpeg. For more information see https://ffmpeg.org/ffmpeg-filters.html#Video-Filters
# <audiofilters> [OPTIONAL] - set of audiofilters arguments that are passed to ffmpeg. For more information see https://ffmpeg.org/ffmpeg-filters.html#Audio-Filters
# <crf>n [OPTIONAL] - use "constant rate factor" setting for h.264. For more information see https://trac.ffmpeg.org/wiki/Encode/H.264
# <maxrate>4096k [OPTIONAL] - specify a maximum bitrate when using crf and h.264. For more information see https://trac.ffmpeg.org/wiki/Encode/H.264
# <avgrate>4096k [OPTIONAL] - specify target average bitrate. For more information see https://trac.ffmpeg.org/wiki/Encode/H.264
# <minrate>512k [OPTIONAL] - specify a minimum bitrate for h.264. For more information see https://trac.ffmpeg.org/wiki/Encode/H.264
# <priority>n [OPTIONAL] - use "nice" to change the OS priority. A higher value => more "nice" => lower system priority.
# <output_path>/path/to/output - output transcoded media to this location
# <allow_experimental/> [OPTIONAL] - tell ffmpeg that it is allowed to use "experimental" codecs.
# <profile>baseline|main|high [OPTIONAL] - restrict h.264 profile. For more information see https://trac.ffmpeg.org/wiki/Encode/H.264
# <profile_level>3.0|3.1|4.0|4.1|4.2 [OPTIONAL] - use with "profile". Set a specific compatibility level. For more information see https://trac.ffmpeg.org/wiki/Encode/H.264
# <audiocap> [OPTIONAL] - setting to cap the audio frequency to in Hertz (or cycles per a second). Common values for this include 11025, 22050, and 44100. A higher number means higher quality. Note that some codecs only support certain values.
# <quality> [OPTIONAL] - Video quality setting as a number from 1 (highest) to 51 (lowest).

#END DOC
echo ffmpeg_transcode v1.  

MEDIA_FILE=`basename "${cf_media_file}"`
FILE_ONLY=`echo ${MEDIA_FILE} | sed s/\.[^\.]*$//`

temp=`/usr/local/bin/cds_datastore.pl subst "${output_path}"`
if [ ! -d ${temp} ]; then
    echo Requested output path $temp does not exist. Trying to create...
    mkdir -p "$temp"
    if [ "$?" != "0" ]; then
        echo "-ERROR: Unable to create output path $temp, exiting."
        exit 1
    fi
fi

OUTPUT_FILE_PATH="${temp}/${FILE_ONLY}.${format}"
echo Outputting to ${OUTPUT_FILE_PATH}

FFMPEG=`which ffmpeg`

if [ "${FFMPEG}" == "" ]; then
	echo ffmpeg could not be found in the system path.
	exit 1
fi
if [ ! -x ${FFMPEG} ]; then
	echo ${FFMPEG} is not executable.
	exit 1
fi

n=0

while [ -f "${OUTPUT_FILE_PATH}" ]; do
	let n=n+1
	OUTPUT_FILE_PATH="${output_path}/${FILE_ONLY}_$n.${format}"
done

if [ "${cf_media_file}" == "" ]; then
	echo -FATAL: No media file specified to transcode.
	exit 0
fi

echo +MESSAGE: Transcoding $cd_media_file to $OUTPUT_FILE_PATH
echo +MESSAGE: Format: $format
echo +MESSAGE: Video codec: $vcodec
echo +MESSAGE: Audio codec: $acodec
echo +MESSAGE: Frame size: ${scale}
echo +MESSAGE: Video filters: ${videofilters}
echo +MESSAGE: Audio filters: ${audiofilters}
echo +MESSAGE: Rate factor: ${crf}
echo +MESSAGE: Maximum bitrate: ${maxrate}
echo +MESSAGE: Average bitrate: ${avgrate}
echo +MESSAGE: Minimum bitrate: ${minrate}
echo +MESSAGE: Video quality: ${quality}
echo +MESSAGE: Audio cap: ${audiocap}
echo +MESSAGE: Profile restriction: ${profile}
echo +MESSAGE: Profile level: ${profile_level}

# -y means "always over-write output files"
vidoptions=""
audoptions=""

scale=`/usr/local/bin/cds_datastore.pl subst ${scale}`

if [ "${priority}" == "" ]; then
	priority=0
fi

if [ "${audioonly}" == "" ]; then
	vidoptions="-vcodec ${vcodec} -s ${scale}"
fi

if [ "${crf}" != "" ]; then
	temp=`/usr/local/bin/cds_datastore.pl subst ${crf}`
	vidoptions="${vidoptions} -crf ${temp}"
fi

if [ "${maxrate}" != "" ]; then
	temp=`/usr/local/bin/cds_datastore.pl subst ${maxrate}`
	vidoptions="${vidoptions} -maxrate ${temp}"
fi

if [ "${minrate}" != "" ]; then
	temp=`/usr/local/bin/cds_datastore.pl subst ${minrate}`
	vidoptions="${vidoptions} -minrate ${temp}"
fi

if [ "${avgrate}" != "" ]; then
	temp=`/usr/local/bin/cds_datastore.pl subst ${avgrate}`
	vidoptions="${vidoptions} -b:v ${temp}"
fi

if [ "${videofilters}" != "" ]; then
	temp=`/usr/local/bin/cds_datastore.pl subst ${videofilters}`
	vidoptions="${vidoptions} -vf ${temp}"
fi

if [ "${profile}" != "" ]; then
	temp=`/usr/local/bin/cds_datastore.pl subst ${profile}`
	vidoptions="${vidoptions} -profile ${temp}"
fi

if [ "${profile_level}" != "" ]; then
	temp=`/usr/local/bin/cds_datastore.pl subst ${profile_level}`
	vidoptions="${vidoptions} -level ${temp}"
fi

if [ "${quality}" != "" ]; then
	temp=`/usr/local/bin/cds_datastore.pl subst ${quality}`
	vidoptions="${vidoptions} -q:v ${temp}"
fi

if [ "${audiofilters}" != "" ]; then
	temp=`/usr/local/bin/cds_datastore.pl subst ${audiofilters}`
	audoptions="${audoptions} -af ${temp}"
fi

if [ "${allow_experimental}" != "" ]; then
	audoptions="-strict -2 ${audoptions}"
fi

if [ "${audiocap}" != "" ]; then
	temp=`/usr/local/bin/cds_datastore.pl subst ${audiocap}`
	audoptions="${audoptions} -ar ${temp}"
fi

if [ "${debug}" != "" ]; then
	echo debug: commandline is nice -n ${priority} /usr/local/bin/ffmpeg -i "${cf_media_file}" ${vidoptions} -acodec ${acodec} ${audoptions} -f ${format} -y "${OUTPUT_FILE_PATH}"
fi

nice -n ${priority} ${FFMPEG} -i "${cf_media_file}" ${vidoptions} -acodec ${acodec} ${audoptions} -f ${format} -y "${OUTPUT_FILE_PATH}"

if [ "$?" != "0" ]; then
	echo -ERROR: ffmpeg failed with error $?.  More information should be in the CDS log trace.
	exit 1
else
	echo cf_media_file=${OUTPUT_FILE_PATH} > ${cf_temp_file}
	echo +SUCCESS: ffmpeg transcode succeeded to file ${OUTPUT_FILE_PATH}
	exit 0
fi

