#!/bin/bash -e

###Step 5 - Ruby prerequisites
echo ------------------------------------------
echo Kickstarter: Installing Ruby prerequisites
echo ------------------------------------------
DEBIAN_FRONTEND=noninteractive apt-get -y install software-properties-common
DEBIAN_FRONTEND=noninteractive apt-add-repository -y ppa:brightbox/ruby-ng
apt-get -y update
apt-get -y install ruby3.3 ruby3.3-dev ruby-switch
ruby-switch --set ruby3.3
gem install nokogiri -v 1.13.10
gem install faraday -v 2.8.1
gem install faraday-net_http -v 3.0.2
gem install retryable -v 3.1.0
gem install awesome_print trollop sentry-raven aws-sdk-v1 aws-sdk-core aws-sdk-resources google-api-client:'<0.9' \
    launchy thin rest-client certifi sentry-raven xmp mail exifr elasticsearch rake rspec webmock
