#!/usr/bin/env bash


echo export PATH="$PATH:/opt/circleci/.rvm/bin" >> /root/.profile
echo '[[ -s "/opt/circleci/.rvm/scripts/rvm" ]] && source "/opt/circleci/.rvm/scripts/rvm"' >> /root/.profile
