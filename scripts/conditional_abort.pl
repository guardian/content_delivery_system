#!/usr/bin/perl

#this script tests the provided metadata, and causes the route to exit if a given condition is, or is not, met.
#arguments:
#	<take-files>{meta|inmeta}</take-files>	- which metadata files to check
#	<check-field>blah			- check this field in the metadata
#  <message>blah				- output this message if we stop processing
#  <invert/> [OPTIONAL]				- exit the route if the field does NOT exist, or does NOT contain the data given
#	<field-data>regex [OPTIONAL]		- only exit the route if the data in check-field matches this data. If this is not specified, then the route will exit if the given field exists.
#- regex can be any perl-compatible regular expression; if you give a certain string
#																	- it will match if that string occurs anywhere in the field.
#																	- NOTE: if you need to use / or . characters then you must escape them using a \, like this: \/ \.
#END DOC

my $version='$Rev: 515 $ $LastChangedDate: 2013-09-24 13:18:15 +0100 (Tue, 24 Sep 2013) $';

use Data::Dumper;
use XML::SAX;
use CDS::Datastore;

sub check_args {
	my @args=@_;

	foreach(@args){
		if(not defined $ENV{$_}){
			print "-ERROR: $_ was not specified.  Please check the route file.\n";
			exit 1;
		}
	}
}

#START MAIN
my $metafile,$meta_parent;

check_args(qw/check-field/);

my $checkfield=$ENV{'check-field'};

my $invert=0;
$invert=1 if(defined $ENV{'invert'});
my $debug=0;
$debug=1 if(defined $ENV{'debug'});
my $matchdata=$ENV{'field-data'};

my $store=CDS::Datastore->new('conditional_abort');
my $value=$store->get('meta',$checkfield);

if(not defined $value){
	print "debug: $checkfield does not exist within metadata.\n" if($debug);
	$have_match=0;
} elsif(not defined $matchdata){
	print "debug: $checkfield exists within metadata.  Not given any further conditions.\n" if($debug);
	$have_match=1;
} elsif(defined $matchdata and $value=~/$matchdata/){
	print "debug: $checkfield exists within metadata and matched '$matchdata'.\n" if($debug);
	$have_match=1;
} else {
	print "debug: $checkfield exists within metadata and did not match '$matchdata'.\n" if($debug);
	$have_match=0;
}

if($debug){
	print "debug: inverting output\n" if($invert);
	print "debug: NOT inverting output\n" if(not $invert);
}

if($invert){
	if($have_match){
		$have_match=0;
	} else {
		$have_match=1;
	}
}

if($have_match){
	print "INFO: Not continuing as condition was matched.\n";
	print $store->substitute_string($ENV{'message'})."\n" if(defined $ENV{'message'});
	exit 1;
} else {
	print "+SUCCESS: Continuing as condition was not matched.\n";
	exit 0;
}
