#!/bin/bash -e

###Step 5 - Ruby prerequisites
echo ------------------------------------------
echo Kickstarter: Installing Ruby prerequisites
echo ------------------------------------------

# Update the package list
DEBIAN_FRONTEND=noninteractive apt-get -y update

# Install required dependencies
DEBIAN_FRONTEND=noninteractive apt-get -y install software-properties-common

# Add the Brightbox PPA for Ruby
DEBIAN_FRONTEND=noninteractive apt-add-repository -y ppa:brightbox/ruby-ng

# Update the package list again after adding the PPA
DEBIAN_FRONTEND=noninteractive apt-get -y update

# Install Ruby 3.2 and related packages
DEBIAN_FRONTEND=noninteractive apt-get -y install ruby3.2 ruby3.2-dev

# Set Ruby 3.2 as the default
update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby3.2 1
update-alternatives --install /usr/bin/gem gem /usr/bin/gem3.2 1

# Install RubyGems
gem install nokogiri -v 1.13.10
gem install faraday -v 2.8.1
gem install faraday-net_http -v 3.0.2
gem install retryable -v 3.1.0
gem install awesome_print trollop sentry-raven aws-sdk-v1 aws-sdk-core aws-sdk-resources google-api-client:'<0.9' \
    launchy thin rest-client certifi sentry-raven xmp mail exifr elasticsearch rake rspec webmock
