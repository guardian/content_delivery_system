#!/usr/bin/perl

#This script is an interface that allows shellscripts to access basic datastore functionality
#Usage: cds_datastore [VERB] [PARAMS]
# where [VERB] is one of {get|set|subst} - not case-sensitive.
# for 'get', the first entry in [PARAMS] is a delimiter character for the output. [newline] or [tab] are
#   used to denote newline or tab-delimited.
#	The second is the type, {meta|media|track}. The rest of the [PARAMS] are a list of keys to get.
# e.g., cds_datastore get meta ~ title description - returns title and description from meta, with a
# ~ character seperating them.
#  Return code is the number of items returned, or <0 if an error.
# for 'set', [PARAMS] is a list of key/value pairs to set.
#   e.g., cds_datastore set title "This is a new title" newid 0123456
# for 'subst', [PARAMS] is just one argument - the string to substitute.
#   e.g., cds_datastore subst "I have got the video called {meta:title} with size {track:vide:width}x{track:vide:height}"

use CDS::Datastore;
use Data::Dumper;

#START MAIN
my $store=CDS::Datastore->new('shellscript');
#$store->{'debug'}=1;

my $verb=shift @ARGV;
if(lc $verb eq "get"){
	#my @params=@argv;
	my $delim=shift @ARGV;
	$delim="\n" if(lc $delim eq '[newline]');
	$delim="\t" if(lc $delim eq '[tab]');
	if($ARGV[0] ne 'meta' and $ARGV[0] ne 'media' and $ARGV[0] ne 'track'){
		print STDERR "cds_datastore: error - you need to specify metadata type, one of {meta|media|track}; not ".$ARGV[0].".\n";
		exit -1;
	}
	my @result=$store->get(@ARGV);
	print $_.$delim foreach(@result);
	print "\n";
	exit scalar @result;
} elsif(lc $verb eq "set"){
	if($ARGV[0] ne 'meta' and $ARGV[0] ne 'media' and $ARGV[0] ne 'track'){
		print STDERR "cds_datastore: error - you need to specify metadata type, one of {meta|media|track}.\n";
		exit -1;
	}
	my @result=$store->set(@ARGV);
} elsif(lc $verb eq "subst"){
	my $result=$store->substitute_string($ARGV[0]);
	print "$result\n";
} elsif(lc $verb eq "dump"){
	print Dumper($store->get_meta_hashref);
} else {
	print STDERR "cds_datastore: error - verb '$verb' not recognised.  You need to specify get, set or subst.\n";
	exit -2;
}
exit 0;
