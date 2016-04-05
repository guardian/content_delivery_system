#!/bin/bash

YUM=`which yum`
GEM=`which gem`

if [ ! -x "${YUM}" ]; then
	echo Could not find a working copy of YUM package management tool
	exit 1
fi

if [ ! -x "${GEM}" ]; then
	echo Could not find a working copy of Gem Ruby package management
	exit 1
fi

echo INFO: Using ${YUM} and ${GEM}
echo
echo Checking for currently installed build packages...
rpm -qa | grep postgresql-devel
DEVEL_ABSENT="$?"
rpm -qa | grep -P 'postgresql-\d+'
POSTGRESQL_ABSENT="$?"

echo Postgres currently absent: ${POSTGRESQL_ABSENT}
echo Postgres-devel currently absent: ${DEVEL_ABSENT}
echo Packages not currently installed will be removed at the end of the install process.

echo Installing development tools, required for build
yum -y groupinstall "Development Tools"

if [ "${DEVEL_ABSENT}" -eq "1" ]; then
	echo Installing postgresql-devel, required for build
	${YUM} -y install postgresql-devel
fi

echo
echo ---------------------------------
echo
echo Downloading and installing pg gem...
${GEM} install pg

if [ "$?" -ne "0" ]; then
	echo Something went wrong with installation. Leaving postgresql packages intact.
	exit 2
fi

echo Installation succeeded

if [ "${DEVEL_ABSENT}" -eq "1" ]; then
	echo Removing postgresql-devel that was installed for build
	rpm --erase postgresql-devel
fi

if [ "${POSTGRESQL_ABSENT}" -eq "1" ]; then
        echo Removing postgresql that was installed for build
        rpm --erase postgresql
fi
echo All done
