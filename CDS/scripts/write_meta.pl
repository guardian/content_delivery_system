#!/usr/bin/perl

my $version='$Rev: 472 $ $LastChangedDate: 2013-08-14 14:25:30 +0100 (Wed, 14 Aug 2013) $';

#This module will write the contents of the datastore in .meta format to a given location
use CDS::Datastore::Episode5;

#arguments:
#<ouput_path>/path/to/output/{filebase}.meta - output to this location.
#<set_meta_file/> - tell the route that this is the new 'meta' file.
#<inmeta_format/> - use the 'inmeta' format as opposed to 'meta'
#You need to use a substitution ({filebase} here) to get unique filenames.

if(not $ENV{'output_path'}){
	print STDERR "ERROR - You must specify an output location using <output_path>.\nTo get a unique filename, use a substitution like {filebase}\n";
	exit 1;
}

my $store=CDS::Datastore::Episode5->new('write_meta');

my $output_path=$store->substitute_string($ENV{'output_path'});

print "INFO - outputting .meta file to '$output_path'.\n";

if($ENV{'inmeta_format'}){
	unless($store->export_inmeta($output_path)){
		print "-ERROR - unable to export file! See log trace for details.\n";
		exit 1;
	}
	$output_var="cf_inmeta_file";
} else {
	unless($store->export_meta($output_path)){
		print "-ERROR - unable to export file! See log trace for details.\n";
		exit 1;
	}
	$output_var="cf_meta_file";
}

if($ENV{'set_meta_file'} or $ENV{'set_inmeta_file'}){
	print "Outputting $output_path as the new $output_var..\n";
	unless($ENV{'cf_temp_file'}){
		print "-ERROR - cf_temp_file not set, unable to communicate with cds_run\n";
		exit 1;
	}
	open FH,">".$ENV{'cf_temp_file'} or die "-ERROR: unable to write to ".$ENV{'cf_temp_file'};
	print FH "$output_var=$output_path\n";
	close FH;
}

print "+SUCCESS - metadata exported.\n";
exit 0;

