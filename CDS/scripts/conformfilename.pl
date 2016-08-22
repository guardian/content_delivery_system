#!/usr/bin/perl

my $version='$Rev: 651 $ $LastChangedDate: 2014-01-01 16:57:45 +0000 (Wed, 01 Jan 2014) $';

#This script ensures that the media file is conformed to a file name convention with no spaces, no characters other than letters or numbers
#and with a YYMMDD date on the front
#
#Arguments:
# <take-file>{media|meta|inmeta|xml} - conform the filenames of the given route files.  This will change the name on-disk and update CDS to use the new filename.
# END DOC

use File::Copy;
use File::Basename;

sub conform_name {
my $incoming_file_name=shift;

if($incoming_file_name=~/^\d{6}[A-Za-z0-9\.]$/){
	return $incoming_file_name;
}

$incoming_file_path=dirname($incoming_file_name);
$incoming_file_name=basename($incoming_file_name);

my $new_name;

if($incoming_file_name=~/^(\d*)(.*)\.([^\.]+)$./){
	my $prepend_nums=$1;
	my $main_name=$2;
	my $xtn=$3;
	print "debug: got $prepend_nums as prepend, $main_name as main name, $xtn as file extension\n";
	
	unless($prepend_nums){
		my @date_elems=localtime(time);
		$prepend_nums=sprintf("%02d%02d%02d",$date_elems[5] % 100,$date_elems[4],$date_elems[3]);
	}
	$main_name=~s/[^A-Za-z0-9]//g;
	
	$new_name=$prepend_nums.$main_name.'.'.$xtn;
	
	print "debug: renaming $incoming_file_name to $new_name\n";
	my $r=move($incoming_file_path.'/'.$incoming_file_name,$incoming_file_path.'/'.$new_name);
	print "-ERROR: File rename failed: $!\n" unless($r);
	return $incoming_file_path.'/'.$new_name;
}

return undef;
}

#START MAIN
my $tempfile=$ENV{'cf_temp_file'};

open FHTEMP,">:utf8",$tempfile;

my $changed=0;

foreach(qw/media meta inmeta xml/){
	my $orig=$ENV{'cf_'.$_.'_file'};
	print "$_=$orig\n";
	if($orig){
		print "info: conforming $_ file $orig...\n";
		my $newname=conform_name($orig);
		unless($newname eq $orig){
			print FHTEMP "cf_".$_."_file=$newname\n";
			++$changed;
		}
	}
}

close FHTEMP;

if($changed<1){
	print "-WARNING: No files were changed.\n";
	exit 0;
}

print "success: changed a total of $changed files.\n";
exit 0;
