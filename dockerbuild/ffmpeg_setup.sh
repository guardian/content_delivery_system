#!/bin/bash -e

###Step 6 - ffmpeg
echo ------------------------------------------
echo Kickstarter: Installing ffmpeg
echo ------------------------------------------
cd /tmp
curl https://gnm-multimedia-deployables.s3.eu-west-1.amazonaws.com/ffmpeg/ffmpeg-bin.tar.bz2 > ffmpeg-bin.tar.bz2
tar xvjf ffmpeg-bin.tar.bz2
cp -v ffmpeg-bin/ffmpeg /usr/local/bin
cp -v ffmpeg-bin/ffmpeg_g /usr/local/bin
cp -v ffmpeg-bin/ffprobe /usr/local/bin
cp -v ffmpeg-bin/ffprobe_g /usr/local/bin
rm -f /tmp/ffmpeg-bin.tar.bz2
