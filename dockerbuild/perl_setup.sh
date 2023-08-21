#!/bin/bash -e

echo ------------------------------------------
echo Kickstarter: Installing Perl prerequisites
echo ------------------------------------------
mkdir -p /usr/local/cloudworkflowscripts
mkdir -p /usr/local/lib/site_perl
curl -L https://cpanmin.us/ -o cpanm
chmod +x cpanm
apt-get -y install libdbd-mysql-perl
./cpanm --force Amazon::SQS::Simple
./cpanm Log::Any@1.716
./cpanm Data::UUID URL::Encode Net::FTP::Throttle Digest::SHA1 File::Touch Search::Elasticsearch Digest::HMAC_SHA1
