#!/bin/bash -e

###Step 6 - ffmpeg
echo ------------------------------------------
echo Kickstarter: Installing ffmpeg
echo ------------------------------------------
cd /tmp
curl https://johnvansickle.com/ffmpeg/builds/ffmpeg-git-amd64-static.tar.xz > ffmpeg-bin.tar.xz
TOP_DIR=$(tar -tf ffmpeg-bin.tar.xz | head -1)
tar -xJf ffmpeg-bin.tar.xz --strip-components=1 -C . "$TOP_DIR"
cp -v ffmpeg /usr/local/bin
cp -v ffprobe /usr/local/bin
rm -f /tmp/ffmpeg-bin.tar.xz
