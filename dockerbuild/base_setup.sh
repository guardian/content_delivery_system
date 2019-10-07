#!/bin/bash -e

###Step one - get package repos up to date
echo Updating package repositories
apt-get -y update
apt-get -y upgrade
mkdir -p /usr/local/bin

###Step two - install some basic prerequisites
echo ------------------------------------------
echo Kickstarter: Installing prerequisites...
echo ------------------------------------------
DEBIAN_FRONTEND=noninteractive apt-get -y install python-pip zip perl ffmpeg2theora libz-dev libcrypt-ssleay-perl liburi-encode-perl libnet-ssleay-perl libnet-idn-encode-perl \
liblwp-protocol-https-perl libdbd-sqlite3-perl libyaml-perl libxml-sax-expatxs-perl libxml-xpath-perl libwww-perl libtemplate-perl  \
libxml-simple-perl libjson-perl libjson-xs-perl libdate-manip-perl libnet-sslglue-perl libdigest-perl libdigest-sha-perl libdatetime-perl libdatetime-format-http-perl \
libdbi-perl libhtml-stream-perl libfile-slurp-unicode-perl cpanminus zlib1g-dev build-essential s3cmd libsqlite3-dev nodejs
pip install awscli

###Step 5 - Ruby prerequisites
echo ------------------------------------------
echo Kickstarter: Installing Ruby prerequisites
echo ------------------------------------------
DEBIAN_FRONTEND=noninteractive apt-get -y install software-properties-common
DEBIAN_FRONTEND=noninteractive apt-add-repository -y ppa:brightbox/ruby-ng
apt-get -y update
apt-get -y install ruby2.6 ruby2.6-dev ruby-switch
ruby-switch --set ruby2.6
gem install awesome_print trollop sentry-raven aws-sdk-v1 aws-sdk-core aws-sdk-resources google-api-client:'<0.9' launchy thin rest-client certifi sentry-raven elasticsearch


echo ------------------------------------------
echo Kickstarter: Installing Perl prerequisites
echo ------------------------------------------
mkdir -p /usr/local/cloudworkflowscripts
mkdir -p /usr/local/lib/site_perl
curl -L https://cpanmin.us/ -o cpanm
chmod +x cpanm
apt-get -y install libdbd-mysql-perl
./cpanm --force Amazon::SQS::Simple
./cpanm Data::UUID URL::Encode Net::FTP::Throttle Digest::SHA1 File::Touch Search::Elasticsearch

echo ------------------------------------------
echo Kickstarter: Installing JS prerequisites
echo ------------------------------------------
cd /usr/local/lib/cds_backend
#package.json has been already put here by the Packer config in cdsbase-packer.yml
npm install

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


rm -rf /var/cache/apt

echo ------------------------------------------
echo Completed kickstarter at `date "+%H:%M:%S on %d-%m-%Y"`
echo ------------------------------------------
