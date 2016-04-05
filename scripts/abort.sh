#!/bin/bash

VERSION="$Rev: 510 $ $LastChangedDate: 2013-09-20 18:17:45 +0100 (Fri, 20 Sep 2013) $"
#This module simply returns an error.  It is normally used for testing, to stop a route from running
#at a certain point or to test failure methods.
echo -ERROR: Abort method: Automatically returning failure.
exit 1;