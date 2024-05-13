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
DEBIAN_FRONTEND=noninteractive apt-get -y install zip perl ffmpeg2theora libz-dev libcrypt-ssleay-perl liburi-encode-perl libnet-ssleay-perl libnet-idn-encode-perl \
liblwp-protocol-https-perl libdbd-sqlite3-perl libyaml-perl libxml-sax-expatxs-perl libxml-xpath-perl libwww-perl libtemplate-perl  \
libxml-simple-perl libjson-perl libjson-xs-perl libdate-manip-perl libnet-sslglue-perl libdigest-perl libdigest-sha-perl libdatetime-perl libdatetime-format-http-perl \
libdbi-perl libhtml-stream-perl libfile-slurp-unicode-perl cpanminus zlib1g-dev build-essential s3cmd libsqlite3-dev nodejs curl libdbd-pg-perl libxml2-dev libxslt1-dev imagemagick ca-certificates

rm -rf /var/cache/apt
