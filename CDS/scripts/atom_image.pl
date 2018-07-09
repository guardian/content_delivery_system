#!/usr/bin/env perl

#This CDS module attempts to acquire an image URL from CAPI given an Atom id. as an input.
#Arguments:
# <atom_id> - the Atom id. of the video 

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

my $response;
while(true) {
	$response = $ua->request(GET 'https://internal.content.guardianapis.com/atom/media/'.$store->substitute_string($ENV{'atom_id'}));
	if($response->code >=400 && $response->code <=499){
     	print $response->content;
     	print "\n-ERROR: CAPI returned " . $response->code . ", actual error is logged above.\n";
     	exit(1);
  	} elsif ($response->code >=500 && $response->code <= 599){
     	print $response->content;
     	print "\n-ERROR: CAPI returned " . $response->code . ", actual error is logged above.\n";
     	exit(1) if($retries>=8);
     	sleep(20);
     	continue;
  	} elsif($response->code==200){
      	print "*INFO: Got response from CAPI\n";
      	last;
  	} else {
      	print "-ERROR: Unexpected status code ".$response->code." from CAPI, retrying";
      	sleep(20);
      	continue;
    }
    $retries = $retries + 1;
}

my $capi = decode_json($response->content);

unless (is_imageurl_valid($capi->{'response'}->{'media'}->{'data'}->{'media'}->{'trailImage'}->{'master'}->{'file'})) {
	exit(1);
}

print "INFO: Outputting image URL ".$capi->{'response'}->{'media'}->{'data'}->{'media'}->{'trailImage'}->{'master'}->{'file'}."\n";

$store->set('meta','atom_image_url',$capi->{'response'}->{'media'}->{'data'}->{'media'}->{'trailImage'}->{'master'}->{'file'});

print "+SUCCESS: URL acquired\n";