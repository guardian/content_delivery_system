#!/usr/bin/perl

my $version='$Rev: 1 $ $LastChangedDate: 2020-05-15 16:06:33 +0100 (Fri, 15 May 2020) $';

#Module to check dates are not before 2008 and set them to the current date/time if they are.
#Expects:
#<key>blah 	   - the name of the key to check for the date
#END DOC

use CDS::Datastore;
use File::Slurp qw/read_file/;
use DateTime::Format::Strptime;
use DateTime;
use Date::Manip qw(ParseDate);
use Date::Parse;

#START MAIN
my $store=CDS::Datastore->new('check_date');

$store->{'debug'}=$ENV{'debug'};

foreach(qw/key/){
	if(not defined $ENV{$_}){
		print "-ERROR - you need to specify <$_> to use this module.\n";
		exit 1;
	}
}

my $key=$ENV{'key'};
if($key eq ''){
	print "-ERROR - you need to specify a value in <key> to set a metadata key.\n";
	exit 1;
}

my @keyparts=split /:/,$ENV{'key'};
#if no section is specified, default to "meta"
if(scalar @keyparts==1){
	$keyparts[1]=$ENV{'key'};
	$keyparts[0]="meta";
	$key="meta:$key";
}

if($keyparts[0] eq "track"){
	splice @keyparts,1,0,'type';
}

my $existing_value=$store->get(@keyparts,undef);

my $value=$existing_value;
my $finalstring=$existing_value;
my $test_date = ParseDate($value);
if (!$test_date) {
	print "-ERROR - Perl could not parse the supplied string ($value) as a date. Aborting.\n";
	exit 1;
}
my $date_time_from_datastore = str2time($value);
my $oldest_allowed_date_time = 1199145600;
if ($date_time_from_datastore < $oldest_allowed_date_time) {
	my $now = DateTime->now()->iso8601().'Z';
	$finalstring = $now;
	print "INFO: Setting '$key' to '$finalstring' in the metadata stream...\n";
	$store->set(@keyparts,$finalstring,undef);
	print "+SUCCESS: Value set.\n";
} else {
	print "INFO: $key is $value which is after midnight on 1/1/2008. Leaving alone.\n"
}
