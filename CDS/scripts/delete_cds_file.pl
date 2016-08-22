#!/usr/bin/perl
$|=1;

my $version='$Rev: 651 $ $LastChangedDate: 2014-01-01 16:57:45 +0000 (Wed, 01 Jan 2014) $';

#This script will delete the media, inmeta, meta or XML files if they're specified in <take-files>.
#You also need to specify a list of file extensions that will be deleted, to prevent accidental deletions.

#Arguments:
# <filetypes> = |-seperated list of file extensions (including the .) to delete

#END DOC
#Implied:
# cf_{media|meta|inmeta|xml}_file - files to act on
# cf_temp_file - use to output new names (i.e., blanking)
#Exits:
# 0=>OK
# 1=>No filetypes specified
# 2=>No temp file specified

print "delete_file v1.0 invoked\n";

if(length $ENV{'filetypes'} < 2){
	print STDERR "-FATAL: You must specify the filetypes to delete\n";
	exit 1;
}

if(length $ENV{'cf_temp_file'} < 2){
	print STDERR "-FATAL: This module requires a temp file to pass back modified filenames.\n";
	exit 2;
}

my @types_list=split /\|/,$ENV{'filetypes'};

foreach(('media','inmeta','meta','xml')){
	my $varname="cf_".$_."_file";
	if(defined $ENV{$varname}){
		foreach(@types_list){
			if($ENV{$varname}=~/$_$/){
				print STDOUT "Deleting the $varname '".$ENV{$varname}."'\n";
				my $r=unlink($ENV{$varname});
				if($r != 1){
					print STDERR "-WARNING: An error ocurred deleting the $varname '".$ENV{$varname}."'\n";
				}
				open FH,">>".$ENV{'cf_temp_file'};
				print FH "$varname=\n";
				close FH;
			}
		}
	}
}
exit 0;
