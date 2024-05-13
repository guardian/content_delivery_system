#!/bin/bash -e

###Step 5 - Ruby prerequisites
echo ------------------------------------------
echo Kickstarter: Installing Ruby prerequisites
echo ------------------------------------------
DEBIAN_FRONTEND=noninteractive apt-get -y install software-properties-common
DEBIAN_FRONTEND=noninteractive apt-add-repository -y ppa:brightbox/ruby-ng
apt-get -y update
apt-get -y install ruby2.7 ruby2.7-dev ruby-switch
ruby-switch --set ruby2.7
gem install nokogiri -v 1.13.10
gem install faraday-net_http -v 3.0.2
gem install awesome_print trollop sentry-raven aws-sdk-v1 aws-sdk-core aws-sdk-resources google-api-client:'<0.9' \
    launchy thin rest-client certifi sentry-raven xmp mail exifr elasticsearch rake rspec webmock
