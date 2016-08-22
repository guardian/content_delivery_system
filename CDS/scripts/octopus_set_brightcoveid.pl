#!/usr/bin/perl

my $version='$Rev: 472 $ $LastChangedDate: 2013-08-14 14:25:30 +0100 (Wed, 14 Aug 2013) $';

#This module updates the Brightcove ID header field in Octopus based on info in the datastore
#arguments:
#<brightcove_id_key>blah - use this key for Brightcove id data (defaults to 'Brightcove ID')
#<octopus_id_key>blah    - use this key for Octopus id data (defaults to 'octopus ID')
use Data::Dumper;
use CDS::Datastore;
use CDS::octopus_simple;


#START MAIN
my $bckey="Brightcove ID";
if(defined $ENV{'brightcove_id_key'}){
	$bckey=$ENV{'brightcove_id_key'};
}
my $octkey="octopus ID";
if(defined $ENV{'octopus_id_key'}){
	$bckey=$ENV{'octopus_id_key'};
}
my $statuskey="r2-video-status";
if(defined $ENV{'output_status_key'}){
	$statuskey=$ENV{'output_status_key'};
}

my $store=CDS::Datastore->new('octopus_set_brightcoveid');
if(not defined $store){
	die "Unable to connect to datastore\n";
}

my ($bcid,$octid)=$store->get('meta',$bckey,$octkey);

if(not $bcid){
	print STDERR "-ERROR - unable to retrieve Brightcove ID from key $bckey\n";
	exit 1;
}
if(not $octid){
	print STDERR "-ERROR - unable to retrieve Octopus ID from key $octkey\n";
	exit 1;
}

unless(CDS::octopus_simple::add_brightcove_id($octid,$bcid)){
	exit 1;	#an error message has already been displayed by octopus_simple
}

$store->set('meta',$statuskey,'VIDEOOK',undef);
exit 0;
