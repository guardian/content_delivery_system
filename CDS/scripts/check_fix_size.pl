#!/usr/bin/perl

#This is a simple script to check if {media:size} is set, and to set it if not.
#Remember to set <take-files>media</take-files>!

use CDS::Datastore;

#START MAIN
my $store;

eval {
$store=CDS::Datastore->new('check_fix_size');
};

my $media=$ENV{'cf_media_file'};

unless(-f $media){
	print "-ERROR: Unable to find media file $media!\n";
	exit 1;
}

my $currentsize;

eval {
	my $currentsize=$store->get('media','size');
};

if($currentsize<1){
	my $realsize=-s $media;
	print "Got real file size $realsize.\n";
	
	$store->set('media','size',$realsize);
	print "+Success - output real file size to media:size\n";
}
print "File size already present, not changing.\n";

exit 0;
