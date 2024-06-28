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

# Install bundler
gem install bundler

# Create a Gemfile for managing gem installations
cat <<EOF > Gemfile
source 'https://rubygems.org'

gem 'nokogiri', '1.13.10'
gem 'faraday', '2.8.1'
gem 'faraday-net_http', '3.0.2'
gem 'retryable', '3.0.5'
gem 'awesome_print'
gem 'trollop'
gem 'sentry-raven'
gem 'aws-sdk-v1'
gem 'aws-sdk-core'
gem 'aws-sdk-resources'
gem 'google-api-client', '<0.9'
gem 'launchy'
gem 'thin'
gem 'rest-client'
gem 'certifi'
gem 'mini_exiftool'
gem 'mail'
gem 'exifr'
gem 'elasticsearch'
gem 'rake'
gem 'rspec'
gem 'webmock'
EOF

# Install gems using bundler
bundle install
