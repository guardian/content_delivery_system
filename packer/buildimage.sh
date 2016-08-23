#!/bin/bash

if [ ! -x `which packer` ]; then
	echo Packer appears not to be installed, or not on your PATH.
	echo Download it from https://packer.io and try again.
	exit 1
fi



SOURCE_CONFIG="cdsbase/cdsbase-packer.yml"
DEST_CONFIG="cdsbase/cdsbase-packer.json"

if [ ! -f "${SOURCE_CONFIG}" ]; then
	echo "${SOURCE_CONFIG} source could not be found"
	exit 1
fi

./yaml2json.rb "${SOURCE_CONFIG}" > "${DEST_CONFIG}"

if [ "$?" != "0" ]; then
	echo yaml2json failed for some reason, not continuing.
	exit 2
fi

cd "cdsbase"
packer validate "cdsbase-packer.json"

if [ "$?" != "0" ]; then
	echo Generated Packer config is not valid, not continuing.
	exit 3
fi

packer build "cdsbase-packer.json"

echo Completed.