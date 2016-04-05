#!/usr/bin/perl

my $version='$Rev: 559 $ $LastChangedDate: 2013-11-03 14:20:56 +0000 (Sun, 03 Nov 2013) $';

#this script queries the Brightcove API to get metadata for an id number given in the .meta/.inmeta file
#
#  <take-files>{inmeta|meta} - use either the .meta/.inmeta file
#  	<brightcove-id-key>blah - use this metadata key to get the brightcove id
#	<brightcove-key-prefix>blah - prepend this string to the fieldnames given by brightcove when outputting
# to the .meta file
#	<keyfile>blah			- this file contains the secret key data to communicate with API
#	<output_template>blah - use this template to output metadata (usually meta.tt or inmeta.tt)
#	<template_path>blah [optional] - use a non-standard template path (default: /etc/cds_backend/templates)

#	<retries>n	[optional]	- keep trying this many times if communication fails (default: 5)
#	<retry-delay>n [optional] - wait this long between retries, in seconds (default: 5)
#	<debug/> [optional] - output tons of debugging information
#END DOC

use Data::Dumper;
use Template;
use LWP::Simple;
use XML::Simple;
use File::Temp qw/tempfile/;
use File::Copy;
use CDS::Datastore;


#need to get load_keydata, output_metadata from level3_cache_invalidate
sub load_keydata {
my ($filename)=@_;

my %data;

open $fh,"<$filename" or return undef;
my @lines=<$fh>;

foreach(@lines){
	chomp;
#	print $_."\n";
	if(/^([^:]+):\s*(.*)$/){
		$data{$1}=$2;
	}
}
close $fh;

#print Dumper(\%data);
#die;
return \%data;
}

#sub output_meta_file {
#my ($metafile,$output)=@_;
#
#my ($fh, $filename) = tempfile();
#print "DEBUG: outputting metadata to temp file $filename.\n" if $debug;
#print $fh $output;
#
#close $fh;
#
#print "DEBUG: deleting $metafile and replacing with $filename.\n" if $debug;
#unlink($metafile);
#move($filename,$metafile);
#}

sub send_request {
my($bcid,$token,$retries,$retry_delay,$debug)=@_;

my $query_url="http://api.brightcove.com/services/library?command=find_video_by_id&video_id=$bcid&output=mrss&token=$token";
print STDERR "debug: query_url is '$query_url'\n" if($debug);

my $n=0;
my $result=undef;

while(not defined $result or $result=~/^\s*$/){	#is result empty or composed entirely of whitespace
	$result=get($query_url); #get() is an LWP::Simple call
	if(not defined $result){
		++$n;
		if($n>$retries){
			print STDERR "-ERROR: Unable to get a response from Brightcove after $n attempts. Giving up.\n";
			return undef;
		}
		sleep($retry_delay);
		print STDERR "-WARNING: Unable to get a response from Brightcove on attempt $n/$retries.  Retrying...\n";
	}
}

if($debug){
	print "Got result:\n";
	print "\t$_\n" foreach(split /\n/,$result);
}

my $data=XMLin($result);

return $data;
}
	
#this routine converts the 2d data returned by Brightcove into a flat structure for a .meta file
sub process_fields {
my ($bcdata,$prefix)=@_;

#first up, collapse any arrays into multiple hashes
foreach(keys %{$bcdata}){
	my $n=1;
	my $masterkey=$_;
	if(ref $bcdata->{$_} eq 'ARRAY'){
		foreach(@{$bcdata->{$_}}){
			my $subdata=$_;
			foreach(keys %$_){
				my $newname=$masterkey."_".$n."_".$_;
				$bcdata->{$newname}=$subdata->{$_};
			}
			#delete $_;
			++$n;
		}
		delete $bcdata->{$_};
	}
}

#next, collapse any structures so media:thumnail->width becomes media:thumbnail_width
foreach(keys %{$bcdata}){
	my $masterkey=$_;
	if(ref $bcdata->{$_} eq 'HASH'){
		foreach(keys %{$bcdata->{$_}}){
			$bcdata->{"$masterkey"."_$_"}=$bcdata->{$masterkey}->{$_};
		}
		delete $bcdata->{$_};
	}
}

#now, remove any : from names so bc:titleid becomes titleid and add in the given prefix
foreach(keys %{$bcdata}){
	my $org_name=$_;
	if(/:([^:]+)$/){
		$new_name=$1;
	} else {
		$new_name=$org_name;
	}
	$new_name="$prefix$new_name";
	$bcdata->{$new_name}=$bcdata->{$org_name};
	delete $bcdata->{$org_name};
}

print "\nInfo: process_fields complete.\n";
return $bcdata;
}

#START MAIN
my $store=CDS::Datastore->new('get_brightcove_metadata');
if(defined $ENV{'debug'}){
	$debug=1;
} else {
	$debug=0;
}

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

$key_prefix=$ENV{'brightcove_key_prefix'};
$key_prefix=$key_prefix."_" if($key_prefix ne '');

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

if(defined $ENV{'template_path'}){
	$template_path=$ENV{'template_path'};
} else {
	$template_path=$default_template_path;
}

#if(defined $ENV{'output_template'}){
#	$output_template=$template_path.'/'.$ENV{'output_template'};
#} else {
#	print "-ERROR: output template was not specified, use the <output_template>blah</output_template> in the route file.\n";
#	exit 1;
#}

if(not defined $ENV{'keyfile'}){
	print "-ERROR: keyfile was not specified.  You must specify a file containing a valid Brightcove API key\nwith the <keyfile>blah argument.\n";
	exit 1;
}

print "MESSAGE: Loading key data...\n";
my $keydata=load_keydata($ENV{'keyfile'});
if(not defined $keydata){
	print "-ERROR: Unable to load API key data from '".$ENV{'keyfile'}."'.\n";
	exit 1;
}
print Dumper($keydata) if($debug);
print "MESSAGE: Done.\n";

#print "MESSAGE: Loading metadata file $metafile...\n";
#if(not -f $metafile){
#	print "-ERROR: Unable to open provided meta-data file $metafile.\n";
#	exit 1;
#}

#my $parser=XML::SAX::ParserFactory->parser(Handler=>saxmeta->new);
#$parser->{'Handler'}->{'config'}->{'keep-simple'}=1;
#$parser->{'Handler'}->{'config'}->{'keep-spaces'}=1;
#$parser->parse_uri($metafile);

#$metadata=$parser->{'Handler'}->{'content'};
#print Dumper($parser->{'Handler'}->{'content'}) if($debug);
#print "MESSAGE: Done\n";

my $bcid;
if($ENV{'bcid'} ne ""){
	$bcid=$ENV{'bcid'};
} else { 
	$bcid=$store->get('meta',$ENV{'brightcove_id_key'});
}

if(not defined $bcid){
	print "-ERROR: Unable to locate brightcove ID data in key '".$ENV{'brightcove_id_key'}."' of file $metafile.\n";
	exit 1;
}
if(not $bcid=~/^\d+$/){
	print "-ERROR: Brightcove ID data in key '".$ENV{'brightcove_id_key'}."' of file $metafile appears to be incorrect (zero-length or contains non-digit characters)\n";
	exit 1;
}

print "MESSAGE: Requesting metadata from Brightcove...\n";
my $data=send_request($bcid,$keydata->{'Secret'},$retries,$retry_delay,$debug);
print "MESSAGE: Done\n";
print Dumper($data) if($debug);
if(not defined $data->{'channel'}->{'item'}){	#if this chunk was missing then it's a blank reply
	print "INFO - returned data:\n";
	print Dumper($data);
	print "-ERROR - Brightcove returned no item for ID $bcid.\n";
	exit 1;
}

print "MESSAGE: Processing reply...\n";
my $bcdata=process_fields($data->{'channel'}->{'item'},$key_prefix);	#this is where the actual metadata is stored

if($debug){
	print "debug: data from process_fields for insertion:\n";
	print Dumper($bcdata);
}

print "MESSAGE: Done\nMESSAGE: Inserting brightcove metadata into metadata stream...\n";
my @args;

push @args,'meta';

foreach(keys %{$bcdata}){
	#$metadata->{'meta'}->{$_}=$bcdata->{$_};
	push @args,($_,$bcdata->{$_});
}

$store->set(@args);

#$parser->{'Handler'}->escape_for_xml;

#if($debug){
#	print "debug: data to output:\n";
#	print Dumper($metadata);
#}

#my $tt=Template->new(ABSOLUTE=>1);
#$tt->process($output_template,$metadata,\$output) or die "-ERROR: problem with template: ".$tt->error;
#print $output if($debug);

#output_meta_file($metafile,$output);
print "+SUCCESS: Brightcove metadata has been output.\n";
