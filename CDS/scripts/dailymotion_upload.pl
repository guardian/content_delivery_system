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

my $store=CDS::Datastore->new('dailymotion_upload');

#my $imagefile = $ARGV[1];

#print "\n".$imagefile."\n";

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
if(scalar @tags>10){
	print "-WARNING: More than 10 tags have been specified, so we will only use the first 10.\n";
	@tags = splice(@tags,0,10);
}

if (grep { $_ eq 'UK news' } @tags) {
	push @tags, 'United Kingdom';
	push @tags, 'United Kingdom of Great Britain and Northern Ireland';
}

if (grep { $_ eq 'Germany' } @tags) {
	push @tags, 'Deutschland';
	push @tags, 'Federal Republic of Germany';
	push @tags, 'Bundesrepublik Deutschland';
}

if (grep { $_ eq 'France' } @tags) {
	push @tags, 'French Republic';
}

if (grep { $_ eq 'Italy' } @tags) {
	push @tags, 'Italia';
	push @tags, 'Italian Republic';
	push @tags, 'Repubblica Italiana';
}

if (grep { $_ eq 'Russia' } @tags) {
	push @tags, 'Russian Federation';
}

if (grep { $_ eq 'Spain' } @tags) {
	push @tags, 'Kingdom of Spain';
}

if (grep { $_ eq 'Turkey' } @tags) {
	push @tags, 'Republic of Turkey';
	push @tags, 'West Asia';
	push @tags, 'Asia';
	push @tags, 'Middle East';
}

if (grep { $_ eq 'China' } @tags) {
	push @tags, "People's Republic of China";
	push @tags, 'Asia';
	push @tags, 'East Asia';
}

if (grep { $_ eq 'India' } @tags) {
	push @tags, 'Republic of India';
	push @tags, 'Asia';
	push @tags, 'South Asia';
}

if (grep { $_ eq 'Japan' } @tags) {
	push @tags, 'Asia';
	push @tags, 'East Asia';
}

if (grep { $_ eq 'Syria' } @tags) {
	push @tags, 'Syrian Arab Republic';
	push @tags, 'West Asia';
	push @tags, 'Asia';
	push @tags, 'Middle East';
}

if (grep { $_ eq 'Morocco' } @tags) {
	push @tags, 'Kingdom of Morocco';
	push @tags, 'Maghreb';
	push @tags, 'North Africa';
	push @tags, 'Africa';
}

if (grep { $_ eq 'Tunisia' } @tags) {
	push @tags, 'Tunisian Republic';
	push @tags, 'Maghreb';
	push @tags, 'North Africa';
	push @tags, 'Africa';
}

if (grep { $_ eq 'Nigeria' } @tags) {
	push @tags, 'Federal Republic of Nigeria';
	push @tags, 'West Africa';
	push @tags, 'Africa';
}

if (grep { $_ eq 'United Arab Emirates' } @tags) {
	push @tags, 'West Asia';
	push @tags, 'Asia';
	push @tags, 'Middle East';
}

if (grep { $_ eq 'South Korea' } @tags) {
	push @tags, 'Republic of Korea';
	push @tags, 'Korean Peninsula';
	push @tags, 'Asia';
	push @tags, 'East Asia';
}

if (grep { $_ eq 'Australia news' } @tags) {
	push @tags, 'Commonwealth of Australia';
	push @tags, 'Oceania';
	push @tags, 'Australasia';
}

if (grep { $_ eq 'New Zealand' } @tags) {
	push @tags, 'Oceania';
	push @tags, 'Australasia';
}

if (grep { $_ eq 'US news' } @tags) {
	push @tags, 'United States';
	push @tags, 'United States of America';
	push @tags, 'USA';
	push @tags, 'North America';
	push @tags, 'The Americas';	
}

if (grep { $_ eq 'Canada' } @tags) {
	push @tags, 'North America';
	push @tags, 'The Americas';	
}

if (grep { $_ eq 'Brazil' } @tags) {
	push @tags, 'Federative Republic of Brazil';
	push @tags, 'South America';
	push @tags, 'The Americas';	
}

if (grep { $_ eq 'Colombia' } @tags) {
	push @tags, 'Republic of Colombia';
	push @tags, 'South America';
	push @tags, 'The Americas';	
}

if (grep { $_ eq 'Honduras' } @tags) {
	push @tags, 'Republic of Honduras';
	push @tags, 'North America';
	push @tags, 'The Americas';	
}

if (grep { $_ eq 'Guatemala' } @tags) {
	push @tags, 'Republic of Guatemala';
	push @tags, 'North America';
	push @tags, 'The Americas';	
}

if (grep { $_ eq 'El Salvador' } @tags) {
	push @tags, 'Republic of El Salvador';
	push @tags, 'North America';
	push @tags, 'The Americas';	
}

if (grep { $_ eq 'Haiti' } @tags) {
	push @tags, 'Republic of Haiti';
	push @tags, 'Hispaniola';
	push @tags, 'Greater Antilles';
	push @tags, 'Caribbean';
	push @tags, 'North America';
	push @tags, 'The Americas';	
}

if (grep { $_ eq 'Film' } @tags) {
	push @tags, 'Movie';
	push @tags, 'Cinema';
	push @tags, 'Motion picture';
}

if (grep { $_ eq 'Football' } @tags) {
	push @tags, 'Soccer';
	push @tags, 'Association football';
}

if (grep { $_ eq 'Whales' } @tags) {
	push @tags, 'Animals';
	push @tags, 'Mammals';
}

if (grep { $_ eq 'BBC' } @tags) {
	push @tags, 'British Broadcasting Corporation';
}

if (grep { $_ eq 'FBI' } @tags) {
	push @tags, 'Federal Bureau of Investigation';
}

if (grep { $_ eq 'Nasa' } @tags) {
	push @tags, 'National Aeronautics and Space Administration';
}

if (grep { $_ eq 'NSA' } @tags) {
	push @tags, 'National Security Agency';
}

if (grep { $_ eq 'Farc' } @tags) {
	push @tags, 'Revolutionary Armed Forces of Colombia';
	push @tags, 'Fuerzas Armadas Revolucionarias de Colombia';
}

if (grep { $_ eq 'NRA' } @tags) {
	push @tags, 'National Rifle Association of America';
}

if (grep { $_ eq 'NYPD' } @tags) {
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

 
use HTTP::Request::Common;

 
my $file, $result, $message;
#my $filePath = '/vagrant';
#my $keyword = "test.mp4";
 
#$file = $filePath.'/'.$keyword."";
 
 
#if(scalar @ARGV <1){
#	print "Usage: ./dailymotion_upload [filename]\n";
#}



my $ua = LWP::UserAgent->new;
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
#print Dumper(decode_json($req->content));
if ($req->is_success) {
    #print Dumper(decode_json($req->content));
}
else {
  print "\n in else not success\n";
}

my $server = decode_json($req->content);

my $ua = LWP::UserAgent->new;
my $req = $ua->request(GET 'https://api.dailymotion.com/file/upload?access_token='.$server->{'access_token'});

print $req->request()->as_string();
 	

print "\nRESPONSE -- \n" . $req->as_string;
 
# Check the outcome of the response
#print Dumper(decode_json($req->content));
if ($req->is_success) {
    #print Dumper(decode_json($req->content));
}
else {
  print "\n in else not success\n";
}

my $server2 = decode_json($req->content);

my $ua = LWP::UserAgent->new;
my $req;


#use LWP::UserAgent;
use HTTP::Request::Common qw(POST $DYNAMIC_FILE_UPLOAD);

$DYNAMIC_FILE_UPLOAD=1;
my $ua=LWP::UserAgent->new();
my $request   =  HTTP::Request::Common::POST
  $server2->{'upload_url'},
  Content_Type => 'form-data',
  Content => [ 'file' => [ $ENV{'cf_media_file'} ] ];



print Dumper($req);

#my $resp = $ua->request($req);

my $resp = $ua->request($request);

print Dumper($resp->request()->as_string());

print "\nRESPONSE-- \n". $resp->as_string;

if(not $resp->is_success){
	print "\n It didn't work :(\n";
	exit(1);
}

my $server3 = decode_json($resp->content);
my $ua = LWP::UserAgent->new;
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
#print Dumper(decode_json($req->content));
if ($req->is_success) {
    #print Dumper(decode_json($req->content));
}
else {
  print "\n in else not success\n";
}



my $server4 = decode_json($req->content);

my $req;

if ($block == 0) {
	my $ua = LWP::UserAgent->new;
	$req = $ua->request(POST 'https://api.dailymotion.com/video/'.$server4->{'id'}.'?',
		  Content_Type => 'application/x-www-form-urlencoded',
		  Content => [
			  title=>$videotitle,
			  channel=>$videocat,
			  tags=>$tags,
			  description=>$videodescription,
			  explicit=>$adult,
			  thumbnail_url=>$imageurl,
			  #taken_time=>$videotaken,
			  access_token=>$server->{'access_token'}
		  ]
	);
}

else {
	
	$req = $ua->request(POST 'https://api.dailymotion.com/video/'.$server4->{'id'}.'?',
		  Content_Type => 'application/x-www-form-urlencoded',
		  Content => [
			  title=>$videotitle,
			  channel=>$videocat,
			  tags=>$tags,
			  description=>$videodescription,
			  explicit=>$adult,
			  #mediablocking=>'country/all/media/mobile',
			  thumbnail_url=>$imageurl,
			  #taken_time=>$videotaken,
			  access_token=>$server->{'access_token'}
		  ]
	);
}

print $req->request()->as_string();
 	

print "\nRESPONSE -- \n" . $req->as_string;
 
# Check the outcome of the response
#print Dumper(decode_json($req->content));
if ($req->is_success) {
    #print Dumper(decode_json($req->content));
}
else {
  print "\n in else not success\n";
}

my $ua = LWP::UserAgent->new;
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
#print Dumper(decode_json($req->content));
if ($req->is_success) {
    #print Dumper(decode_json($req->content));
}
else {
  print "\n in else not success\n";
}

$store->set('meta','dailymotion_video_id',$server4->{'id'});