#!/bin/bash

###Step one - get package repos up to date
echo Updating package repositories
apt-get -y update
apt-get -y upgrade
mkdir -p /usr/local/bin

###Step two - install some basic prerequisites
echo ------------------------------------------
echo Kickstarter: Installing prerequisites...
echo ------------------------------------------
apt-get -y install python-pip e2fsprogs zip ruby2.0 ruby2.0-dev perl ffmpeg2theora libz-dev
pip install awscli


###Step 5 - Ruby prerequisited
echo ------------------------------------------
echo Kickstarter: Installing Ruby prerequisites
echo ------------------------------------------
rm -f /usr/bin/ruby
rm -f /usr/bin/gem
ln -s /usr/bin/ruby2.0 /usr/bin/ruby
ln -s /usr/bin/gem2.0 /usr/bin/gem
gem install awesome_print trollop sentry-raven aws-sdk-v1 aws-sdk-core aws-sdk-resources google-api-client launchy thin rest-client certifi sentry-raven elasticsearch

###Step 6 - ffmpeg
echo ------------------------------------------
echo Kickstarter: Installing ffmpeg
echo ------------------------------------------
cd /tmp
aws s3 cp s3://gnm-multimedia-archivedtech/WorkflowMaster/ffmpeg-bin.tar.bz2 .
tar xvjf ffmpeg-bin.tar.bz2
cp -v ffmpeg-bin/ffmpeg /usr/local/bin
cp -v ffmpeg-bin/ffmpeg_g /usr/local/bin
cp -v ffmpeg-bin/ffprobe /usr/local/bin
cp -v ffmpeg-bin/ffprobe_g /usr/local/bin

###Step 7 - CDS
echo ------------------------------------------
echo Kickstarter: Setting up CDS workflow processing
echo ------------------------------------------
cd /tmp
cpanm Data::UUID URL::Encode
apt-get -y install libdbd-mysql-perl

mkdir -p /usr/local/cloudworkflowscripts
mkdir -p /usr/local/lib/site_perl

###Step 10 - crontabs to stop instance filling up
echo ------------------------------------------
echo Kickstarter: Setting up crontabs
echo ------------------------------------------
crontab -u root - << EOF
# m h dom mon dow command
0 2 * * * /usr/bin/find /mnt -mtime +12 -delete
12 * * * * /usr/bin/find /var/log/cds_backend -mtime +1 -delete
EOF

###Step 11 - logrotate
echo ------------------------------------------
echo Kickstarter: Setting up logrotate
echo ------------------------------------------
#make logrotate run hourly
cp -a /etc/cron.daily/logrotate /etc/cron.hourly

#install logrotate configs from s3
aws s3 cp s3://gnm-multimedia-archivedtech/WorkflowMaster/logrotate /etc/logrotate.d --recursive

echo ------------------------------------------
echo Completed kickstarter at `date "+%H:%M:%S on %d-%m-%Y"`
echo ------------------------------------------
