#!/usr/bin/env perl

#This CDS module attempts to acquire an image URL from CAPI given an Atom id. as an input.
#Arguments:
# <atom_id> - the Atom id. of the video 

#END DOC
  
use LWP::UserAgent;
use JSON;
use CDS::Datastore;

sub is_imageurl_valid {
	my ($url_to_check) = @_;

	my $url_status = 1;

	if (($url_to_check eq "") || ($url_to_check eq "http://invalid.url")) {
		$url_status = 0;
	}
	
	return $url_status;
}

#START MAIN

my $store=CDS::Datastore->new('atom_image');

print "INFO: Attempting to get image URL from CAPI\n";

my $ua = LWP::UserAgent->new;
my $req = $ua->request(GET 'https://internal.content.guardianapis.com/atom/media/'.$store->substitute_string($ENV{'atom_id'}));

my $capi = decode_json($req->content);

unless (is_imageurl_valid($capi->{'response'}->{'media'}->{'data'}->{'media'}->{'trailImage'}->{'master'}->{'file'})) {
	print "-ERROR: Unable to get URL. \n";
	exit(1);
}

print "INFO: Outputting image URL ".$capi->{'response'}->{'media'}->{'data'}->{'media'}->{'trailImage'}->{'master'}->{'file'}."\n";

$store->set('meta','atom_image_url',$capi->{'response'}->{'media'}->{'data'}->{'media'}->{'trailImage'}->{'master'}->{'file'});

print "+SUCCESS: URL acquired\n";