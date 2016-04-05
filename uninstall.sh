#!/bin/bash

#This script uninstalls the CDS backend

#Configuration
MANIFEST="/etc/cds_backend/manifest"
MODULES_PATH="/usr/local/lib/cds_backend/"
BINARIES_PATH="/usr/local/bin"
ROUTES_PATH="/etc/cds_backend/routes"
TEMPLATES_PATH="/etc/cds_backend/templates"
MAPPINGS_PATH="/etc/cds_backend/mappings"
OWNER_UID=0
OWNER_GID=0
MODULES_PERM=755
BINARIES_PERM=755
ROUTES_PERM=600
TEMPLATES_PERM=600
MAPPINGS_PERM=600
#End config

if [ -f "$MANIFEST" ]; then
	echo Uninstalling from $MANIFEST...
	for x in `cat "$MANIFEST"`; do
		rm -f $x
	done
	rm -f $MANIFEST
else
	echo Warning! - Manifest not found.  Uninstallation may be unsafe.
	echo Press Ctrl-C to cancel or any other key to continue.
	read junk
	rm -rf ${MODULES_PATH}
	rm -rf ${ROUTES_PATH}
	rm -rf ${TEMPLATES_PATH}
	rm -rf ${MAPPINGS_PATH}

	for x in `ls "${BINARIES_PATH}"/{cds_run.pl,newsml_get.pl,cds_octrun_chain.sh,saxRoutes.pm,saxnewsml.pm}`; do
		rm "${BINARIES_PATH}/$x"
	done
fi
