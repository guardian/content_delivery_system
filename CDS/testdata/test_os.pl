#!/usr/bin/perl

use Data::Dumper;
use lib ".";
use octopus_simple;

if(not octopus_simple::is_working){
	die "octopus_simple is not working.\n";
}

my $data=octopus_simple::get_header($ARGV[0]);
if(not defined $data){
	die "Unable to get data for id ".$ARGV[0].".\n";
}

print Dumper($data);