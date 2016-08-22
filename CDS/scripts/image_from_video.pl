#!/usr/bin/perl

#This method extracts an image as a jpeg from the given cf_media_file, and optionally
#sets a key to say where it went.
#
#Arguments:
# <take-files>media - you need to include this so that the media file is available
# <output_path>/path/to/file - where the image should be written to
# <output_key>keyname [OPTIONAL] - set this key in the datastore meta section to say where the image was saved.
# <timecode>hh:mm:ss.ss [OPTIONAL] - take the image from this timecode as opposed to frame 1. NOTE: format is hours:mins:seconds, with DECIMAL POINT IN SECONDS (not frames!!)
#END DOC

use CDS::Datastore;
use Cwd qw/realpath/;

sub check_args
{

my $failed=0;
foreach(@_){
	unless($ENV{$_}){
		print "You must specify the argument <$_> in the route file. Consult the documentation for this method for more information\n";
		$failed=1;
	}
}
exit 1 if($failed);
return 1;
}

#START MAIN
check_args(qw/output_path/);

my $store=CDS::Datastore->new('image_from_video');

my $output_path=$store->substitute_string($ENV{'output_path'});

my $videofile=$ENV{'cf_media_file'};
if($videofile eq ''){
	print "-ERROR: You must specify a media file to work on using <take-files>media</take-files>. If you did, and you still get this message, then there was no video file available when this method was run.\n";
	exit 1;
}

unless(-f $videofile){
	print "-ERROR: The video file '$videofile' does not exist.\n";
	exit 1;
}

my $timecode="00:00:00.00";
if($ENV{'timecode'}){
	$timecode=$store->substitute_string($ENV{'timecode'});
	#Security - ensure that people can't break the commandline by putting dodgy characters in!
	$timecode=~s/[^\d:\.]//g;
}

#Again, ensure that people can't tack extra commands onto the end of the line by closing the quotes.
$output_path=~tr/"//;

my $cmd="ffmpeg -ss \"$timecode\" -i \"$videofile\" -frames 1 -f image2 -y \"$output_path\"";

if($ENV{'debug'}){
	print "DEBUG: I will run '$cmd'...\n";
}

system($cmd);
my $rtn=$?>>8;
unless($rtn==0){
	print "-ERROR: frame extraction failed.\n";
	exit 1;
}

print "+SUCCESS: frame extraction succeeded.\n";
if($ENV{'output_key'}){
	my $keyname=$store->substitute_string($ENV{'output_key'});
	print "INFO: Outputting file path to datastore key $keyname...\n";
	$store->set('meta',$keyname,realpath($output_path));
	print "+SUCCESS: frame extracted and file path output.\n";
}

