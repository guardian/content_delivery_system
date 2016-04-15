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
#  <overlay_scale/> [OPTIONAL] - scale the overlay to the size of the base image before compositing
#  <output_meta_key>keyname [OPTIONAL] - output the file path of the processed image to this metadata key in the datastore. Defaults to 'composite_image'.
#  <no_set_media/> [OPTIONAL] - by default this method will set the current Media file to the output image. If you don't want this, set no_set_media.
#  <temp_path>/tmp [OPTIONAL] - temporary working directory. Defaults to '/tmp'.
#END DOC

use CDS::Datastore;
use File::Temp;
use File::Basename;
use Data::Dumper;

sub get_image_data {
	#simple function to extract image data from imagemagick. not the most elegant solution in the world, but it does not introduce any other dependencies...
	my $filename=shift;
	
	$filename=~s/'/\'/g; #remove shell escape chars
	my $teststring = `identify '$filename'`;
	chomp $teststring;
	die "Imagemagick identify failed on $filename: $teststring" if($?!=0);
	
    if ($teststring=~/^(?<mix1>.*) (?<width>\d+)x(?<height>\d+) (?<geometry>[x\d\+]+) (?<depth>\d+)-bit (?<class>\w+) (?<size>\w+) (?<unknown1>[^\s]+) (?<unknown2>[^\s]+)$/ or
        $teststring=~/^(?<mix1>.*) (?<width>\d+)x(?<height>\d+) (?<geometry>[x\d\+]+) (?<depth>\d+)-bit (?<class>\w+) (?<size>\w+)$/) {
		print "Width is ".$+{'width'}.", height is ".$+{'height'}."\n";
		my %data;
		%data=%+;
		#print Dumper(\%data);
		my $mix=$+{'mix1'};
		$mix=~/^(?<filename>.*) (?<format>\w+)$/;
		print "Filename is ".$+{'filename'}.", format is ".$+{'format'}."\n";
		#print Dumper(\%+);
		foreach(keys %+){
		    $data{$_}=$+{$_};
		}
		undef $data{'mix1'};
		#print Dumper(\%data);
		return \%data;
	} else {
		die "$teststring did not match!\n";
	}
	
}

sub do_scale
{
	my($input_image,$scale)=@_;
	
	if($scale !~ /^\d+x\d+$/){
		die "-ERROR: $scale does not look like a correct scaling parameter. Should be digits, followed by 'x', followed by digits.\n";
	}
	
	my $tf = File::Temp->new(TEMPLATE=>'image_composite_XXXXXXX', DIR=>$temp_path, UNLINK=>0, SUFFIX=>'.png');
	$processed_image=$tf->filename;
	
	my $result = `convert -resize "$scale" -background none -gravity center -crop "$scale" "$input_image" PNG32:"$processed_image"`;
	if($? != 0){
		print $result;
		die "-ERROR: Convert command failed on error $?. See log trace for more details.\n";
	}
	return $processed_image;
}

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

our $temp_path = "/tmp";
$temp_path = $store->substitute_string($ENV{'temp_path'}) if($ENV{'temp_path'});

my $output_key = "composite_image";
if($ENV{'output_meta_key'}){
	$output_key=$ENV{'output_meta_key'};
}
my $scale=$store->substitute_string($ENV{'output_scale'}) if($ENV{'output_scale'});

$input_image=~s/"/\\"/; #escape quote marks so shell command can't be broken
$temp_path=~s/"/\\"/;
$overlay_image=~s/"/\\"/;
$output_image=~s/"/\\"/;

print "INFO: Arguments:\n";
print "Base image: $input_image\nOverlay image: $overlay_image\nOutput key: $output_key\nTemp path: $temp_path\n";
print "Scale to: $scale\n\n" if($scale);

die "-ERROR: Base image $input_image does not exist" if(! -f $input_image);
die "-ERROR: Overlay image $overlay_image does not exist" if(! -f $overlay_image);
die "-ERROR: Temp path $temp_path does not exist" if(! -d $temp_path);
my $od=dirname($output_image);
die "-ERROR: Output directory $od does not exist" if(! -d $od);
print "-WARNING: Output image $output_image already exists and will be overwritten\n" if(-f $output_image);

my $processed_input_image,$processed_overlay_image;
my $delete_processed_input=0,$delete_processed_overlay=0;
if($ENV{'output_scale'}){
	print "INFO: Scaling base image to $scale...\n";

	$processed_input_image = do_scale($input_image,$scale);
	$processed_overlay_image=$overlay_image;
	$delete_processed_input=1;
} elsif($ENV{'overlay_scale'}){
	my $image_data;
	eval {
		$image_data=get_image_data($input_image);
		if ($ENV{'debug'}) {
			print Dumper($image_data);
		}
	};
	if ($@) {
		print "-ERROR: Unable to determine image properties from imagemagick: $@\n";
		exit(1);
	}
	my $scale=$image_data->{'width'}."x".$image_data->{'height'};
	print "INFO: Scaling overlay image to $scale...\n";
	$processed_overlay_image = do_scale($overlay_image,$scale);
	$processed_input_image=$input_image;
	$delete_processed_overlay=1;
} else {
	print "INFO: NOT scaling base image.\n";
	$processed_input_image=$input_image;
	$processed_overlay_image=$overlay_image;
	$delete_processed_input=0;
	$delete_processed_overlay=0;
}

print "INFO: Compositing images...\n";
print "\"$processed_overlay_image\" \"$processed_input_image\" \"$output_image\"";
my $result = `composite "$processed_overlay_image" "$processed_input_image" "$output_image"`;
if($? != 0){
	print $result;
	unlink($processed_input_image) if($delete_processed_input);
	unlink($processed_overlay_image) if($delete_processed_overlay);
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
print "INFO: Deleting temp files\n";
unlink($processed_input_image) if($delete_processed_input);
unlink($processed_overlay_image) if($delete_processed_overlay);
print "+SUCCESS: $output_image output to meta:$output_key\n";


