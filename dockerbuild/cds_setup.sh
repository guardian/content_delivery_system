#!/bin/bash -e
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

#this script #installs the Content Delivery System onto the given system

#Configuration
MANIFEST="/etc/cds_backend/manifest"
MODULES_PATH="/usr/local/lib/cds_backend/"
BINARIES_PATH="/usr/local/bin"
ROUTES_PATH="/etc/cds_backend/routes"
TEMPLATES_PATH="/etc/cds_backend/templates"
MAPPINGS_PATH="/etc/cds_backend/mappings"
LOG_PATH="/var/log/cds_backend"
SPOOL_PATH="/var/spool/cds_backend"
CACHE_PATH="/var/cache/cds_backend"
SPOOL_PERM=0770
OWNER_UID=0
OWNER_GID=0
MODULES_PERM=0755
BINARIES_PERM=0755
ROUTES_PERM=0660
TEMPLATES_PERM=0660
MAPPINGS_PERM=0660
LOG_PERM=0770
#End config

SOURCE_DIR=/usr/src/CDS
if [ "${SOURCE_DIR}" == "." ]; then
	SOURCE_DIR=$PWD
fi

echo Running in ${SOURCE_DIR}
PRINSTALLED=0

echo CDS Backend Installer script v1.3
echo
#Attempt to install the AWS SDK for Ruby....
GEM=`which gem`

if [ -x "${GEM}" ]; then
	echo -----------------------------------------------------
	cd ${SOURCE_DIR}/Ruby
	echo Building and installing CDS library for Ruby...
	gem build cdslib.gemspec
	gem install cdslib-1.0.gem
	if [ "$?" != "0" ]; then
		echo Gem reported an error building or installing the library.
		echo Ensure that the Ruby development files are installed \(ruby-dev package on Debian-based systems\), or try updating your Ruby installation and trying again.
		exit 1
	fi

	echo Building and installing CDS-Vidispine interface for Ruby...
	gem build vslib.gemspec
	gem install vslib-1.0.gem

	if [ "$?" != "0" ]; then
		echo Gem reported an error building or installing the library.
		echo Ensure that the Ruby development files are installed \(ruby-dev package on Debian-based systems\), or try updating your Ruby installation and trying again.
		exit 1
	fi

	echo Building and installing R2 Newspaper Integration interface for Ruby...
	gem build R2NewspaperIntegration.gemspec
	gem install R2NewspaperIntegration-1.0.gem

	if [ "$?" != "0" ]; then
		echo Gem reported an error building or installing the library.
		echo Ensure that the Ruby development files are installed \(ruby-dev package on Debian-based systems\), or try updating your Ruby installation and trying again.
		exit 1
	fi

	echo Building and installing Elemental interface for Ruby...
	gem build elementallib.gemspec
	gem install elementallib-1.0.gem

	if [ "$?" != "0" ]; then
			echo Gem reported an error building or installing the library.
			echo Ensure that the Ruby development files are installed \(ruby-dev package on Debian-based systems\), or try updating your Ruby installation and trying again.
			exit 1
	fi

	echo Building and installing Thumbor interface for Ruby...
	gem build thumborlib.gemspec
	gem install thumborlib-1.0.gem

	if [ "$?" != "0" ]; then
			echo Gem reported an error building or installing the library.
			echo Ensure that the Ruby development files are installed \(ruby-dev package on Debian-based systems\), or try updating your Ruby installation and trying again.
			exit 1
	fi

	cd ${SOURCE_DIR}
	echo ------------------------------------------------------

	echo Building and installing Pluto interface for Ruby...
	gem build plutolib.gemspec
	gem install plutolib-1.0.gem

	if [ "$?" != "0" ]; then
        echo Gem reported an error building or installing the library.
        echo Ensure that the Ruby development files are installed \(ruby-dev package on Debian-based systems\), or try updating your Ruby installation and trying again.
        exit 1
	fi
else
	echo I couldn\'t find a working copy of Gem, ruby\'s package tool.  If you want to use methods that talk to AWS, Google or Vidispine,
	echo you should install the relevant SDK.  The simplest way is to install gem and re-run this installer, or run \"sudo gem install aws-sdk google-api-client launchy thin\"
	echo
  exit 1
fi

echo Installing CDS from ${SOURCE_DIR}.

echo Creating a new usergroup for CDS.
groupadd -r cds 2>/dev/null

OWNER_GID=`grep cds: /etc/group | cut -d : -f 3`
if [ "${OWNER_GID}" == "" ]; then
	echo Unable to create a group for some reason.  Scripts will be owned by root.
	echo Press ENTER to continue
        if [ "${yestoall}" == "0" ]; then
            read junk
	fi
        OWNER_GID=0
else
	echo CDS group is at group ID ${OWNER_GID}
fi

mkdir -p `dirname $MANIFEST`
if [ "$?" != "0" ]; then
	echo Unable to create configuration location.  Maybe you need to run the installer as root?
	echo Edit the top of the script to install scripts with another owner or group
	exit 1
fi

mkdir -p ${ROUTES_PATH}
chown ${OWNER_UID} ${ROUTES_PATH}
chgrp ${OWNER_GID} ${ROUTES_PATH}
chmod 770 ${ROUTES_PATH}

mkdir -p ${TEMPLATES_PATH}
chown ${OWNER_UID} ${TEMPLATES_PATH}
chgrp ${OWNER_GID} ${TEMPLATES_PATH}
chmod 770 ${TEMPLATES_PATH}

mkdir -p ${MODULES_PATH}
chown ${OWNER_UID} ${MODULES_PATH}
chgrp ${OWNER_GID} ${MODULES_PATH}
chmod ${MODULES_PERM} ${MODULES_PATH}

mkdir -p ${LOG_PATH}
chown ${OWNER_UID} ${LOG_PATH}
chgrp ${OWNER_GID} ${LOG_PATH}
chmod ${LOG_PERM} ${LOG_PATH}


mkdir -p ${BINARIES_PATH}
#mkdir -p ${MAPPINGS_PATH}

if [ ! -x `which perl` ]; then
	echo ERROR - you do not appear to have Perl installed, which is needed to run CDS.
	echo Please install a recent version of Perl for your OS and re-run this script.
	exit 1;
fi


for x in `ls "${SOURCE_DIR}/scripts"`; do
	if [ -f "${SOURCE_DIR}/scripts/$x" ]; then
		install -bcpv -g ${OWNER_GID} -m ${MODULES_PERM} -o ${OWNER_UID} "${SOURCE_DIR}/scripts/$x" ${MODULES_PATH}
		echo ${MODULES_PATH}/$x >> $MANIFEST
	fi
done

echo
echo

for x in `ls "${SOURCE_DIR}/test_routes"`; do
        if [ -f "${SOURCE_DIR}/test_routes/$x" ]; then
                install -bcpv -g ${OWNER_GID} -m ${ROUTES_PERM} -o ${OWNER_UID} -p -v "${SOURCE_DIR}/test_routes/$x" ${ROUTES_PATH}
		echo ${ROUTES_PATH}/$x >> $MANIFEST
        fi
done

echo
echo

for x in `ls "${SOURCE_DIR}/scripts/templates"`; do
        if [ -f "${SOURCE_DIR}/scripts/templates/$x" ]; then
                install -bcpv -g ${OWNER_GID} -m ${TEMPLATES_PERM} -o ${OWNER_UID} "${SOURCE_DIR}/scripts/templates/$x" ${TEMPLATES_PATH}
		echo ${TEMPLATES_PATH}/$x >> $MANIFEST
	fi
done

echo
echo

#for x in `ls "${SOURCE_DIR}/mappings"`; do
#        if [ -f "${SOURCE_DIR}/mappings/$x" ]; then
#                #install -bcpv -g ${OWNER_GID} -m ${MAPPINGS_PERM} -o ${OWNER_UID} "${SOURCE_DIR}/mappings/$x" ${MAPPINGS_PATH}
#		echo ${MAPPINGS_PATH}/$x >> $MANIFEST
#        fi
#done

echo
echo

for x in `ls "${SOURCE_DIR}"/{cds_run.pl,cds_datareport.pl,resolve_name.pl,newsml_get.pl,ee_get.pl,cds_datastore.pl,saxnewsml.pm}`; do
        if [ -f "$x" ]; then
                install -bcpv -g ${OWNER_GID} -m ${BINARIES_PERM} -o ${OWNER_UID} "$x" ${BINARIES_PATH}
		echo ${BINARIES_PATH}/`basename "$x"` >> $MANIFEST
        fi
done

echo
echo

echo Creating path for in-process data ${SPOOL_PATH}...
mkdir -p "${SPOOL_PATH}"
chown ${OWNER_UID} "${SPOOL_PATH}"
chgrp ${OWNER_GID} "${SPOOL_PATH}"
chmod ${SPOOL_PERM} "${SPOOL_PATH}"

echo Creating path for cache data ${CACHE_PATH}...
mkdir -p "${CACHE_PATH}"
chown ${OWNER_UID} "${CACHE_PATH}"
chgrp ${OWNER_GID} "${CACHE_PATH}"
chmod ${SPOOL_PERM} "${CACHE_PATH}"

#now for the Perl system-level modules, CDS::Datastore et. al.
#first find a good install location
#this perl script is much easier than mucking around with awk etc!
PMDIR=`perl ${SOURCE_DIR}/findpmpaths.pl`
if [ "$?" -ne "0" ]; then
	echo There seemed to be a problem finding a suitable path to install the PM files.
	echo CDS will not run without these, check above trace for more information
	exit 1
fi

echo Installing PM libraries to ${PMDIR}...

for x in `find ${SOURCE_DIR}/CDS -iname \*.pm`; do
	SRCPATH=`dirname "$x"`
	#we need to strip our own source path out of the complete path to avoid attempting
	#to install to silly locations
	INSTPATH=${PMDIR}/`echo $SRCPATH | sed s#${SOURCE_DIR}/##`
	#-D tells install to recursively create directories as needed
	mkdir -p "${INSTPATH}"
	chown ${OWNER_UID} "${INSTPATH}"
	chgrp ${OWNER_GID} "${INSTPATH}"
	install -bcpv -g ${OWNER_GID} -m ${BINARIES_PERM} -o ${OWNER_UID} "$x" ${INSTPATH}/`basename "$x"`
	echo ${INSTPATH}/`basename $x` >> ${MANIFEST}
done

ln -s /usr/local/bin/cds_run.pl /usr/local/bin/cds_run
ln -s /usr/local/bin/newsml_get.pl /usr/local/bin/newsml_get
ln -s /usr/local/bin/cds_datareport.pl /usr/local/bin/datareport
ln -s /usr/local/bin/cds_datastore.pl /usr/local/bin/cds_datastore
ln -s /usr/local/bin/resolve_name.pl /usr/local/bin/resolve_name
ln -s /usr/local/bin/ee_get.pl /usr/local/bin/ee_get

echo The next step is to install any extra Perl libraries that are needed by CDS or the CDS methods.

echo Checking you have the Perl modules you need \(logging to ${SOURCE_DIR}/checkperlmodules.log\)....
perl ${SOURCE_DIR}/checkperlmodules.pl ${pkgargs} 2> ${SOURCE_DIR}/checkperlmodules.log

echo
cat << EOF
CDS is now installed, now you need to set up some routes in ${ROUTES_PATH}.
Consult the documentation for more details on this.
At the moment, cds_run can only be run by root.  If you want to allow other users to run the CDS
system, then you should add them to the CDS group, like this:
$ usermod -aG cds {username}
You will need to re-start any Terminal or login sessions for this to take effect.

If you want to use a database to store logs, you should read the DBLOGGING.txt file in the installation directory, and copy the cds_backend.conf file from the etc/ subdirectory of the installation to /etc
EOF
