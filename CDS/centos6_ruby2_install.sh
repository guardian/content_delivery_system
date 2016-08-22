#!/bin/bash

#This script is derived from information at http://www.server-world.info/en/note?os=CentOS_6&p=ruby20
#CentOS 6 (and maybe other yum-based distros?) still doesn't have ruby2.0. So, we need to download sources, build an RPM and then install it.

yum -y install wget

echo Installing EPEL repository...
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
rpm -Uvh remi-release-6*.rpm epel-release-6*.rpm

echo -----------------------------------------------------------------

echo Installing prerequisites for Ruby install...
echo

yum -y groupinstall "Development Tools" 
yum --enablerepo=epel -y install libyaml libyaml-devel readline-devel ncurses-devel gdbm-devel tcl-devel openssl-devel db4-devel libffi-devel   # install from EPEL

mkdir -p ${HOME}/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

echo ----------------------------------------------------------
echo Downloading Ruby sources...
echo
wget http://cache.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p353.tar.gz -P rpmbuild/SOURCES 
wget --no-check-certificate https://raw.github.com/hansode/ruby-2.0.0-rpm/master/ruby200.spec -P rpmbuild/SPECS
echo ----------------------------------------------------------
echo Installing build dependencies...
echo
yum-builddep  ${HOME}/rpmbuild/SPECS/ruby200.spec
echo ----------------------------------------------------------
echo Building source and compiling into RPM...
echo
rpmbuild -bb ${HOME}/rpmbuild/SPECS/ruby200.spec

echo ----------------------------------------------------------
echo Installing RPM...
echo
rpm -Uvh ${HOME}/rpmbuild/RPMS/x86_64/ruby-2.0.0p353-2.el6.x86_64.rpm

EXITCODE=$?
echo ----------------------------------------------------------
if [ "${EXITCODE}" != "0" ]; then
	echo RPM installation failed 
	exit 1
fi

echo Installation apparently succeeded

ruby -v | grep 2\.
if [ "$?" != "0" ]; then
	echo Ruby returned a strange version number, expecting 2.x but got `ruby -v`
	exit 2
fi
echo Ruby returned 2.x version number, so all is well.
exit 0
