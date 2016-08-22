#!/bin/bash

VERSION="$Rev: 513 $ $LastChangedDate: 2013-09-24 09:45:15 +0100 (Tue, 24 Sep 2013) $"

#This module outputs an HTML report of the current contents of the datastore to the given folder.
#Commonly used as a fail-method to help in debugging route problems, but can be used to monitor data coming in and out over the live of a route
#
#Arguments:
# <output_directory>/path/to/directory - output the data report to this directory.  The file name always consists of a CDS identifier, the route name and date/time of the run.
#END DOC

#REPORTPROG=`which cds_datareport.pl`
REPORTPROG=/usr/local/bin/cds_datareport.pl

if [ ! -x "${REPORTPROG}" ]; then
	echo -ERROR: Unable to find cds_datareport.pl script, cannot run without this.
	exit 1;
fi

echo INFO: outputting report to \'${output_directory}\'

if [ "${output_directory}" == "" ]; then
	echo -ERROR: You must specify an output location by using \<output_directory\> in the route file
	exit 1;
fi

cd "${output_directory}"
exec "${REPORTPROG}" "${cf_datastore_location}"
