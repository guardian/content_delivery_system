#!/usr/bin/perl

my $version='$Rev: 472 $ $LastChangedDate: 2013-08-14 14:25:30 +0100 (Wed, 14 Aug 2013) $';

#This module sets the 'path' field in Octopus according to metadata from the datastore
#Parameters:
# <octopus_id_key>blah - use this key for octopus id - optional - defaults to 'octopus ID'
# <r2_key_prefix>blah - prefix this value onto all r2-related keys - optional
# <r2_id_key>blah - use this key for r2 id - defaults to {prefix}id
# <r2_url_key>blah - use this key for r2 production url - defaults to {prefix}url
# <r2_lastop_key>blah - use this key for r2 last operation - defaults to {prefix}lastop
# <r2_videostatus_key> - use this key for r2 video status - defaults to {prefix}video-status
# <r2_pagestatus_key> - use this key for r2 page status - defaults to {prefix}page-status
use Data::Dumper;
use CDS::Datastore;
use CDS::octopus_simple;

#START MAIN

#sort out arguments
my @r2keyargs=qw/r2_id_key r2_url_key r2_lastop_key r2_videostatus_key r2_pagestatus_key/;
my @r2keys=qw/id url lastop video-status page-status/;

my $octopus_key='octopus ID';

my $debug=1 if($ENV{'debug'});

if($ENV{'octopus_id_key'}){
	$octopus_key=$ENV{'octopus_id_key'};
}

for(my $n=0;$n<scalar @r2keyargs;++$n){
	if($ENV{$r2keyargs[$n]}){
		$r2keys[$n]=$ENV{$r2keyargs[$n]};
	}
}

if($ENV{'r2_key_prefix'}){
	my $prefix=$ENV{'r2_key_prefix'};
	if(not $prefix=~/[_-]$/){
		$prefix=$prefix.'-';
	}
	for(my $n=0;$n<scalar @r2keys;++$n){
		$r2keys[$n]=$prefix.$r2keys[$n];
	}
}

my $store=CDS::Datastore->new('octopus_set_r2_data');

my @values=$store->get('meta',$octopus_key,@r2keys);

if($debug){
	print "debug: values from datastore:\n";
	print Dumper(\@values);
}

# $octopus_id,$r2id,$r2prodpath,$r2lastop,$r2pagestatus,$r2vidstatus
my $result=CDS::octopus_simple::add_r2path($values[0],$values[1],$values[2],$values[3],$values[5],$values[4]);
if(!result){
	#octopus_simple should have already shown error message.
	#print "-ERROR: Octopus was unable to record R2 data\n";
	exit 1;
}
print "+SUCCESS: Octopus has stored R2-related data\n";
exit 0;
