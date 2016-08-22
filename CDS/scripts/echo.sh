#!/bin/bash

#This module simply echoes a message to the log, and if an XML file is present dumps its output as well.
#If invoked as a fail-method, it will also output which method failed and what the error was.
#Normally used for debugging but can be handy for other log-related uses
#
#Arguments:
# <message>messagetext - Output this message to the log

#START MAIN
VERSION="$Rev: 517 $ $LastChangedDate: 2013-10-07 12:07:00 +0100 (Mon, 07 Oct 2013) $"

echo ${message}
if [ "${cf_xml_file}" != "" ]; then
	cat ${cf_xml_file}
fi

if [ "${cf_failed_method}" != "" ]; then
	echo Called as failure method.  Method ${cf_failed_method} failed with error ${cf_last_error}
fi
exit 0
