#!/usr/bin/env bash

#from http://stackoverflow.com/questions/3915040/bash-fish-command-to-print-absolute-path-to-a-file
function abspath() {
    # generate absolute path from relative path
    # $1     : relative filename
    # return : absolute path
    if [ -d "$1" ]; then
        # dir
        (cd "$1"; pwd)
    elif [ -f "$1" ]; then
        # file
        if [[ $1 == */* ]]; then
            echo "$(cd "${1%/*}"; pwd)/${1##*/}"
        else
            echo "$(pwd)/$1"
        fi
    fi
}

DEPLOYPATH="s3://gnm-multimedia-archivedtech/WorkflowMaster"
BASEPATH=$(abspath "${BASH_SOURCE%/*}")

#echo ${BASH_SOURCE}
echo Running in ${BASEPATH}

echo -----------------------------------
echo Building gems...
echo -----------------------------------
cd ${BASEPATH}/Ruby
rm -f *.gem
for x in `ls *.gemspec`; do gem build "$x"; done

echo -----------------------------------
echo Building new tar bundle...
echo -----------------------------------
ln -s ${BASEPATH} /tmp/cds_install

cd /tmp
tar cv --exclude=".git/" --exclude=".svn/" --exclude=".vagrant/" --exclude=".*/" cds_install/* | bzip2 > /tmp/cds_install.tar.bz2
if [ "$?" != "0" ]; then
    echo tar bundle failed to build :\(
    exit 1
fi
rm /tmp/cds_install

echo -----------------------------------
echo Moving old tar bundle on S3...
echo -----------------------------------
aws s3 mv "${DEPLOYPATH}/cds_install.tar.bz2"  "${DEPLOYPATH}/cds_install_$(date +%Y%m%d_%H%M%S).tar.bz2"
if [ "$?" != "0" ]; then
    echo aws command failed :\(
    exit 1
fi

echo -----------------------------------
echo Deploying new bundle to S3...
echo -----------------------------------
aws s3 cp  /tmp/cds_install.tar.bz2 "${DEPLOYPATH}/cds_install.tar.bz2"
if [ "$?" != "0" ]; then
    echo aws command failed :\(
    exit 1
fi

rm -f /tmp/cds_install.tar.bz2

echo All done!