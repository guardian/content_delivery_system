#!/usr/bin/perl
$|=1;

my $version='$Rev: 1029 $ $LastChangedDate: 2014-09-12 19:07:27 +0100 (Fri, 12 Sep 2014) $';

#This method will archive any specified files (media, meta etc.) using SAN-efficient commands if possible.
#
#Once "archived" in this way, a file is no longer accessible to the route.
#
#Arguments:
# <take-files>{media|meta|inmeta|xml} - archive these files
# <archive-path>/path/to/archive - archive the files to this location (accepts substitutions)
# <recurse-m3u/> - if the media file specified is an m3u8 playlist, read it and also archive all referenced content
# <basepath>/path/to/m3u8 - when archiving m3u8 playlists, use this is the base path - i.e., where the main index sits.  The main index stores paths relative to this.
# <keep-original/> - copy the files, don't move them.  This will give you one 'archived' copy that is no longer managed by CDS and keep the original intact.
# <archive-dated-folder/> - archive to a subfolder of archive-path, labelled with the current date/time
# <date_format>%y%m%d... - use the specified format to generate the name of the folder for archive-dated-folder.  Details on the format can be found by typing 'man date' at a unix prompt or searching the Web for 'date manpage'. No + is required at the start.
# <prepend>extra_file_name - put this text onto the start of the archived copy of the file
# <conflict_append_number/> - if the given file exists in the location, then append a number to the filename to make a unique one
#END DOC

require 5.008008;
#use strict;
use warnings;

use File::Basename;
use File::Path qw/make_path/;
use Data::Dumper;
use CDS::Datastore;

my $sourceFileName;
my $archivePath;
my $destFileName;
my $shouldDelete;

sub read_m3u {
my($filename,$basepath)=@_;
#$debug=1;

my @urls;

print "read_m3u: new file\n---------------\n" if $debug;

open $fh,"<$filename" or sub { print "Unable to open file.\n"; return undef; };

my @lines=<$fh>;

foreach(@lines){
	#print "$_\n"
	#if($debug);
	if(not /^#/){
		chomp;
		#fixme: there should possibly be a more scientific test than this!!
		if(/^http:/){
			if(/\/([^\/]+\/[^\/]+)$/){
				my $filename="$basepath/$1";
				push @urls,$filename;
				print "debug: read_m3u: got filename $filename.\n";
			}
		}
	}
}
print "------------------\n" if $debug;
close $fh;
#print Dumper(\@urls);
return @urls;
}

sub interrogate_m3u8 {
my ($url,$basepath)=@_;

my @contents;
my @urls;
my $filename;

print "INFO: interrogating url at $url.\n";

if($url=~/^http:/){	#we've been passed a real URL.  Assume that any contents is in subdirs relative to $basepath.
	if($url=~/\/([^\/]+\/[^\/]+)$/){
		$filename="$basepath/$1";
		print "debug: interrogate_m3u - got 'real' file at $filename.\n";
	} else {
		print "debug: interrogate_m3u - URL $url doesn't look like it corresponds to something in $basepath.\n";
	}
} else {
	$filename=$url;
}

if(-f $filename){
	@contents=read_m3u($filename,$basepath);
	foreach(@contents){
		#print "$_\n";
		push @urls,$_;
		my @supplementary_urls=interrogate_m3u8($_,$basepath) if(/\.m3u8$/);
		push @urls,@supplementary_urls;
	}
} else {
	print "-WARNING: Unable to find file '$filename'.\n";
}
#print Dumper(\@urls);
return @urls;
}

print STDOUT "\nMESSAGE: Perl script archive_to_san invoked\n";
my $store=CDS::Datastore->new('archive_to_san');

#print STDOUT "debug: dump of environment follows\n";
#print Dumper(\%ENV);

if ($ENV{'archive-path'})
{
	print STDOUT "MESSAGE: archive-path $ENV{'archive-path'}\n";
	$archivePath = $store->substitute_string($ENV{'archive-path'});
}

my $basepath=$store->substitute_string($ENV{'basepath'});
my $outfolder;

make_path($archivePath);

# check if archive path exists
if (-d $archivePath)
{
	my @fileNames;
	my $numFiles = 0;
	
	if($ENV{'cf_media_file'})
	{
		push(@fileNames, $ENV{'cf_media_file'});
		if(defined $ENV{'recurse-m3u'}){
			my $fn=basename($ENV{'cf_media_file'});
			$fn=~/^(.*)\.[^\.]*/;
			$outfolder="$1/";
		}
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
	
	if(defined $ENV{'recurse-m3u'}){
		foreach(@fileNames){
			my @extra_files=interrogate_m3u8($_,$basepath) if($_=~/\.m3u8$/);
			push @fileNames,@extra_files;
		}
	}
	
	print STDOUT "MESSAGE: Files to archive @fileNames\n";
	
	my $cmd;
	my $shouldDelete=0;
	if(defined $ENV{'keep-original'}){
		if(-x "/usr/bin/cvcp"){
			$cmd="/usr/bin/cvcp -y";	#-y=>preserve ownership etc. details
			$shouldDelete=0;
		} else {
			print "WARNING: Unable to find xsan copy program cvcp.  Falling back to regular system copy.\n";
			$cmd="/bin/cp";
			$shouldDelete=0;
		}
		print "MESSAGE: archive_to_san: Keeping original files (i.e. copying)\n";
	} else {
		if(-x "/usr/bin/cvcp"){
			$cmd="/usr/bin/cvcp -y";	#-y=>preserve ownership etc. details
			$shouldDelete=1;
		} else {
			print "WARNING: Unable to find xsan copy program cvcp.  Falling back to regular system copy.\n";
			$cmd="mv -vf ";
			$shouldDelete=0;
		}
		print "MESSAGE: archive_to_san: Removing original files (i.e. moving)\n";
	}

	# If the following environment variable exists and is set to true, create a new folder with
	# the current date and time in the name.
	my $currentTime=`date +%y%m%d_%H%M%S`;
	
	if(defined $ENV{'archive-dated-folder'})
	{
		if($ENV{'archive-dated-folder'} eq "true") 
		{
			# get the current date & time as a string
			#$currentTime = `date`;
			
			print "MESSAGE: archive_to_san: Using a dated folder\n";
			if(defined($ENV{'date_format'}))
			{
				my $processArgument = "date +" . $ENV{'date_format'};
				$currentTime = `$processArgument`;					
			}
			else
			{
				$currentTime = `date +%y%m%d_%H%M%S`;
			}	
			
			chomp($currentTime);
			$currentTime =~ s/ |://g;
				
			my $newFolderPath =  $archivePath . "/" . $currentTime; 
				
			# make a folder with the date
			mkdir $newFolderPath, 0755;
				
			# update the archive path to have the new folder path
			$archivePath = $newFolderPath;			
		}
	}
	
	my $prepend;
	if(defined $ENV{'prepend'})
	{
		$prepend=$store->substitute_string($ENV{'prepend'});
		$prepend=~s/{date}/$currentTime/g;
	}
	$numFiles = @fileNames;
	
	# move files to location
	for (my $i = 0; $i < $numFiles; $i++)
	{
		$sourceFileName = fileparse($fileNames[$i]);
		if(defined $ENV{'prepend'})
		{
			#$outfolder is empty unless recurse-m3u is set, when it will contain the folder name to output to.
			$destFileName = $archivePath . "/" . $outfolder. $prepend . $sourceFileName;	
		} else {
			$destFileName = $archivePath . "/" . $outfolder . $sourceFileName;	
		}
		
		if(not -d dirname($destFileName)){
			make_path(dirname($destFileName));
		}
		
		# Might as well check the source file exists.
		unless ( -e  $fileNames[$i])
		{
			print STDERR "-ERROR: source file '$fileNames[$i]' to archive does not exist\n";
	#		exit 1;
		}	
		
		# Does a file with the destination name file name already exist?
		if ( -e $destFileName)
		{
			print STDERR "WARNING: file with same name exists at destination\n";
			my $filepart,$xtn;
			
			if($ENV{'conflict_append_number'}){
				if($destFileName=~/^(.*)(\.[^\.]+)/){
					$filepart=$1;
					$xtn=$2;
				} else {
					$filepart=$destFileName;
					$xtn="";
				}
				my $n=1;
				do {
					$destFileName=$filepart."-$n".$xtn;
					++$n;
					if($ENV{'debug'}){
						print STDERR "DEBUG: testing file name $destFileName...\n";
					}
				} while(-e $destFileName);
				print STDERR "INFO: New file name is $destFileName\n";
			}
		}
		
		print STDOUT "MESSAGE: destination file '$destFileName'\n";
		
		my $r;
		$r=system("$cmd \"". $fileNames[$i] ."\" \"".$destFileName."\"");
		if($r==0)
		{
			print STDOUT "+SUCCESS: file '$destFileName' moved to archive location (return code $r,exit code $!)\n";
			unlink($fileNames[$i]) if($shouldDelete);
		}
		else
		{
			print STDERR "-ERROR: file move failed (return code $r,exit code $!)\n";
#			exit 1;			
		}
	}
}
else
{
	print STDERR "-FATAL: archive path '$archivePath' does not exist\n";
	exit 1;
}
