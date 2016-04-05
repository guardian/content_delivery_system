#!/usr/bin/perl
$|=1;

my $version='$Rev: 651 $ $LastChangedDate: 2014-01-01 16:57:45 +0000 (Wed, 01 Jan 2014) $';

#SUPERCEDED BY ARCHIVE_TO_SAN. This is a CDS method to move the media, inmeta, meta and/or xml files to a new location.  It will move anything specified in <take-files>.
#
#Arguments:
#  <dest-path>/path/to/archive - Move the files to this location. Substitutions are accepted.
#  <dest-dated-folder/>		- Move the files to a folder with today's date under <dest-path>
#  <keep-original/>		- Copy, don't move, the files.
#END DOC

require 5.008008;
use strict;
use warnings;

use File::Basename;
use File::Copy;
use CDS::Datastore;

my $destPath;
my $keepOriginal = 0;
my $useDatedFolder = 0;

print STDOUT "\nMESSAGE: Perl script move_to version $version invoked\n";

my $store=CDS::Datastore->new('move_to');

if ($ENV{'dest-path'})
{
	# print STDOUT "archive-path $ENV{'dest-path'}\n";
	$destPath = $ENV{'dest-path'};
}

if( defined($ENV{'dest-dated-folder'}))
{
	if($ENV{'dest-dated-folder'} eq "true")
	{
		print STDOUT "MESSAGE: use dest-dated-folder ".$ENV{'dest-dated-folder'}". specified\n";
		$useDatedFolder = 1;	
	}
}

if( defined($ENV{'keep-original'}) )
{
	if($ENV{'keep-original'} eq "true")
	{
		$keepOriginal = 1;
	}
}

# check if dest path exists

print STDOUT "MESSAGE: check if '$destPath' exists\n";

if (-d $destPath)
{
	my @fileNames;
	my $fileName;
	my $destFileName;
	my $numFiles = 0;
	
	if($ENV{'cf_media_file'})
	{
		push(@fileNames, $ENV{'cf_media_file'});
	}

	if($ENV{'cf_meta_file'})
	{
		push(@fileNames, $ENV{'cf_meta_file'});
	}	
	
	if($ENV{'cf_inmeta_file'})
	{
		push(@fileNames, $ENV{'cf_inmeta_file'});
	}

	if($ENV{'cf_xml_file'})
	{
		push(@fileNames, $ENV{'cf_xml_file'});
	}	
	
	$numFiles = @fileNames;
	
	if($numFiles == 0)
	{
		print STDERR "-FATAL: environment variables are not set for files\n";
		exit 1;
	}
	
	# add a slash to the end of the path if needed.
	$destPath = $store->subsitutue_string($destPath . "/");
	
	for (my $i = 0; $i < $numFiles; $i++)
	{
		$fileName = $store->substitute_string(fileparse($fileNames[$i]));
		
		if($useDatedFolder == 1)
		{
			# get the current date & time as a string
			my $currentTime = `date`;
			chomp($currentTime);
			$currentTime =~ s/ |://g;
			
			my $newFolderPath =  $destPath . $currentTime; 
			
			# make a folder with the date
			mkdir $newFolderPath, 0755;
			
			# include the new folder name in the destination path
			$destFileName = $newFolderPath . "/" . $fileName;			
		}
		else
		{	
			$destFileName = $destPath . $fileName;
		}
		
		$destFileName=$store->substitute_string($destFileName);
	
		if($keepOriginal ==  1)
		{
			# copy files to location
			print STDOUT "MESSAGE: Copy file to $destFileName\n";
					
			if(copy ($fileNames[$i], $destFileName))
			{
				print STDOUT "+SUCCESS: file copied to location\n";
			}
			else
			{
				print STDERR "-FATAL: file failed to copy to location\n";	
				exit 1;			
			}			
		}
		else
		{
			# move files to location
			print STDOUT "MESSAGE: Move file to $destFileName\n";
			
			if(move $fileNames[$i], $destFileName)
			{
				print STDOUT "+SUCCESS: file moved to location\n";
			}
			else
			{
				print STDERR "-FATAL: file failed to move to location\n";	
				exit 1;							
			}			
		}
	}
}
else
{
	print STDERR "-FATAL: dest $destPath path does not exist";
	exit 1;
}
