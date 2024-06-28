#!/bin/bash -e

### Step 5 - Ruby prerequisites
echo ------------------------------------------
echo Kickstarter: Installing Ruby prerequisites
echo ------------------------------------------

# Install required dependencies
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential libssl-dev zlib1g-dev \
    libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev \
    libffi-dev software-properties-common libgmp-dev

# Install Ruby gems
gem install nokogiri -v 1.13.10 --use-system-libraries
gem install faraday -v 2.8.1
gem install faraday-net_http -v 3.0.2
gem install retryable -v 3.0.5
gem install awesome_print trollop sentry-raven aws-sdk-v1 aws-sdk-core aws-sdk-resources google-api-client:'<0.9' \
    launchy thin rest-client certifi sentry-raven xmp mail exifr elasticsearch rake rspec webmock
