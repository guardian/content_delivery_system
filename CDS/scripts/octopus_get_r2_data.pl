#!/usr/bin/perl

#This is a CDS module which uses the octopusutil program (via the octopus_simple interface)
#to extract relevant r2 metadata from the octopus header and insert it into the datastore.

#arguments:
# octopus-id-key - key to extract octopus id from in meta file - normally 'octopus ID'
# take-files - whether to use meta or inmeta file
# <allow-invalid-id/> - if this is set, then don't throw an error if the R2 id does not exist.
#<r2-key-prefix>blah - prefix the r2 keys output with this value - optional
#        <retries>n      - if the value does not exist or is 'none' then retry this many times before erroring - optional, default 5
#       <retry-delay>n  - wait this long (in seconds) between retries - optional, default 5

my $version='$Rev: 472 $ $LastChangedDate: 2013-08-14 14:25:30 +0100 (Wed, 14 Aug 2013) $';


use warnings;
#use strict;

use File::Copy;
use File::Temp  qw/tempfile/;
#use XML::SAX;
use Data::Dumper;
use Template;

#use lib ".";
use CDS::octopus_simple;
#use saxmeta;
use CDS::Datastore;

sub check_args {

}

#START MAIN
my $default_template_path="/etc/cds_backend/templates";
#my $retries,$retry_delay,$metafile,$meta_parent,$key_prefix,$template_path,$output_template,$debug;

if(not CDS::octopus_simple::is_working){
	print "-ERROR: Unable to initialise octopus_simple module.  Check that octopus_util is installed, executable and octopus_simple.pm knows where it is.\n";
	exit 1;
}

my $store=CDS::Datastore->new('octopus_get_r2_data');

if(defined $ENV{'retries'}){
	$retries=$ENV{'retries'};
} else {
	$retries=5;
}

if(defined $ENV{'retry-delay'}){
	$retry_delay=$ENV{'retry-delay'};
} else {
	$retry_delay=5;
}

$key_prefix=$ENV{'r2_key_prefix'};
$key_prefix=$key_prefix."-" unless($key_prefix=~/[\-_]$/); #if($key_prefix ne '');

#if(defined $ENV{'cf_meta_file'}){
#	$metafile=$ENV{'cf_meta_file'};
#	$meta_parent="meta";
#} elsif(defined $ENV{'cf_inmeta_file'}){
#	$metafile=$ENV{'cf_inmeta_file'};
#	$meta_parent="meta";
#} else {
#	print "-ERROR: Neither meta nor inmeta file was provided, unable to continue\n";
#	exit 1;
#}

#if(defined $ENV{'template_path'}){
#	$template_path=$ENV{'template_path'};
#} else {
#	$template_path=$default_template_path;
#}

#if(defined $ENV{'output_template'}){
#	$output_template=$template_path.'/'.$ENV{'output_template'};
#} else {
#	print "-ERROR: output template was not specified, use the <output_template>blah</output_template> in the route file.\n";
#	exit 1;
#}

if(defined $ENV{'debug'}){
	$debug=1;
} else {
	$debug=0;
}

#if(not -f $metafile){
#	print "-ERROR: Unable to open provided meta-data file $metafile.\n";
#	exit 1;
#}

#my $parser=XML::SAX::ParserFactory->parser(Handler=>saxmeta->new);
#$parser->{'Handler'}->{'config'}->{'keep-simple'}=1;
#$parser->{'Handler'}->{'config'}->{'keep-spaces'}=1;
#$parser->parse_uri($metafile);

#print Dumper($parser->{'Handler'}->{'content'}) if($debug);

#FIXME: is this valid for both meta and inmeta??
#my $octid=$parser->{'Handler'}->{'content'}->{$meta_parent}->{$ENV{'octopus_id_key'}};

unless($ENV{'octopus_id_key'}){
	print STDERR "-ERROR: you must specify a metadata key to retrieve the Octopus ID in <octopus_id_key>blah\n";
	exit 1;
}
my $octid=$store->get('meta',$ENV{'octopus_id_key'},undef);

if(not defined $octid){
	print "-ERROR: Unable to locate octopus ID data in key '".$ENV{'octopus_id_key'}."'.\n";
	exit 1;
}
if(not $octid=~/^\d+$/){
	print "-ERROR: Octopus ID data in key '".$ENV{'octopus-id-key'}."' of the datastore appears to be incorrect (zero-length or contains non-digit characters)\n";
	exit 1;
}

my $octdata=CDS::octopus_simple::get_header($octid);
if(not defined $octdata){
	print "-ERROR: Unable to look up data for id '$octid' within Octopus.\n";
	exit 1;
}
if(not defined $octdata->{'path'}){
	print "-ERROR: 'path' data is not defined by octopus for id '$octid'.\n";
	exit 1;
}

print Dumper($octdata) if($debug);

my %r2data;
($r2data{'id'},$r2data{'url'},$r2data{'lastop'},$r2data{'page-status'},$r2data{'video-status'})=split(/#/,$octdata->{'path'});
$r2data{'url'}=~/^http:\/\/[^\/]*(\/.*)$/;
$r2data{'cmspath'}=$1;
if(not $r2data{'id'}=~/^\d+$/ and not $ENV{'allow_invalid_id'}){
	print "-ERROR: returned r2 id does not appear to be valid.  Returned path string was '".$octdata->{'path'}."'.\n";
	exit 1;
}
($r2data{'restriction'},$r2data{'mobile'},$r2data{'explicit'},$r2data{'aspect'})=split(/#/,$octdata->{'info4'});
if($r2data{'aspect'}==0){
	$r2data{'aspect'}='16x9';
} else {
	$r2data{'aspect'}='4x3';
}

$r2data{'original-source'}=$octdata->{'info7'};
#getting the Brightcove ID here is great in principle, but if we're being called in an upload operation it probably won't have been set yet, or may point
#to the previous version of the video that's being replaced.
my $temp;
$temp=$octdata->{'INFO5'} if(defined $octdata->{'INFO5'});
$temp=$octdata->{'info5'};

($fcsid,$r2data{'trailpic-id'},$bcid)=split(/#/,$temp);

print Dumper(\%r2data) if($debug);

my @args=('meta');
foreach(keys %r2data){
	push @args,($key_prefix.$_,$r2data{$_});
}
$store->set(@args);

print "+SUCCESS: r2-related octopus metadata has been output to datastore.\n";
