#!/bin/bash

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

SOURCE_DIR=`dirname "$0"`
if [ "${SOURCE_DIR}" == "." ]; then
	SOURCE_DIR=$PWD
fi

PRINSTALLED=0

echo CDS Backend Installer script v1.2 $Rev$ $LastChangedDate$
echo
echo Installing prerequisites....
echo

yestoall=0
if [ "$1" == "-y" ]; then
	echo Running in unattended mode
	yestoall=1
    pkgargs="-y "
fi

#Install prerequisites
APTGET=`which apt-get`
if [ -x "${APTGET}" ]; then	#We have apt so are running on a debian-type system
	echo You appear to be running on a system with Debian''s Advanced Package Tool installed at ${APTGET}.
	echo I will attempt to update the indexes and install prerequisites using this.
	echo If you are not using apt-provided versions of Perl, Ruby-gems, then you should press
	echo CTRL-C to stop the install and ensure that they are installed and up to date.
	echo Then re-run the install and type S \[enter\] here to skip
	echo
	echo Most users should type C \[enter\] to continue, and then Y \(yes\) when APT asks you if you want
	echo to install the packages
	echo

	if [ "${yestoall}" == "1" ]; then
		skipme="C"
                pkgargs="-y "
	fi

	while [ "${skipme}" != "C" ] && [ "${skipme}" != "S" ]; do
		echo Do you want to \(C\)ontinue or \(S\)kip?
		read skipme
		skipme=`echo ${skipme} | awk '{ print toupper($0) }'`
	done
	
	HAVEAPT=1;
	case "${skipme}" in
	"C" )
        #zlib1g-dev is required for nokogiri in aws-sdk-v1
		apt-get ${pkgargs} update
		apt-get ${pkgargs} install perl cpanminus ruby2.0 ruby2.0-dev zlib1g-dev build-essential s3cmd libsqlite3-dev
		if [ "$?" != "0" ]; then
			echo
			echo -------------------------------------------------------
			echo There seemed to be a problem installing or updating Perl, Ruby and ruby-gems
			echo Please check your APT installation.  If you think this is the installer\'s fault,
			echo then re-run and type S \[enter\] to skip this stage
			echo
			exit 2
		fi
		echo
		echo -------------------------------------------------------------------
		echo Perl/Ruby installed/updated via APT
		echo -------------------------------------------------------------------
		echo
		PRINSTALLED=1
		;;
	"S" )
		;;
	*)
		echo Skip request not understood. Exiting.
		exit 1
		;;
	esac
fi

YUM=`which yum`
if [ "${PRINSTALLED}" == "0" ] && [ -x "${YUM}" ]; then	#We have apt so are running on a redhat-type system
	echo You appear to be running on a system with the YUM package management tool installed at ${yum}.
	echo I will attempt to update the indexes and install prerequisites using this.
	echo I will also install the software and libraries necessary for CPAN to build perl modules later on, in case it is necessary.
	echo If you are not using yum-provided versions of Perl, Ruby or Ruby-gems, then you should press
	echo CTRL-C to stop the install and ensure that they are installed and up to date.
	echo Then re-run the install and type S \[enter\] here to skip
	echo
	echo Most users should type C \[enter\] to continue, and then Y \(yes\) when YUM asks you if you want
	echo to install the packages
	echo

	if [ "${yestoall}" == "1" ]; then
		skipme="C"
	fi

	while [ "${skipme}" != "C" ] && [ "${skipme}" != "S" ]; do
		echo Do you want to \(C\)ontinue or \(S\)kip?
		read skipme
		skipme=`echo ${skipme} | awk '{ print toupper($0) }'`
	done
	
	HAVEYUM=1;
	case "${skipme}" in
	"C" )
		yum ${pkgargs} install perl s3cmd
		yum ${pkgargs} groupinstall "Development Tools" "Development Libraries"
		if [ "$?" != "0" ]; then
			echo
			echo -------------------------------------------------------
			echo There seemed to be a problem installing or updating Perl, Ruby and ruby-gems
			echo Please check your APT installation.  If you think this is the installer\'s fault,
			echo then re-run and type S \[enter\] to skip this stage
			echo
			exit 2
		fi
		yum ${pkgargs} install ruby-2.0.0p353-2.el6.x86_64
		if [ "$?" != "0" ]; then
			echo
			echo --------------------------------------------------------
			echo Your system was not able to install Ruby 2.0.  This probably means it is not in your distro\'s repositories yet.
			echo Ruby 2.0 is required for CDS to communicate with Amazon Web Services and with Google/YouTube.
			echo
			echo I can attempt to build an RPM from source and install that.  This will involve removing Ruby 1.8, if it is installed, and anything
			echo 'that depends on it (for example, the Puppet management system).  If this is a problem, then you can try installing Ruby 2 another way or not use'
			echo methods that communicate with AWS or Google/YouTube.
			echo
			echo If you want to build the RPM at a later time, run the centos6_ruby2_install.sh script from the CDS install directory.
			echo
			while [ "${skipme}" != "C" ] && [ "${skipme}" != "S" ]; do
				echo 'Do you want to (C)ontinue and build the RPM or (S)kip and install Ruby 2 yourself?'
				read skipme
				skipme=`echo ${skipme} | awk '{ print toupper($0) }'`
			done
			PRINSTALLED=1
			case "${skipme}" in
			"C" )
				centos6_ruby2_install.sh
				;;
			"S" )
				;;
			"*" )
				echo Skip request not understood
				;;
			esac
		fi	
		echo
		echo -------------------------------------------------------------------
		echo Perl/Ruby installed/updated via YUM
		echo -------------------------------------------------------------------
		echo
		PRINSTALLED=1
		;;
	"S" )
		;;
	*)
		echo Skip request not understood. Exiting.
		exit 1
		;;
	esac
fi

PORT=`which port`
if [ "${PRINSTALLED}" == "0" ] && [ -x ${PORT} ]; then
	echo You appear to be running on a system with the Port package management system installed.
	echo I will attempt to update the indexes and install prerequisites using this.
	echo If you are not using port-provided versions of Perl, Ruby and ruby-gems, then you should press
	echo CTRL-C to stop the install and ensure that they are up to date.
    echo Then re-run the install and type S \[enter\] here to skip
	echo
	echo If you didn't understand the above, it's safe to type C \[enter\] for Continue.

	if [ "${yestoall}" == "1" ]; then
		skipme="C"
	fi

	while [ "${skipme}" != "C" ] && [ "${skipme}" != "S" ]; do
		echo Do you want to \(C\)ontinue or \(S\)kip?
		read skipme
	done

	case "${skipme}" in
	"C" )
		port selfupdate
		port install perl5 ruby20
		if [ -f "/opt/local/bin/ruby2.0" ]; then
			ln -s /opt/local/bin/ruby2.0 /usr/local/bin/ruby2.0
			ln -s /opt/local/bin/gem2.0 /opt/local/bin/gem2.0
		fi
		PRINSTALLED=1
		;;
	"S" )
		;;
	*)
		echo Skip request not understood. Exiting.
		exit 1
		;;
	esac
	
fi

if [ "${PRINSTALLED}" == "0" ]; then
	echo I couldn\'t find a package management system to install the required prerequisites.
	echo Please ensure that you have Perl installed before continuing \(most Unix-ish platforms do\)
	echo If you want to use Amazon Web Services, you should ensure that you have Ruby and gems, ruby\'s package management
	echo tool, installed.
	echo
	echo Type ENTER to continue or CTRL-C to exit
	echo
	read junk
fi

#ensure that system ruby is version 2.0
#FIXME - need to implement a flag to make this optional
if [ -x "/usr/bin/ruby2.0" ]; then
    rm -f /usr/bin/ruby
    ln -s /usr/bin/ruby2.0 /usr/bin/ruby
    rm -f /usr/bin/gem
    ln -s /usr/bin/gem2.0 /usr/bin/gem
fi

#Attempt to install the AWS SDK for Ruby....
GEM=`which gem`

if [ -x "${GEM}" ]; then 
	echo Installing Amazon Web Services libraries for Ruby...
	gem install aws-sdk-v1
	echo
	echo -----------------------------------------------------
	if [ "$?" != "0" ]; then
		echo Gem reported an error installing the library.  This may be because it is already installed,
		echo or it could be an error.  Ensure that the Ruby development files are installed \(ruby-dev package on Debian-based systems\), or try updating your Ruby installation and trying again.
		echo Remember that the AWS library does NOT work with Ruby version 1.8 or 1.9.  If you have an error with Nokogiri, this is probably because the gem command is not for Ruby 2.x.  Make sure that you have ruby 2.0 installed and your default Gem installation is also from the 2.0 installation \(check with ruby --version and gem --version\).  The safest way to do this is to uninstall ruby1.8 and ruby-gems if you can.  The correct version of gem is included in the ruby2.0 package.
		echo See the log immediately above for more information.
		echo
		echo Press \[ENTER\] to continue
		read junk
	else
		echo AWS libraries installed sucessfully
	fi

	echo Installing Google client API library for Ruby...
	gem install google-api-client launchy thin

	cd ${SOURCE_DIR}/Ruby
	echo Building and installing CDS library for Ruby...
	gem build ${SOURCE_DIR}/Ruby/cdslib.gemspec
	gem install ${SOURCE_DIR}/Ruby/cdslib-1.0.gem
	if [ "$?" != "0" ]; then
		echo Gem reported an error building or installing the library.
		echo Ensure that the Ruby development files are installed \(ruby-dev package on Debian-based systems\), or try updating your Ruby installation and trying again.
		exit
	fi

	echo Building and installing CDS-Vidispine interface for Ruby...
	gem build ${SOURCE_DIR}/Ruby/vslib.gemspec
	gem install ${SOURCE_DIR}/Ruby/vslib-1.0.gem

	if [ "$?" != "0" ]; then
		echo Gem reported an error building or installing the library.
		echo Ensure that the Ruby development files are installed \(ruby-dev package on Debian-based systems\), or try updating your Ruby installation and trying again.
		exit
	fi

	echo Building and installing R2 Newspaper Integration interface for Ruby...
	gem build ${SOURCE_DIR}/Ruby/R2NewspaperIntegration.gemspec
	gem install ${SOURCE_DIR}/Ruby/R2NewspaperIntegration-1.0.gem

	if [ "$?" != "0" ]; then
		echo Gem reported an error building or installing the library.
		echo Ensure that the Ruby development files are installed \(ruby-dev package on Debian-based systems\), or try updating your Ruby installation and trying again.
		exit
	fi

	echo Building and installing Elemental interface for Ruby...
	gem build ${SOURCE_DIR}/Ruby/elementallib.gemspec
	gem install ${SOURCE_DIR}/Ruby/elementallib-1.0.gem

        echo Building and installing Thumbor interface for Ruby...
        gem build ${SOURCE_DIR}/Ruby/thumborlib.gemspec
        gem install ${SOURCE_DIR}/Ruby/thumborlib-1.0.gem

        if [ "$?" != "0" ]; then
                echo Gem reported an error building or installing the library.
                echo Ensure that the Ruby development files are installed \(ruby-dev package on Debian-based systems\), or try updating your Ruby installation and trying again.
                exit
        fi
	
	cd ${SOURCE_DIR}
	echo ------------------------------------------------------
else
	echo I couldn\'t find a working copy of Gem, ruby\'s package tool.  If you want to use methods that talk to AWS, Google or Vidispine,
	echo you should install the relevant SDK.  The simplest way is to install gem and re-run this installer, or run \"sudo gem install aws-sdk google-api-client launchy thin\"
	echo
	echo Type ENTER to continue or CTRL-C to exit
	echo
	read junk
fi

#remove all aliases for ls, to avoid confusing the loops below
unalias ls
echo
echo

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
echo Press ENTER to attempt an automatic installation...
echo
if [ ! "${yestoall}" == "1" ]; then
    read junk
fi

if [ "${HAVEAPT}" == "1" ]; then
	echo
	echo ---------------------------------------------
	echo You appear to have Debian\'s Advanced Package Tool installed.  I will attempt to install
	echo modules through APT, and then double-check that you have what you need
	echo If CPAN or APT asks you, please confirm that you want to install the listed packages.
	echo A list of the packages that will be installed can be found in aptpkgs.lst in the CDS install directory.
	echo
	apt-get ${pkgargs} install `cat "${SOURCE_DIR}/aptpkgs.lst"`
	echo
	echo ----------------------------------------------
elif [ "{$HAVEYUM}" == "1" ]; then
	echo
	echo ----------------------------------------------
	echo You appear to have the YUM package tool installed. I will attempt to install
	echo modules through YUM, and then double-check that you have what you need
	echo If CPAN or YUM asks you, please confirm that you want to install the listed packages.
	echo A list of the packages that will be installed can be found in yumpkgs.lst in the CDS install directory
	echo
	yum ${pkgargs} install `cat "${SOURCE_DIR}/yumpkgs.lst"`
	echo
	echo ----------------------------------------------
fi

echo
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

