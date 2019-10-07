#!/bin/bash -e

echo ------------------------------------------
echo Kickstarter: Installing JS prerequisites
echo ------------------------------------------
apt-get -y install npm
rm -rf /var/cache/apt
mkdir -p /usr/local/lib/cds_backend
cd /usr/local/lib/cds_backend
mv /tmp/dockerbuild/package.json .
npm install
