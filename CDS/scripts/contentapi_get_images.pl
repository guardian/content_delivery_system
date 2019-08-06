#!/usr/bin/perl
$|=1;

#this module queries the Content API to get information about the images associated with a given video
#WARNING: for this to succeed, the video must be LIVE on the site.
#A 'not found' error will be returned if the video page is not live.
#Use of <non-fatal/> is recommended when using this module, and gracefully
#handling the case when no data is returned

#Arguments:
# <octopus_id_key>blah [optional] - use this datastore key to get the Octopus ID.  Defaults to 'octopus ID'.
# <output_key_prefix>blah [optional] - prefix this to all keys that are output. Defaults to '' (blank string).
# <output_fields>field1|field2|field3... [optional] - only output these fields.
#END DOC

my $version='contentapi_get_images $Rev: 754 $ $LastChangedDate: 2014-02-10 17:42:40 +0000 (Mon, 10 Feb 2014) $';

use CDS::Datastore;
use LWP::UserAgent;
use JSON;
use Data::Dumper;

#configurable parameters
my $webservice_base="http://content.guardianapis.com";

my $params='format=json&show-media=all&order-by=newest';
#my $debug=1;
#end configurable parameters

sub api_lookup {
my ($octid,$apikey)=@_;

unless($octid=~/^\d+$/){
	print "-ERROR: '$octid' doesn't look like an Octopus ID (not numeric)\n";
	return undef;
}

# CAPI access code changed in August 2019 because of a change to CAPI
my $url;

$url="$webservice_base/internal-code/octopus/$octid.json?$params&api-key=$apikey";

print "info: about to query $url\n" if($debug);
my $ua=LWP::UserAgent->new;
$ua->timeout($ENV{'http_timeout'}) if($ENV{'http_timeout'});
$ua->env_proxy;

my $response=$ua->get($url);

my $jsondata;
if($response->is_success){
	$jsondata=$response->decoded_content;
} else {
	print "-ERROR: Content API returned status \"".$response->status_line."\" querying octopus ID $octid.\n";
	return undef;
}

if($jsondata){
	return from_json($jsondata);
} else {
	print "-ERROR: Unable to retrieve open platform information for octopus ID $octid: $jsondata\n";
	return undef;
}
}

sub get_image_records {
my $arrayref=shift;

my @output;
foreach(@$arrayref){
	#print Dumper($_);
	my %rtn;
	my $record=$_;
	next unless($_->{'rel'} eq 'alt-size');	#all images are tagged with alt-size
	next unless($_->{'type'} eq 'picture');

	foreach(keys %{$record->{'fields'}}){
		$rtn{$_}=$record->{'fields'}->{$_};
	}
	foreach(keys %{$record}){
		next if($_ eq 'rel');
		next if($_ eq 'type');
		next if(ref $record->{$_} ne '');
		$rtn{$_}=$record->{$_};
	}
	#print "TAKEN IMAGE\n";
	push @output,\%rtn;
}
return \@output;
}

sub is_in_array_or_empty {
my($needle,$haystack)=@_;

return 1 unless(defined $haystack->[0]);
foreach(@$haystack){
	return 1 if($needle eq $_);
}
return 0;
}

#START MAIN
my $delimiter='|';	#should not change this, it's standard for all CDS modules.
my $key_prefix='';
my $octopus_id_key='octopus ID';
my @output_fields;

local $api_key=$ENV{'api_key'};

print "INFO: $version\n";

if($ENV{'octopus_id_key'}){
	$octopus_id_key=$ENV{'octopus_id_key'};
}

if($ENV{'output_key_prefix'}){
	$key_prefix=$ENV{'output_key_prefix'};
}

if($ENV{'output_fields'}){
	@output_fields=split /\|/,$ENV{'output_fields'};
}

$debug=$ENV{'debug'};

my $store=CDS::Datastore->new('contentapi_get_images');

my $octid;

eval {
	$octid=$store->get('meta',$octopus_id_key);
};
if($@){
	print "-ERROR: Unable to access datastore: $@\n";
	exit 1;
}

unless($octid=~/^\d+$/){
	print "-ERROR: Key '$octopus_id_key' returned '$octid', which doesn't look like an Octopus ID (not numeric)\n";
	exit 1;
}

print "INFO: Querying octopus ID $octid\n";

my $info=api_lookup($octid,$api_key);
print Dumper($info) if($debug);

unless($info->{'response'}->{'status'} eq 'ok'){
	print "-ERROR: Content API did not return ok status.\n";
	print Dumper($info) unless($debug);	#if we're in debug mode we've already output this...
	exit 1;
}

my $image_array=get_image_records($info->{'response'}->{'content'}->{'mediaAssets'});
#print Dumper($image_array) if($debug);

my %output;
foreach(@$image_array){
	my $record=$_;
	print Dumper($record) if($debug);
	foreach(keys %{$record}){
		next if($_ eq '');
		next unless(is_in_array_or_empty($_,\@output_fields));
		my $key=$key_prefix.$_;
		#print "$key\n";
		$output{$key}=$output{$key}.$delimiter.$record->{$_};
	}
}

my @toset;
push @toset,'meta';
foreach(keys %output){
	$output{$_}=~s/^\|//;
	push @toset,($_,$output{$_});
}

eval {
	$store->set(@toset);
};
if($@){
	print "-ERROR: Unable to set values in data store.  Data store said:\n";
	foreach(split /\n/,$@){
		print "\t$_\n";
	}
	exit 1;
}

print Dumper(\%output) if($debug);

