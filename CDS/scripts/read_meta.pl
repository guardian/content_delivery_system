#!/usr/bin/perl

my $version='$Rev: 882 $ $LastChangedDate: 2014-06-06 14:15:27 +0100 (Fri, 06 Jun 2014) $';

#This module uses the built-in Datastore functionality to read an
#Episode Engine .meta or .inmeta file into the route's data stream.
#
#options:
#<take-files>{meta|inmeta}	- which file to read
#<debug/>			- [OPTIONAL] show debugging information
#

use CDS::Datastore::Episode5;
use Data::Dumper;

sub check_args {
my(@args)=@_;

foreach(@args){
	if(not defined $ENV{$_} or $ENV{$_} eq ''){
		print "-ERROR: I need to have $_ specified.  Exiting.\n";
		exit 1;
	}
}
}

#START MAIN
my $metafile;

check_args(qw/cf_datastore_location/);
if($ENV{'cf_meta_file'}){
	$metafile=$ENV{'cf_meta_file'};
	print "INFO: Using .meta file $metafile.\n";
} elsif($ENV{'cf_inmeta_file'}){
	$metafile=$ENV{'cf_inmeta_file'};
	print "INFO: Using .inmeta file $metafile.\n";
} elsif($ENV{'cf_xml_file'}){
	$metafile=$ENV{'cf_xml_file'};
	print "INFO: Using .xml file $metafile.\n";
} else {
	print "-ERROR: No .inmeta or .meta file has been specified.\n";
	exit 1;
}

unless(-f $metafile){
	print "-ERROR: metadata file $metafile does not exist.\n";
	exit 1;
}

#ok, now fire up the data store.  The argument is the name of this module,
#for tracking/audit purposes.
my $store=CDS::Datastore::Episode5->new('read_meta');
if(not $store->import_episode($metafile)){
	print "-ERROR: unable to read metadata file $metafile.  Further information should be in the log trace.\n";
	exit 1;
}
exit 0;
