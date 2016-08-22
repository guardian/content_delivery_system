#!/usr/bin/env perl

$|=1;

$longversion='facebook_upload.pl from master revision $Rev: 1395 $ $LastChangedDate: 2015-10-09 16:38:28 +0100 (Fri, 09 Oct 2015) $';
$version='facebook_upload.pl $Rev: 1395 $';

#This CDS module uploads a video and various associated data to Facebook via the Graph API for display on a Facebook page.
#Arguments:
# <image_file> - upload the given image file for use as a thumbnail if present
# <access_token>blah - key for accessing the Facebook server
# <video_title>blah - the title of the video
# <video_description>blah - the description of the video
# <video_category>blah - the content category of the video
# <video_embed>n - A switch which allows (1) or disallows (0) video embedding of the video by the general public
# <video_no_story>n - A switch which controls weather a Facebook story for the video is posted (0) or not posted (1) 
# <page_id>n - Identification number of the Facebook page the video should be posted to
# <video_draft> - Weather the video is a draft or not
# <video_scheduled> - Weather the video is to be scheduled or not
# <video_time>n - Scheduled time to post the video
# <video_backdate> - Weather the video is to be backdated or not
# <video_backdate_time>n - Time to backdate the video to
# <video_backdate_accuracy>blah - Accuracy level of backdating
# <allow_bm_crossposting> - Weather the video can be crossposted or not
#END DOC

use LWP::UserAgent;
use JSON;
use Data::Dumper;
use File::Basename;
use CDS::Datastore;
use Date::Parse;


package FileSplitter;

sub new {
	my $class=shift;

	my $self={
		'counter'=>0,
		'chunkSize'=>1024000,
		'offset'=>0,
		'inputOffset'=>undef
	};
	bless($self,$class);
}

sub setFileName {
	my ($self,$fn)=@_;
	
	$self->{'filename'}=$fn;
	@{$self->{'statdata'}}=stat($fn);
	open($self->{'fh'},'<',$fn) or die "Could not open file $fn: $!";
}

sub fileSize {
	my $self=shift;
	
	return $self->{'statdata'}[7];
}

sub setChunkSize {
	my $self=shift;
	my $s=shift;
	
	#die "Cannot have a chunk size > 32Mb" if($s>32*1024*1024);
	$self->{'chunkSize'}=$s;
}

sub getNextChunk {
	my $self=shift;
	my $data;
	
	return undef if(eof($self->{'fh'}));
	
	print "reading in ".$self->{'chunkSize'}." bytes "; #from offset ".$self->{'counter'}*$self->{'chunkSize'}."\n";
	seek($self->{'fh'}, $self->{'inputOffset'}, SEEK_SET) if(defined $self->{'inputOffset'});
	$self->{'inputOffset'} = undef;
	read($self->{'fh'}, $data, $self->{'chunkSize'});
	
	++$self->{'counter'};
	return $data;
}

sub setNextChunkSize {
	my($self,$start,$end)=@_;

	$self->{'chunkSize'} = $end - $start;
	$self->{'offset'} = $start;
	print "setNextChunkSize: from $start to $end is ".$self->{'chunkSize'}."\n";	
}

sub setNextChunkSizeRetry {
	my($self,$start,$end)=@_;

	$self->{'chunkSize'} = $end - $start;
	$self->{'inputOffset'} = $start;
	print "setNextChunkSize: from $start to $end is ".$self->{'chunkSize'}."\n";	
}


sub offset {
	my $self=shift;
	
	return $self->{'offset'};
}
sub DESTROY {
	my $self=shift;
	
	close($self->{'fh'});
}

package main;
##START MAIN

my $store=CDS::Datastore->new('facebook_upload');

my $imagefile;
if(defined $ENV{'image_file'}){
	$imagefile = $store->substitute_string($ENV{'image_file'});
} else {
	$imagefile = undef;
}

print "INFO: Image file is ".$imagefile."\n";

my $videotitle = $store->substitute_string($ENV{'video_title'});
my $videodescription = $store->substitute_string($ENV{'video_description'});
my $videocat = $store->substitute_string($ENV{'video_category'});
my $videoembed = 0;

if ($store->substitute_string($ENV{'video_embed'}) eq "master_facebook_allow_user_embedding") {
	$videoembed = 1;
}

my $videons = 0;

if ($store->substitute_string($ENV{'video_no_story'}) eq "master_facebook_hide_story") {
	$videons = 1;
}
 
my $videodraft = 1;

#if ($store->substitute_string($ENV{'video_draft'}) ne "master_facebook_unlisted") {
#	$videodraft = 0;
#}

my $videoscheduled = 0;

if ($store->substitute_string($ENV{'upload_as'}) eq "Scheduled") {
    $videoscheduled = 1;
}

if ($store->substitute_string($ENV{'upload_as'}) eq "Publish") {
    $videodraft = 0;
}

my $videotime = str2time($store->substitute_string($ENV{'video_time'}));

my $videobd = 0;

if ($store->substitute_string($ENV{'video_backdate'}) eq "master_facebook_backdate_post") {
	$videobd = 1;
}

$allowbmcrossposting = 1;

if ($store->substitute_string($ENV{'allow_bm_crossposting'}) eq "false") {
	$allowbmcrossposting = 0;
}


my $videobdt = str2time($store->substitute_string($ENV{'video_backdate_time'}));

my $call = 0;
my $uct = "pub";

if  ($videodraft == 1) {
	$uct = "DRAFT";
}

if  ($videoscheduled == 1) {
	$uct = "SCHEDULED";
}

my $videobtg = lc $store->substitute_string($ENV{'video_backdate_accuracy'});
 
print "Video title is '$videotitle'\n";
print "Video description is '$videodescription'\n";
print "Video category is '$videocat'\n";
print "Video embed status is '$videoembed'\n";
print "Video no story status is '$videons'\n";
print "Video draft status is '$videodraft'\n";
print "Video scheduled status is '$videoscheduled'\n";
print "Video time is '$videotime'\n";
print "Video backdate status is '$videobd'\n";
print "Video backdate time is '$videobdt'\n";
print "Call to action status is '$call'\n";
print "Publish status is '$uct'\n";
 
use HTTP::Request::Common;

 
my $file, $result, $message;

my $at = $store->substitute_string($ENV{'access_token'});

my $s = FileSplitter->new();

$s->setFileName($ENV{'cf_media_file'});

my $ua = LWP::UserAgent->new;
my $req = $ua->request(POST 'https://graph-video.facebook.com/v2.4/'.$store->substitute_string($ENV{'page_id'}).'/videos?access_token='.$at.'&upload_phase=start&file_size='.$s->fileSize);
 	#print $req->request()->as_string();
 	
print "\nRESPONSE -- \n" . $req->as_string;
 
# Check the outcome of the response
#print Dumper(decode_json($req->content));
if ($req->is_success) {
    #print Dumper(decode_json($req->content));
}
else {
  print "-Error: Unable to initiate upload\n";
}

$server = decode_json($req->content);
print "DEBUG: information returned by server:";
print Dumper($server);

$store->set('meta','facebook_upload_sess_id',$server->{'upload_session_id'},'facebook_video_id',$server->{'video_id'});

#print Dumper($server->{'end_offset'});

#print "\n";


$s->setChunkSize($server->{'end_offset'});

print "INFO: File size is ". $s->fileSize."\n";

my $chunknumber = 0;
my $chunkdata=$s->getNextChunk;

while(1){
	#last if(not defined $_);
	print "Got chunk number " .$s->{'counter'}. " of ".$s->{'chunkSize'}." bytes\n";	
	my $req = $ua->request(POST 'https://graph-video.facebook.com/v2.4/'.$store->substitute_string($ENV{'page_id'}).'/videos',
          Content_Type => 'form-data',
          Content => [
			  access_token=>$at,
			  upload_phase=>"transfer",
			  start_offset=>$s->offset,
			  upload_session_id=>$server->{'upload_session_id'},
			  video_file_chunk => [undef, basename($s->{'filename'}), Content-Type=>'video/mp4', Content=>$chunkdata]
          ]
	);
		#print $req->request()->as_string();
	
	print "\nRESPONSE -- \n" . $req->as_string;
 
	# Check the outcome of the response
	#print Dumper(decode_json($req->content));
	my $responsedata=decode_json($req->decoded_content);
	
	if ($req->is_success) {
		print Dumper($responsedata);
		if($responsedata->{'start_offset'} and $responsedata->{'end_offset'}){
			$s->setNextChunkSize($responsedata->{'start_offset'},$responsedata->{'end_offset'});
		}
		last if $s->{'chunkSize'}==0;
		$chunkdata=$s->getNextChunk;
		#print Dumper(decode_json($req->content));
	} else {
	  print "\n -warning in else not success\n";
	  print Dumper($responsedata);
	  if($responsedata->{'error'}->{'code'} == 6000) {
	  	die "A non-recoverable error occurred at Facebook's end :'(";
	  }
	  if($responsedata->{'error'}->{'error_subcode'} == 1363037) {
	  	print "\n -ERROR 6001:1363037 - Sending the chunk again... \n";
	  	$s->setNextChunkSizeRetry($responsedata->{'error'}->{'error_data'}->{'start_offset'},$responsedata->{'error'}->{'error_data'}->{'end_offset'});
	  	last if $s->{'chunkSize'}==0;
		$chunkdata=$s->getNextChunk;
	  }
	  	#if($responsedata->{'error'}->{'code'} == 2) {
			print "\n The last request was broken. Retrying in 1 second...\n";
		#}
		print "-error Error code was: ".$responsedata->{'error'}->{'code'}."\n";
	  sleep(1);
	}
	#write out the file chunks
	#open my $fhout, ">", "chunk".$s->{'counter'}.".mp4";
	#print $fhout $_;
	#$chunknumber++;
	#close($fhout);

	
}

print $chunknumber."\n";


$chunkmarker = 1;

print "Imagefile is: ". Dumper($imagefile);

my $req;
if (not defined $imagefile or $imagefile eq "") {
	if ($uct eq "pub") {
		if ($videobd == 0) {
			if ($call == 0) {
				my $ua = LWP::UserAgent->new;
				$req = $ua->request(POST 'https://graph-video.facebook.com/v2.4/'.$store->substitute_string($ENV{'page_id'}).'/videos?access_token='.$at.'&upload_phase=finish&title='.$videotitle.
					'&description='.$videodescription.
					'&content_category='.$videocat.
					'&embeddable='.$videoembed.
					'&no_story='.$videons.
					'&upload_session_id='.$server->{'upload_session_id'}
				);
			}
			
			else {
				my $ua = LWP::UserAgent->new;
				$req = $ua->request(POST 'https://graph-video.facebook.com/v2.4/'.$store->substitute_string($ENV{'page_id'}).'/videos?access_token='.$at.'&upload_phase=finish&title='.$videotitle.
					'&description='.$videodescription.
					'&content_category='.$videocat.
					'&embeddable='.$videoembed.
					'&no_story='.$videons.
					'&upload_session_id='.$server->{'upload_session_id'}
				);
			}
		}
		
		else {
			if ($call == 0) {
				my $ua = LWP::UserAgent->new;
				$req = $ua->request(POST 'https://graph-video.facebook.com/v2.4/'.$store->substitute_string($ENV{'page_id'}).'/videos?access_token='.$at.'&upload_phase=finish&title='.$videotitle.
					'&description='.$videodescription.
					'&content_category='.$videocat.
					'&embeddable='.$videoembed.
					'&no_story='.$videons.
					'&backdated_post={\'backdated_time\':'.$videobdt.',\'backdated_time_granularity\':\''.$videobtg.'\'}'.
					'&upload_session_id='.$server->{'upload_session_id'}
				);
			}
			
			else {
				my $ua = LWP::UserAgent->new;
				$req = $ua->request(POST 'https://graph-video.facebook.com/v2.4/'.$store->substitute_string($ENV{'page_id'}).'/videos?access_token='.$at.'&upload_phase=finish&title='.$videotitle.
					'&description='.$videodescription.
					'&content_category='.$videocat.
					'&embeddable='.$videoembed.
					'&no_story='.$videons.
					'&backdated_post={\'backdated_time\':'.$videobdt.',\'backdated_time_granularity\':\''.$videobtg.'\'}'.
					'&upload_session_id='.$server->{'upload_session_id'}
				);
			}
		}
	}
	elsif ($uct eq "SCHEDULED") {
		if ($call == 0) {
			my $ua = LWP::UserAgent->new;
			$req = $ua->request(POST 'https://graph-video.facebook.com/v2.4/'.$store->substitute_string($ENV{'page_id'}).'/videos?access_token='.$at.'&upload_phase=finish&title='.$videotitle.
				'&description='.$videodescription.
				'&content_category='.$videocat.
				'&embeddable='.$videoembed.
				'&no_story='.$videons.
				'&upload_session_id='.$server->{'upload_session_id'}.
				'&unpublished_content_type='.$uct.
				'&scheduled_publish_time='.$videotime.
				'&published=0'
			);
		}
		
		else {
			my $ua = LWP::UserAgent->new;
			$req = $ua->request(POST 'https://graph-video.facebook.com/v2.4/'.$store->substitute_string($ENV{'page_id'}).'/videos?access_token='.$at.'&upload_phase=finish&title='.$videotitle.
				'&description='.$videodescription.
				'&content_category='.$videocat.
				'&embeddable='.$videoembed.
				'&no_story='.$videons.
				'&upload_session_id='.$server->{'upload_session_id'}.
				'&unpublished_content_type='.$uct.
				'&scheduled_publish_time='.$videotime.
				'&published=0'
			);
		}
	}
	else {
		if ($call == 0) {
			my $ua = LWP::UserAgent->new;
			$req = $ua->request(POST 'https://graph-video.facebook.com/v2.4/'.$store->substitute_string($ENV{'page_id'}).'/videos?access_token='.$at.'&upload_phase=finish&title='.$videotitle.
				'&description='.$videodescription.
				'&content_category='.$videocat.
				'&embeddable='.$videoembed.
				'&no_story='.$videons.
				'&upload_session_id='.$server->{'upload_session_id'}.
				'&unpublished_content_type='.$uct.
				'&published=0'
			);
		}
		
		else {
			my $ua = LWP::UserAgent->new;
			$req = $ua->request(POST 'https://graph-video.facebook.com/v2.4/'.$store->substitute_string($ENV{'page_id'}).'/videos?access_token='.$at.'&upload_phase=finish&title='.$videotitle.
				'&description='.$videodescription.
				'&content_category='.$videocat.
				'&embeddable='.$videoembed.
				'&no_story='.$videons.
				'&upload_session_id='.$server->{'upload_session_id'}.
				'&unpublished_content_type='.$uct.
				'&published=0'
			);
		}
	}

	print "1";
}


else {
	if ($uct eq "pub") {
		if ($videobd == 0) {
			my $ua = LWP::UserAgent->new;
			$req = $ua->request(POST 'https://graph-video.facebook.com/v2.4/'.$store->substitute_string($ENV{'page_id'}).'/videos',
				  Content_Type => 'form-data',
				  Content => [
					  access_token=>$at,
					  title=>$videotitle,
					  description=>$videodescription,
					  content_category=>$videocat,
					  embeddable=>$videoembed,
					  no_story=>$videons,
					  upload_phase=>"finish",
					  upload_session_id=>$server->{'upload_session_id'},
					  thumb => [ "$imagefile" ]
				  ]
			);
		}
		
		else {
			my $ua = LWP::UserAgent->new;
			$req = $ua->request(POST 'https://graph-video.facebook.com/v2.4/'.$store->substitute_string($ENV{'page_id'}).'/videos',
				  Content_Type => 'form-data',
				  Content => [
					  access_token=>$at,
					  title=>$videotitle,
					  description=>$videodescription,
					  content_category=>$videocat,
					  embeddable=>$videoembed,
					  no_story=>$videons,
					  upload_phase=>"finish",
					  upload_session_id=>$server->{'upload_session_id'},
					  backdated_post=>"{\'backdated_time\':".$videobdt.",\'backdated_time_granularity\':\'".$videobtg."\'}",
					  thumb => [ "$imagefile" ]
				  ]
			);
		}

	}
	elsif ($uct eq "SCHEDULED") {
		my $ua = LWP::UserAgent->new;
		$req = $ua->request(POST 'https://graph-video.facebook.com/v2.4/'.$store->substitute_string($ENV{'page_id'}).'/videos',
			  Content_Type => 'form-data',
			  Content => [
				  access_token=>$at,
				  title=>$videotitle,
				  description=>$videodescription,
				  content_category=>$videocat,
				  embeddable=>$videoembed,
				  no_story=>$videons,
				  upload_phase=>"finish",
				  upload_session_id=>$server->{'upload_session_id'},
				  unpublished_content_type=>$uct,
				  scheduled_publish_time=>$videotime,
				  published=>0,
				  thumb => [ "$imagefile" ]
			  ]

		);

	}
	else {
		my $ua = LWP::UserAgent->new;
		$req = $ua->request(POST 'https://graph-video.facebook.com/v2.4/'.$store->substitute_string($ENV{'page_id'}).'/videos',
			  Content_Type => 'form-data',
			  Content => [
				  access_token=>$at,
				  title=>$videotitle,
				  description=>$videodescription,
				  content_category=>$videocat,
				  embeddable=>$videoembed,
				  no_story=>$videons,
				  upload_phase=>"finish",
				  upload_session_id=>$server->{'upload_session_id'},
				  unpublished_content_type=>$uct,
				  published=>0,
				  thumb => [ "$imagefile" ]
			  ]

		);

	}

	print "2";

}

 	#print $req->request()->as_string();
 	
print "\nRESPONSE -- \n" . $req->as_string;
 
# Check the outcome of the response
if ($req->is_success) {
    print $req->content;
    
	my $update = LWP::UserAgent->new;
	$updatereq = $update->request(POST 'https://graph-video.facebook.com/v2.6/'.$server->{'video_id'}.'',
		  Content_Type => 'form-data',
		  Content => [
			  access_token=>$at,
			  allow_bm_crossposting=>$allowbmcrossposting
		  ]

	);
	
	print $updatereq->content;
}
else {
  print "ERROR: Facebook rejected our request to set up a video\n";
  exit(1);
}

exit(0);
