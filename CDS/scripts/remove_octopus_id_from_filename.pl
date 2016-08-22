#!/usr/bin/perl

my $version='$Rev: 498 $ $LastChangedDate: 2013-09-18 11:09:49 +0100 (Wed, 18 Sep 2013) $';

#This is a very simple script to remove the _{octid} portion of the video's
#filename.  This is so that, if an Octopus-mastered video is syndicated, the 
#source URL should match the one cached when it was sent through for GoogleTV.

#arguments:
# <use_path>blah [OPTIONAL] - set the out-going path to this
# <no_error_if_exists/>	-continue if the file already exists.

use CDS::Datastore;
use File::Copy;
use File::Basename;

#START MAIN
my $existing_name=$ENV{cf_media_file};
unless($existing_name){
	print STDERR "-ERROR: Unable to determine media file name.  Did you include <take-files>media</take-files> in the route file?\n";
	exit 1;
}

my $store=CDS::Datastore->new('remove_octopus_id_from_filename');

print "INFO: Using existing name $existing_name\n";

my $existing_path=dirname($existing_name);
my $existing_base=basename($existing_name);

my $new_name;

my $new_path=$existing_path;

if($ENV{'use_path'}){
	$new_path=$store->substitute_string($ENV{'use_path'});
} elsif($ENV{'use-path'}){
	$new_path=$store->substitute_string($ENV{'use-path'});
}

if($existing_base=~/^([^_]+)_([\d\-]+)\.([^\.]+)/){
	$new_name="$new_path/$1.$3";
} else {
	print "-ERROR: Existing filename does not seem to have come from Octopus (filename_id.mov form)\n";
	exit 1;
}

unlink($new_name) unless($ENV{'no_delete'});

print "INFO: Symlinking to $new_name\n";
#my $r=move($existing_name,$new_name);
my $r=symlink($existing_name,$new_name);

if($r<1){
	print "-ERROR: $!\n";
	exit 1 unless($ENV{'no_error_if_exists'});
}

open FHOUT,">".$ENV{'cf_temp_file'};
print FHOUT "cf_media_file=$new_name";
close FHOUT;
exit 0;

