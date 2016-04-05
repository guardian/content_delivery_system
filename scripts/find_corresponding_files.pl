#!/usr/bin/perl
$|=1;

my $version='$Rev: 967 $ $LastChangedDate: 2014-08-08 16:09:37 +0100 (Fri, 08 Aug 2014) $';

#This module searches a given location for the file types specified.
#if using batch mode, then you should specify it as a "process-method" so that it is
#run for each file in the batch.
#
#It expects the following arguments from the route XML:
#  provided-file - {media|meta|inmeta|xml} - use this file to work out what the name should be
#  OR provided-name - {string} - take this as the expected name (e.g., <provided-name>{meta:File Name}</provided-name>)
#  find-files - {media|meta|inmeta|xml} - set these files
#  library-path - search this location for files
#  recursive [OPTIONAL] - set this to do a recursive search under library-path.  WARNING: setting this could mean that each file search takes a long time.
#  continue-if-not-found [OPTIONAL] - set this to not report an error if the file cannot be found.
#  append-media-extension [OPTIONAL] - set this to append the given extension when searching for media etc., if it cannot be found otherwise.
#  remove-extension [OPTIONAL] - set this to remove the extension from the incoming file when searching
#  switch-extension [OPTIONAL] - change the incoming file's extension to this for the purposes of matching
#  no-auto-extension [OPTIONAL] - don't automatically assume a meta/inmeta/xml file has the right extension
#  max-retries [OPTIONAL] - if a file is not found, then wait this number of times for it to be present before failing.
#  retry-wait [OPTIONAL] - wait this number of seconds between retries (default: 3s)
#It also expects the following from cds_run:
#cf_{media|meta|inmeta|xml}_file - to work out what file we're looking for
#cf_temp_file

use File::Basename;
use CDS::Datastore;

sub check_args {
	my @args=@_;

	foreach(@args){
		if(not defined $ENV{$_}){
			print "-FATAL: $_ was not specified.  Please check the route file.\n";
			exit 1;
		}
	}
}

sub search_directory {
	my ($directory,$filename,$recurse,$recurse_level)=@_;
	
	#if(not $recurse){
	print "INFO: search_directory: ".$directory."/".$filename."\n";
		if(-f $directory."/".$filename){
			print "INFO: Found $directory/$filename.\n";
			return $directory."/".$filename;
		}else{
			return undef unless($recurse);
		}
		
	#} else {
		my $dh;
		opendir $dh,$directory;
		my @files=readdir $dh;
		closedir $dh;
		#if(-f $directory."/".$filename){
		#	return $directory."/".$filename;
		#}
		foreach(@files){
			if(-d $directory."/".$_ and not /^\./ and $recurse){
				print "MESSAGE: Searching directory '$directory/$_'...\n";
				my $r=search_directory($directory."/".$_,$filename,$recurse,$recurse_level+1);
				return $r if($r);
			}#elsif(-f $directory."/".$_){
			#	return $directory."/".$filename if($_ == $filename);
			#}
		}
		return undef;
	#}
}

#START MAIN
#check arguments

check_args(qw(find-files library-path cf_temp_file));
#print `set | grep cf_`;

my $store=CDS::Datastore->new('find_corresponding_file');

my $basename;
if($ENV{'provided-file'}){
	$basename=basename($ENV{'cf_'.$ENV{'provided-file'}.'_file'});
	#print "Got basename $basename\n";
	if($ENV{'provided-file'} ne 'media'){
		$basename=~s/\.$ENV{'provided-file'}$//;
	}
} elsif($ENV{'provided-name'}){
	$basename=$store->substitute_string($ENV{'provided-name'});
} else {
	print "-ERROR: You must specify either <provided-file> or <provided-name> in the route file.\n";
	exit 1;
}

print "Searching for basename $basename.\n";

my $max_retries=0;
if(defined $ENV{'max-retries'}){
	$max_retries=$ENV{'max-retries'};
}

my $retry_wait=3;	#seconds
if(defined $ENV{'retry-wait'}){
	$retry_wait=$ENV{'retry-wait'};
}

if(defined $ENV{'remove-extension'}){
	if($basename=~/^(.*\.)[^\.]+$/){
		$basename=$1;
	}
}

if(defined $ENV{'switch-extension'}){
	if($basename=~/^(.*)\.[^\.]+$/){
		$basename="$1.".$ENV{'switch-extension'};
	}
}

open FH,">:utf8",$ENV{'cf_temp_file'} or die "-FATAL: Unable to open temporary file '".$ENV{'cf_temp_file'}."' for writing\n";

my @looking_for=split /\|/,$ENV{'find-files'};
my $found=0;

foreach(@looking_for){
	my $i=0;
	my $filetype=$_;
	while(not $found){
		my $searching_filename;
		if(not defined $ENV{'no-auto-extension'} and $_ ne 'media'){
			$searching_filename=$basename.".$_"; #append the file extension we're interested in - .meta, .inmeta, .xml
		} else {
			$searching_filename=$basename;
		}
		my $recurse;
		if(defined $ENV{'recursive'}){
			$recurse=1;
		}else{
			$recurse=0;
		}
		print "Searching for '$searching_filename'\n";
		
		my $lp=$store->substitute_string($ENV{'library-path'});
		my $found_filename=search_directory($lp,$searching_filename,$recurse,0);
		
		if(defined $found_filename){
			print "MESSAGE: Found file $found_filename\n";
			print FH "cf_".$filetype."_file=$found_filename\n";
			$found=1;
		} else {
			print "MESSAGE: Unable to find file '$searching_filename' in '".$lp."'\n";
			if(defined $ENV{'append-media-extension'}){
				unless($_ eq 'media'){
					$searching_filename=$basename.$ENV{'append-media-extension'}.$_;
				} else {
					$searching_filename=$basename.$ENV{'append-media-extension'};
				}
				$found_filename=search_directory($lp,$searching_filename,$recurse,0);
			}
			if(defined $found_filename){
				print "MESSAGE: Found file $found_filename\n";
				print FH "cf_".$filetype."_file=$found_filename\n";
				$found=1;
			} else {
				if(not defined $ENV{'continue-if-not-found'} and $i>=$max_retries){
					print "-FATAL: Exiting as I couldn't find ".$searching_filename.".  To suppress this, set <continue-if-not-found/> in the XML route file\n";
					close FH;
					exit 2;
				}
			}
		}	#if(defined $found_filename) else
		++$i;
		last if($i>$max_retries);
		sleep($retry_wait) if(not $found);
	}	#while(not $found);
}
close FH;

if(not $found){
	print "-ERROR: Could not find '$searching_filename'. Exiting.\n";
	exit 1;
}
exit 0;
