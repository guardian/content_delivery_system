#!/usr/bin/perl
#
#This method creates a composite of two images by superimposing one (with an alpha channel)
#over another.
#It depends on the ImageMagick suite of tools being available on the CDS server, specifically
#the 'convert' and 'composite' commands.
#
#Arguments:
#  <take-files> - optionally, take the media file for processing
#  <base_image>/path/to/file [OPTIONAL] - image to composite on top of. If not specified, will try to use the current Media file (substitutions encouraged).
#  <overlay_image>/path/to/file - image to overlay onto the base image (substitutions accepted)
#  <output_image>/path/to/file - path to write final image to.  Substitutions definitely encouraged.
#  <output_scale>wxh [OPTIONAL] - ensure that the output image is scaled to this size, BEFORE compositing. Normally, set this to the widthxheight of the overlay_image.
#  <output_meta_key>keyname [OPTIONAL] - output the file path of the processed image to this metadata key in the datastore. Defaults to 'composite_image'.
#  <no_set_media/> [OPTIONAL] - by default this method will set the current Media file to the output image. If you don't want this, set no_set_media.
#  <temp_path>/tmp [OPTIONAL] - temporary working directory. Defaults to '/tmp'.
#END DOC

use CDS::Datastore;
use File::Temp;
use File::Basename;

#START MAIN
my $store = CDS::Datastore->new('image_composite');

my $input_image=$ENV{'cf_media_file'};
if($ENV{'base_image'}){
	$input_image=$store->substitute_string($ENV{'base_image'});
}
if(not $input_image){
	print "-ERROR: You must specify a base image to work on, either by using <take-files>media or specifying <base_image> in the route configuration\n";
	exit(1);
}

my $overlay_image=$store->substitute_string($ENV{'overlay_image'});

my $output_image=$store->substitute_string($ENV{'output_image'});

my $temp_path = "/tmp";
$temp_path = $store->substitute_string($ENV{'temp_path'}) if($ENV{'temp_path'});

my $output_key = "composite_image";
if($ENV{'output_meta_key'}){
	$output_key=$ENV{'output_meta_key'};
}
$input_image=~s/"/\\"/; #escape quote marks so shell command can't be broken
$temp_path=~s/"/\\"/;
$overlay_image=~s/"/\\"/;
$output_image=~s/"/\\"/;

print "INFO: Arguments:\n";
print "Base image: $input_image\nOverlay image: $overlay_image\nOutput key: $output_key\nTemp path: $temp_path\n";

die "-ERROR: Base image $base_image does not exist" if(! -f $base_image);
die "-ERROR: Overlay image $overlay_image does not exist" if(! -f $overlay_image);
die "-ERROR: Temp path $temp_path does not exist" if(! -d $temp_path);
my $od=dirname($output_image);
die "-ERROR: Output directory $od does not exist" if(! -d $od);
print "-WARNING: Output image $output_image already exists and will be overwritten" if(-f $output_image);

my $processed_image;
my $delete_processed=0;
if($ENV{'output_scale'}){
	print "INFO: Scaling base image to $scale...\n";
	my $scale=$store->substitute_string($ENV{'output_scale'});
	if($scale !~ /^\d+x\d+$/){
		die "-ERROR: $scale does not look like a correct scaling parameter. Should be digits, followed by 'x', followed by digits.\n";
	}
	my $tf = File::Temp->new(TEMPLATE=>'image_composite_XXXXXXX', DIR=>$temp_path, UNLINK=>0, SUFFIX=>'.jpg');
	$processed_image=$tf->filename;
	$delete_processed=1;
	
	my $result = `convert -scale $scale "$input_image" "$processed_image"`;
	if($? != 0){
		print $result;
		die "-ERROR: Convert command failed on error $?. See log trace for more details.\n";
	}
} else {
	print "INFO: NOT scaling base image.\n";
	$processed_image=$input_image;
	$delete_processed=0;
}

print "INFO: Compositing images...\n";
my $result = `composite "$overlay_image" "$processed_image" "$output_image"`;
if($? != 0){
	print $result;
	unlink($processed_image) if($delete_processed);
	die "-ERROR: Composite command failed on error $?. See log trace for more details.\n";
}
print "INFO: Done.\n";

$store->set('meta',$output_key,$output_image);
unless($ENV{'no_set_media'}){
	print "INFO: Setting media file to be $output_image\n";
	open FH,">:utf8",$ENV{'cf_temp_file'};
	print FH "cf_media_file=$output_image\n";
	close FH;
}
print "INFO: Deleting temp files";
unlink($processed_image) if($delete_processed);
print "+SUCCESS: $output_image output to meta:$output_key\n";


