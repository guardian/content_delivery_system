#!/usr/bin/perl

my $version='$Rev: 510 $ $LastChangedDate: 2013-09-20 18:17:45 +0100 (Fri, 20 Sep 2013) $';

use CDS::Datastore;
use CDS::Brightcove;
use Data::Dumper;

#This module will create a Brightcove record and add two stills, connecting
#TO AN EXISTING CDN URL.
#
#parameters: 
# <keyfile>blah - secret key data to communicate with the API
# <retries> - retry this many times
# <retry-delay> - time to wait between retry attempts
# <title_key> - use this datastore key for title data. Defaults to 'title'
# <description_key> - use this datastore key for description data. Defaults to 'description'
# <refid_key> - use this datastore key for reference ID. Defaults to 'refid'
# <url_key>  - use this datastore key for the URL to link to. Defaults to 'video URL'
# <vidstill_key> - use this datastore key for the video still image URL (480x360px).  Defaults to 'still URL'
# <vidthumb_key> - use this datastore key for the video thumbnail image URL (120x90px).  Defaults to 'thumb URL'
# <filesize_key> - use this datastore key [in the media section] for file size. Defaults to media:size
# <duration_key> - use this datastore key [in the media section] for duration.  Defaults to media:duration
# <codec_key> - use this datastore key [in the tracks section] for codec.  Defaults to tracks:vide:format
# <output_id_key> - output the new Brightcove ID to this key name.  Defaults to 'Brightcove ID'

#configurable parameters
my $brightcove_secret_key='Secret';	#use this key in the keyfile to pick up Brightcove write token

#START MAIN
#sort out arguments

foreach(qw/keyfile output_id_key/){
	unless($ENV{$_}){
		print "-ERROR - you need to specify $_ in the routefile.\n";
		exit 1;
	}
}

my $debug=0;
$debug=1 if(defined $ENV{'debug'});

#connect to the datastore
my $store=CDS::Datastore->new('brightcove_link');

#pick up metadata for the video link operation
my %keys;
#pick up codec from track:vide:format seperately
my @keynames=qw/title description refid url vidstill vidthumb filesize duration/;
my @keysections=qw/meta meta meta meta meta meta media media/;
my @keydefaults=('title','description','refid','video URL','still URL','thumb URL','size','duration');

for(my $i=0;$i<scalar @keynames;++$i){
	my $keyname=$keydefaults[$i];
	my $argname=$keynames[$i]."_key";
	if($ENV{$argname}){
		$keyname=$ENV{$argname};
	}
	my $value=$store->get($keysections[$i],$keyname);
	unless($value){
		print "-ERROR: Unable to get metadata value from $keyname.\n";
		exit 1;
	}
	$keys{$keydefaults[$i]}=$value;
}
$argname='format';
if($ENV{'codec_key'}){
	$argname=$ENV{'codec_key'};
}
$keys{'codec'}=$store->get('track','vide',$argname);

$keys{'url'}=$keys{'video URL'};

if($debug){
	print "DEBUG: Metadata from datastore:\n";
	print Dumper(\%keys);
}

my $brightcove=CDS::Brightcove->new(Debug=>$debug);
$brightcove->loadKey($ENV{'keyfile'},$brightcove_secret_key);

print "MESSAGE: Sending ".$keys{'url'}." to Brightcove...\n\n";
my $brightcoveVideoId=$brightcove->createRemoteVideo(%keys);
unless($brightcoveVideoId){
	#error message should have been printed by CDS::Brightcove
	exit 1;
}
print "MESSAGE: Brightcove video record created.  Brightcove ID=$brightcoveVideoId\n\n";

$store->set('meta',$ENV{'output_id_key'},$brightcoveVideoId);

#ok, now the video is uploaded put on stills
my %stillkeys;
$stillkeys{'type'}='video_still';
$stillkeys{'refid'}=$keys{'refid'}.":VIDEOSTILL";
$stillkeys{'url'}=$keys{'still URL'};
$stillkeys{'videoid'}=$brightcoveVideoId;

print "MESSAGE: Sending video still (480x360) '".$stillkeys{'url'}."' to Brightcove...\n\n";
my $stillImgId=$brightcove->addRemoteImageToVideo(%stillkeys);
unless($stillImgId){
	#error message should have been printed by CDS::Brightcove
	exit 1;
}
print "MESSAGE: Video still attached.  Still ID=$stillImgId\n\n";

$stillkeys{'url'}=$keys{'thumb URL'};
$stillkeys{'refid'}=$keys{'refid'}.":VIDEOTHUMB";
$stillkeys{'type'}="thumbnail";

print "MESSAGE: Sending video thumb (120x90) '".$stillkeys{'url'}."' to Brightcove...\n\n";
my $thumbImgId=$brightcove->addRemoteImageToVideo(%stillkeys);
unless($thumbImgId){
	#error message should have been printed by CDS::Brightcove
	exit 1;
}
print "MESSAGE: Video still attached.  Still ID=$thumbImgId\n\n";

print "+SUCCESS: Video sent and stills attached.\n";
exit 0;

