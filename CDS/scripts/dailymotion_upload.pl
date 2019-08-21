#!/usr/bin/env perl

$|=1;

$longversion='dailymotion_upload.pl from master revision $Rev: 1393 $ $LastChangedDate: 2015-10-08 15:28:13 +0100 (Thu, 08 Oct 2015) $';
$version='dailymotion_upload.pl $Rev: 1393 $';

#This CDS module uploads a video and various associated data to Dailymotion via their API for display on a Dailymotion page.
#Arguments:
# <video_title>blah - the title of the video
# <video_description>blah - the description of the video
# <video_category>blah - the content category of the video
# <video_tags>blah - tags for the video. At least one is required
# <video_mobile>weather or not to ban mobile access to the video. Currently disabled due to partner status requirement
# <video_adult>weather or not the video contains adult content
# <video_holding_image>blah - URL of an image for use with the video
# <video_language>blah - two letter code representing the language of the video
# <client_id>blah Dailymotion app client id
# <client_secret>blah Dailymotion app secret
# <username>blah Username of Dailymotion account
# <password>blah Password of Dailymotion account

#END DOC
  
use LWP::UserAgent;
use JSON;
use Data::Dumper;
use File::Basename;
use CDS::Datastore;
use HTTP::Request::Common;
use HTTP::Request::Common qw(POST $DYNAMIC_FILE_UPLOAD);

sub is_imageurl_valid {
	my ($url_to_check) = @_;

	my $url_status = 1;

	if (($url_to_check eq "") || ($url_to_check eq "http://invalid.url")) {
		$url_status = 0;
	}
	
	return $url_status;
}

#START MAIN

my $store=CDS::Datastore->new('dailymotion_upload');

print "INFO: Setting up parameters\n";

my $videolanguage = 'en';
$videolanguage = $store->substitute_string($ENV{'video_language'});
my $videotitle = $store->substitute_string($ENV{'video_title'});
my $videodescription = $store->substitute_string($ENV{'video_description'});
my $videocat = $store->substitute_string($ENV{'video_category'});
#my $videoembed = "1";
#my $videons = "0";
my $videotaken = 1287507036;
my $imageurl = $store->substitute_string($ENV{'video_holding_image'});

my $tagstring = $store->substitute_string($ENV{'video_tags'});

my $outputtags =~ s/\|/, /g;

my @tags=split /\|/,$tagstring;

if ($videocat eq 'news') {

	if (grep { $_ eq 'celebrity' } @tags) {
		$videocat = 'people';
	}
	
	if (grep { $_ eq 'animals' } @tags) {
		$videocat = 'animals';
	}

	if (grep { $_ eq 'television' } @tags) {
		$videocat = 'tv';
	}
	
	if (grep { $_ eq 'travel' } @tags) {
		$videocat = 'travel';
	}
	
	if (grep { $_ eq 'beauty' } @tags) {
		$videocat = 'lifestyle';
	}
	
	if (grep { $_ eq 'fashion' } @tags) {
		$videocat = 'lifestyle';
	}
	
	if (grep { $_ eq 'life and style' } @tags) {
		$videocat = 'lifestyle';
	}
	
	if (grep { $_ eq 'entertainment' } @tags) {
		$videocat = 'fun';
	}
	
	if (grep { $_ eq 'games' } @tags) {
		$videocat = 'videogames';
	}
	
	if (grep { $_ eq 'comedy' } @tags) {
		$videocat = 'fun';
	}

	if (grep { $_ eq 'education' } @tags) {
		$videocat = 'school';
	}

	if (grep { $_ eq 'technology' } @tags) {
		$videocat = 'tech';
	}	

	if (grep { $_ eq 'art and design' } @tags) {
		$videocat = 'creation';
	}
		
	if (grep { $_ eq 'art' } @tags) {
		$videocat = 'creation';
	}
		
	if (grep { $_ eq 'music' } @tags) {
		$videocat = 'music';
	}
	
	if (grep { $_ eq 'film' } @tags) {
		$videocat = 'shortfilms';
	}
	
	if (grep { $_ eq 'sport' } @tags) {
		$videocat = 'sport';
	}	
	
	if (grep { $_ eq 'news' } @tags) {
		$videocat = 'news';
	}	

}

if(scalar @tags>10){
	print "-WARNING: More than 10 tags have been specified, so we will only use the first 10.\n";
	@tags = splice(@tags,0,10);
}

if (grep { $_ eq 'uk news' } @tags) {
	push @tags, 'United Kingdom';
	push @tags, 'United Kingdom of Great Britain and Northern Ireland';
}

if (grep { $_ eq 'germany' } @tags) {
	push @tags, 'Deutschland';
	push @tags, 'Federal Republic of Germany';
	push @tags, 'Bundesrepublik Deutschland';
}

if (grep { $_ eq 'france' } @tags) {
	push @tags, 'French Republic';
}

if (grep { $_ eq 'italy' } @tags) {
	push @tags, 'Italia';
	push @tags, 'Italian Republic';
	push @tags, 'Repubblica Italiana';
}

if (grep { $_ eq 'russia' } @tags) {
	push @tags, 'Russian Federation';
}

if (grep { $_ eq 'spain' } @tags) {
	push @tags, 'Kingdom of Spain';
}

if (grep { $_ eq 'turkey' } @tags) {
	push @tags, 'Republic of Turkey';
	push @tags, 'West Asia';
	push @tags, 'Asia';
	push @tags, 'Middle East';
}

if (grep { $_ eq 'china' } @tags) {
	push @tags, "People's Republic of China";
	push @tags, 'Asia';
	push @tags, 'East Asia';
}

if (grep { $_ eq 'india' } @tags) {
	push @tags, 'Republic of India';
	push @tags, 'Asia';
	push @tags, 'South Asia';
}

if (grep { $_ eq 'japan' } @tags) {
	push @tags, 'Asia';
	push @tags, 'East Asia';
}

if (grep { $_ eq 'syria' } @tags) {
	push @tags, 'Syrian Arab Republic';
	push @tags, 'West Asia';
	push @tags, 'Asia';
	push @tags, 'Middle East';
}

if (grep { $_ eq 'morocco' } @tags) {
	push @tags, 'Kingdom of Morocco';
	push @tags, 'Maghreb';
	push @tags, 'North Africa';
	push @tags, 'Africa';
}

if (grep { $_ eq 'tunisia' } @tags) {
	push @tags, 'Tunisian Republic';
	push @tags, 'Maghreb';
	push @tags, 'North Africa';
	push @tags, 'Africa';
}

if (grep { $_ eq 'nigeria' } @tags) {
	push @tags, 'Federal Republic of Nigeria';
	push @tags, 'West Africa';
	push @tags, 'Africa';
}

if (grep { $_ eq 'united arab emirates' } @tags) {
	push @tags, 'West Asia';
	push @tags, 'Asia';
	push @tags, 'Middle East';
}

if (grep { $_ eq 'south korea' } @tags) {
	push @tags, 'Republic of Korea';
	push @tags, 'Korean Peninsula';
	push @tags, 'Asia';
	push @tags, 'East Asia';
}

if (grep { $_ eq 'australia news' } @tags) {
	push @tags, 'Commonwealth of Australia';
	push @tags, 'Oceania';
	push @tags, 'Australasia';
}

if (grep { $_ eq 'new zealand' } @tags) {
	push @tags, 'Oceania';
	push @tags, 'Australasia';
}

if (grep { $_ eq 'us news' } @tags) {
	push @tags, 'United States';
	push @tags, 'United States of America';
	push @tags, 'USA';
	push @tags, 'North America';
	push @tags, 'The Americas';	
}

if (grep { $_ eq 'canada' } @tags) {
	push @tags, 'North America';
	push @tags, 'The Americas';	
}

if (grep { $_ eq 'brazil' } @tags) {
	push @tags, 'Federative Republic of Brazil';
	push @tags, 'South America';
	push @tags, 'The Americas';	
}

if (grep { $_ eq 'colombia' } @tags) {
	push @tags, 'Republic of Colombia';
	push @tags, 'South America';
	push @tags, 'The Americas';	
}

if (grep { $_ eq 'honduras' } @tags) {
	push @tags, 'Republic of Honduras';
	push @tags, 'North America';
	push @tags, 'The Americas';	
}

if (grep { $_ eq 'guatemala' } @tags) {
	push @tags, 'Republic of Guatemala';
	push @tags, 'North America';
	push @tags, 'The Americas';	
}

if (grep { $_ eq 'el salvador' } @tags) {
	push @tags, 'Republic of El Salvador';
	push @tags, 'North America';
	push @tags, 'The Americas';	
}

if (grep { $_ eq 'haiti' } @tags) {
	push @tags, 'Republic of Haiti';
	push @tags, 'Hispaniola';
	push @tags, 'Greater Antilles';
	push @tags, 'Caribbean';
	push @tags, 'North America';
	push @tags, 'The Americas';	
}

if (grep { $_ eq 'film' } @tags) {
	push @tags, 'Movie';
	push @tags, 'Cinema';
	push @tags, 'Motion picture';
}

if (grep { $_ eq 'football' } @tags) {
	push @tags, 'Soccer';
	push @tags, 'Association football';
}

if (grep { $_ eq 'whales' } @tags) {
	push @tags, 'Animals';
	push @tags, 'Mammals';
}

if (grep { $_ eq 'bbc' } @tags) {
	push @tags, 'British Broadcasting Corporation';
}

if (grep { $_ eq 'fbi' } @tags) {
	push @tags, 'Federal Bureau of Investigation';
}

if (grep { $_ eq 'nasa' } @tags) {
	push @tags, 'National Aeronautics and Space Administration';
}

if (grep { $_ eq 'nsa' } @tags) {
	push @tags, 'National Security Agency';
}

if (grep { $_ eq 'farc' } @tags) {
	push @tags, 'Revolutionary Armed Forces of Colombia';
	push @tags, 'Fuerzas Armadas Revolucionarias de Colombia';
}

if (grep { $_ eq 'nra' } @tags) {
	push @tags, 'National Rifle Association of America';
}

if (grep { $_ eq 'nypd' } @tags) {
	push @tags, 'City of New York Police Department';
	push @tags, 'New York City Police Department';
}

@tags = splice(@tags,0,10);

my $tags = join(', ',@tags);

my $block = 0;

if ($store->substitute_string($ENV{'video_mobile'}) eq "no_mobile_access") {
	$block = 1;
}

my $adult = 'false';

if ($store->substitute_string($ENV{'video_adult'}) eq "contains_adult_content") {
	$adult = 'true';
}

print "INFO: Logging in to Daily Motion\n";
my $file, $result, $message;



my $req = $ua->request(POST 'https://api.dailymotion.com/oauth/token',
	  Content_Type => 'application/x-www-form-urlencoded',
	  Content => [
		  grant_type=>"password",
		  client_id=>$store->substitute_string($ENV{'client_id'}),
		  client_secret=>$store->substitute_string($ENV{'client_secret'}),
		  username=>$store->substitute_string($ENV{'username'}),
		  password =>$store->substitute_string($ENV{'password'}),
		  scope=>"manage_videos"
	  ]
);

print $req->request()->as_string();
 	
print "\nRESPONSE -- \n" . $req->as_string;
 
# Check the outcome of the response

unless ($req->is_success) {
    print "-ERROR: Unable to log in to daily motion. Server response was ".$req->code.": ".$req->message."\n";
	exit(1);
}

print "INFO: Getting token to upload file...\n";
my $server = decode_json($req->content);

my $req = $ua->request(GET 'https://api.dailymotion.com/file/upload?access_token='.$server->{'access_token'});

print $req->request()->as_string();
 	

print "\nRESPONSE -- \n" . $req->as_string;
 
# Check the outcome of the response

unless ($req->is_success) {
	print "-ERROR: Unable to get token. Server response was ".$req->code.": ".$req->message."\n";
	print $req->decoded_content;
	print "\n";
	exit(1);
}

my $server2 = decode_json($req->content);

my $ua = LWP::UserAgent->new;
my $req;

print "INFO: Uploading file ".$ENV{'cf_media_file'}." to DM...\n";
$DYNAMIC_FILE_UPLOAD=1;
my $request   =  HTTP::Request::Common::POST
  $server2->{'upload_url'},
  Content_Type => 'form-data',
  Content => [ 'file' => [ $ENV{'cf_media_file'} ] ];

print Dumper($req);

my $resp = $ua->request($request);

print Dumper($resp->request()->as_string());

print "\nRESPONSE-- \n". $resp->as_string;

if(not $resp->is_success){
	print "\n It didn't work :(\n";
	exit(1);
}

my $server3 = decode_json($resp->content);
print "INFO: Adding uploaded file ".$server3->{'url'}." as a video to account...\n";
my $req = $ua->request(POST 'https://api.dailymotion.com/me/videos?',
	  Content_Type => 'application/x-www-form-urlencoded',
	  Content => [
		  url=>$server3->{'url'},
		  access_token=>$server->{'access_token'}
	  ]
);

print $req->request()->as_string();
 	
print "\nRESPONSE -- \n" . $req->as_string;
 
# Check the outcome of the response

if ($req->is_success) {
    #print Dumper(decode_json($req->content));
}
else {
  print "\n in else not success\n";
}
print Dumper($content);

my $server4 = decode_json($req->content);

print "INFO: Setting video metadata";

my $content = {
	title        => $videotitle,
	channel      => $videocat,
	tags         => $tags,
	description  => $videodescription,
	explicit     => $adult,
	language	 => $videolanguage,
	access_token => $server->{'access_token'}
};

if (is_imageurl_valid($imageurl)) {
	$content->{'thumbnail_url'} = $imageurl;
}

my $req;
	
$req = $ua->request(POST 'https://api.dailymotion.com/video/'.$server4->{'id'}.'?',
		Content_Type => 'application/x-www-form-urlencoded',
		Content => $content
		);

print $req->request()->as_string();
 	

print "\nRESPONSE -- \n" . $req->as_string;
 
# Check the outcome of the response

if ($req->is_success) {
    #print Dumper(decode_json($req->content));
}
else {
  print "\n in else not success\n";
}

my $req = $ua->request(POST 'https://api.dailymotion.com/video/'.$server4->{'id'}.'?',
	  Content_Type => 'application/x-www-form-urlencoded',
	  Content => [
		  published=>'true',
		  access_token=>$server->{'access_token'}
	  ]
);

print $req->request()->as_string();
 	
print "\nRESPONSE -- \n" . $req->as_string;
 
# Check the outcome of the response

if ($req->is_success) {
    #print Dumper(decode_json($req->content));
}
else {
  print "\n in else not success\n";
}

print "INFO: Done. Outputting video id ".$server4->{'id'}."\n";

$store->set('meta','dailymotion_video_id',$server4->{'id'});

print "+SUCCESS: Completed upload\n";