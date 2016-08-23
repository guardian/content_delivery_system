This directory contains a Packer build for a CDS base image. It's taken from the multimedia-ami-builds repo.

For more information on Packer go to: http://packer.io.

Prerequisites
-------------

Packer - download this from https://www.packer.io
Ruby 2.x (for yaml2json converter script)

How To Use
----------

Firstly, download and install Packer if you have not got it already.
You should make sure that you get credentials to the Multimedia AWS account from Janus and
either set them up in your local AWS configuration or specify an access key and secret
on the commandline.

In order to build a CDS base image from the configuration, change to packer/ and run:

./buildimage.sh

This will use yaml2json.rb to convert the .yml configuration into json suitable for packer,
and build a new image in EC2