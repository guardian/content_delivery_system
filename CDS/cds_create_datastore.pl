#!/usr/bin/perl

use CDS::Datastore::Master;
use Data::Dumper;

#START MAIN
my $datastorename=$ENV{'cf_datastore_location'};
if($ARGV[0]){
	$datastorename=$ARGV[0];
	$ENV{'cf_datastore_location'}=$datastorename;
}

unless($datastorename){
	print STDERR "Error: you need to specify an empty file to create a datastore.  Either set cf_datastore_location, or launch this script as cds_create_datastore <filename>.\n";
	exit 1;
}

my $store=CDS::Datastore::Master->new('cds_create_datastore');
unless($store->isValid){
	print STDERR "Error: internal error setting up datastore (no SQLite handle).  Please check that CDS is installed properly.\n";
	exit 2;
}
my $rv=$store->init;

if($rv){
	print STDERR "Success - an empty datastore has been created at ".$ENV{'cf_datastore_location'}."\n";
	exit 0;
} else {
	print STDERR "Unable to set up datastore.\n";
	exit 3;
}

