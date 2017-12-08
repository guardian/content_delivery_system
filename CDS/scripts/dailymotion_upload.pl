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


sub is_imageurl_valid {
	my ($url_to_check) = @_;

	my $url_status = 'valid';

	if (($url_to_check eq "") || ($url_to_check eq "http://invalid.url")) {
		$url_status = 'invalid';
	}
	
	return $url_status;
}
    
my $content = [
				  title=>$videotitle,
				  channel=>$videocat,
				  tags=>$tags,
				  description=>$videodescription,
				  explicit=>$adult,
				  access_token=>$server->{'access_token'}
			  ]
			  
if ($block == 1) {
	#$content->{'mediablocking'} = 'country/all/media/mobile';
}

if (is_imageurl_valid($imageurl) eq 'valid') {
	$content->{'thumbnail_url'} = $imageurl;
}


my $server4 = decode_json($req->content);

my $req;

my $ua = LWP::UserAgent->new;
	
$req = $ua->request(POST 'https://api.dailymotion.com/video/'.$server4->{'id'}.'?',
		Content_Type => 'application/x-www-form-urlencoded',
		Content => $content
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