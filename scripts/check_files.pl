#!/usr/bin/perl
$|=1;
# This CDS method checks to see if the specified files exist, and outputs their current known location
# to the log.  An error is returned if the file(s) do not exist, use <nonfatal/> to stop this aborting the route.
#
# Arguments:
# <take-files>{media|meta|inmeta|xml} - check the specified 'known' files
# <extra_files>/path/to/file1|/path/to/file2 - add this list of extra files (delimited by |) to the files to check.  Substitutions are accepted.


my $version='$Rev: 1094 $ $LastChangedDate: 2014-11-11 19:19:05 +0000 (Tue, 11 Nov 2014) $';

require 5.008008;
use strict;
use warnings;
use CDS::Datastore;

print STDOUT "\nMESSAGE: Perl script check_files.pm version $version invoked\n";

my $myVar = $#ARGV + 1;

# get environment variable settings for the:  cf_media_file, cf_meta_file, cf_inmeta_file, cf_xml_file

my $mediaFile = $ENV{'cf_media_file'};
my $metaFile =  $ENV{'cf_meta_file'};
my $inmetaFile =  $ENV{'cf_inmeta_file'};
my $xmlFile =  $ENV{'cf_xml_file'};

my $store=CDS::Datastore->new('check_files');

my @extrafiles=split(/\|/,$ENV{'extra_files'});

if($mediaFile)
{
	unless(-e $mediaFile)
	{
		print STDERR "-FATAL: media file '$mediaFile' does not exist\n";
		exit 1;
	}
	else
	{
		print STDOUT "+SUCCESS: media file '$mediaFile' does exists\n";
	}
}

if($metaFile)
{
	unless(-e $metaFile)
	{
		print STDERR "-FATAL: meta file '$metaFile' does not exist\n";
		exit 1;
	}	
	else
	{
		print STDOUT "+SUCCESS: meta file '$metaFile' exists\n";		
	}
}

if($inmetaFile)
{
	unless(-e $inmetaFile)
	{
		print STDERR "-FATAL: inmeta file '$inmetaFile' does not exist\n";
		exit 1;
	}	
	else
	{
		print STDOUT "+SUCCESS: inmeta file '$inmetaFile' exists\n";		
	}	
}

if($xmlFile)
{
	unless(-e $xmlFile)
	{
		print STDERR "-FATAL: xml file '$xmlFile' does not exist\n";
		exit 1;
	}	
	else
	{
		print STDOUT "+SUCCESS: xml file '$xmlFile' exists\n";		
	}	
}

foreach(@extrafiles){
	my $filetocheck=$store->substitute_string($_);
	unless(-f $filetocheck){
		print STDERR "-FATAL: extra file '$filetocheck' does not exist.\n";
		exit 1;
	} else {
		print STDOUT "+SUCCESS: extra file '$filetocheck' exists\n";
	}
}
