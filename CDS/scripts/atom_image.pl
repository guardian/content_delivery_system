#!/usr/bin/env perl

#This CDS module attempts to acquire an image URL from CAPI given an Atom id. as an input.
#Arguments:
# <atom_id> - the Atom id. of the video
# <max_retries> - maximum number of times to try connecting to CAPI 
# <sleep_delay> - number of seconds to wait before each retry

#END DOC
  
use LWP::UserAgent;
use JSON;
use CDS::Datastore;
use HTTP::Request::Common;

sub is_imageurl_valid {
	my ($url_to_check) = @_;

	my $url_status = 1;

	if ($url_to_check eq "") {
		$url_status = 0;
		print "-ERROR: Unable to get URL. Got ".$url_to_check.". Malformed string\n";
	}
	
	return $url_status;
}

#START MAIN

my $store=CDS::Datastore->new('atom_image');

print "INFO: Attempting to get image URL from CAPI\n";

my $ua = LWP::UserAgent->new;

my $retries = 0;
my $max_retries = 8;
if(defined $ENV{'max_retries'}){
	$max_retries = $store->substitute_string($ENV{'max_retries'});
}
my $sleep_delay = 20;
if(defined $ENV{'sleep_delay'}){
	$sleep_delay = $store->substitute_string($ENV{'sleep_delay'});
}

my $response;
while(true) {
	$response = $ua->request(GET 'https://content.guardianapis.com/atom/media/'.$store->substitute_string($ENV{'atom_id'}).'?api-key='.$store->substitute_string($ENV{'api_key'}));
	if($response->code >=400 && $response->code <=499){
		print $response->content;
		print "\n-ERROR: CAPI returned " . $response->code . ", actual error is logged above.\n";
		exit(1);
	} elsif ($response->code >=500 && $response->code <= 599){
		print $response->content;
		print "\n-ERROR: CAPI returned " . $response->code . ", actual error is logged above.\n";
		exit(1) if($retries>=$max_retries);
		sleep($sleep_delay);
		continue;
	} elsif($response->code==200){
		print "*INFO: Got response from CAPI\n";
		last;
	} else {
		print "-ERROR: Unexpected status code ".$response->code." from CAPI, retrying";
		sleep($sleep_delay);
		continue;
	}
	$retries = $retries + 1;
}

my $capi = decode_json($response->content);

if(defined $ENV{'output-smaller-than'}){
  my %image_urls;
  my $image_place = 0;
  while($image_place < 20) {
    if ($capi->{'response'}->{'media'}->{'data'}->{'media'}->{'trailImage'}->{'assets'}->{$image_place}->{'dimensions'}->{'height'} < $store->substitute_string($ENV{'output-smaller-than-height'}) {
      if ($capi->{'response'}->{'media'}->{'data'}->{'media'}->{'trailImage'}->{'assets'}->{$image_place}->{'dimensions'}->{'width'} < $store->substitute_string($ENV{'output-smaller-than-width'}) {
        $image_urls{$image_place} = $capi->{'response'}->{'media'}->{'data'}->{'media'}->{'trailImage'}->{'assets'}->{$image_place}->{'dimensions'}->{'width'};
      }
    }
    $image_place = $image_place + 1;
  }
  my @image_urls_sorted = sort {$b <=> $a} (values %image_urls);
  unless (is_imageurl_valid($capi->{'response'}->{'media'}->{'data'}->{'media'}->{'trailImage'}->{'assets'}->{@image_urls_sorted[0]}->{'file'})) {
  	exit(1);
  }
  print "INFO: Outputting image URL ".$capi->{'response'}->{'media'}->{'data'}->{'media'}->{'trailImage'}->{'assets'}->{@image_urls_sorted[0]}->{'file'}."\n";
  $store->set('meta','atom_image_url',$capi->{'response'}->{'media'}->{'data'}->{'media'}->{'trailImage'}->{'assets'}->{@image_urls_sorted[0]}->{'file'});
} else {
  unless (is_imageurl_valid($capi->{'response'}->{'media'}->{'data'}->{'media'}->{'trailImage'}->{'master'}->{'file'})) {
  	exit(1);
  }
  print "INFO: Outputting image URL ".$capi->{'response'}->{'media'}->{'data'}->{'media'}->{'trailImage'}->{'master'}->{'file'}."\n";
  $store->set('meta','atom_image_url',$capi->{'response'}->{'media'}->{'data'}->{'media'}->{'trailImage'}->{'master'}->{'file'});
}

print "+SUCCESS: URL acquired\n";
