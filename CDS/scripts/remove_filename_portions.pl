#!/usr/bin/perl

use File::Copy;
use Data::Dumper;
use CDS::Datastore;
use File::Basename;
use File::Path qw/make_path/;

my $version='$Rev: 1258 $ $LastChangedDate';

#This module is a CDS method to remove certain portions of the filename of incoming files,
#renaming them as we go, in order to not confuse media pump et. al.

#Arguments:
# <filename-skip-portions>n - remove this number of portions from the filename
# <filename-portion-delimiter>_ [OPTIONAL] - use this character to split the filename into portions.  This is a regex expression.
# <lowercase/> [OPTIONAL] - convert entire filename to lower-case
# <uppercase/> [OPTIONAL] - convert entire filename to upper-case
# <from-end/> [OPTIONAL] - skip sections from the end of the filename rather than the start
# <invert/> [OPTIONAL] - keep the sections that would be skipped, and remove the sections that would be kept
# <symlink/> [OPTIONAL] - symlink the old file to the new file, rather than rename/move
# <output_path>/path/to/output [OPTIONAL] - move or symlink the target file here, rather than its current directory
# <fail_immediate/> [OPTIONAL] - if a rename/symlink fails, exit rightaway rather than trying to complete all renames
# <allow_existing/> [OPTIONAL] - don't error if the destination file already exists
#END DOC

sub conformFile
{
my($baseName)=@_;
	my $newstring;
	
	$baseName=basename($baseName);
	
	my $xtn="";
	if($baseName=~/\.([^\.]+)$/){
		$xtn=".$1";
	}
	
	my $delimiter=$ENV{'filename-portion-delimiter'};
	$delimiter='_' unless($delimiter);
	
	my $skip_n_portions=$ENV{'filename-skip-portions'};
	if($skip_n_portions){
		my $op="skip";
		$op="keep" if($ENV{'invert'});
			
		print "INFO: attempting to $op $skip_n_portions portions of the filename $baseName with delimiter $delimiter\n";

		my @portions=split /\Q$delimiter/,$baseName;
		if($skip_n_portions > scalar @portions){
			print STDERR "Warning: Cannot skip $skip_n_portions of filename $baseName with delimiter $delimiter because there are only ".scalar @portions." seperate portions\n";
			local $Data::Dumper::Pad="\t";
			print Dumper(\@portions);
		} else {
			if($ENV{'from-end'}){
				my $l=scalar(@portions);
				my $n=scalar(@portions)-$skip_n_portions;
				print "\nl is $l, n is $n\n" if($ENV{'debug'});
				$newstring=join($delimiter,@portions[$n .. $l]);
				local $Data::Dumper::Pad="\t";
				print Dumper(\@portions[$n .. $l]);
			} else {
				$newstring=join($delimiter,@portions[0 .. $skip_n_portions-1]);
				local $Data::Dumper::Pad="\t";
				print Dumper(\@portions[$skip_n_portions .. -1]);
			}
			chop $newstring if($newstring=~/$delimiter$/);
			print "newstring is '$newstring'\n" if($ENV{'debug'});
			if($ENV{'invert'}){
				$baseName=$newstring;				
			} else {
				#$baseName=~s/$newstring//;
				$stringAt = index($baseName,$newstring);
				print "\n'$newstring' is contained within $baseName at $stringAt\n" if($ENV{'debug'});
				if($stringAt<1){
					$baseName = substr($baseName,scalar($newstring));
				} else {
					$baseName = substr($baseName,0,$stringAt);
				}
				$baseName=substr($baseName,1) if($baseName[0] eq $delimiter);
				chop $baseName if($baseName=~/$delimiter$/);
			}
		}
	}
	
	if(not $baseName=~/$xtn$/){
		$baseName=$baseName.$xtn;
	}
	$baseName=uc $baseName if($ENV{'uppercase'});
	$baseName=lc $baseName if($ENV{'lowercase'});
	
	print "DEBUG: final filename: $baseName\n";
	
	return $baseName;
}

sub do_file_move
{
my ($src_file,$new_file_name,$dirname,$debug) = @_;
	
	if($ENV{'allow_existing'}){
		if(-f "$dirname/$new_file_name"){
			print "INFO: $dirname/$new_file_name already exists. allow_existing specified so continuing.\n";
			return 1;
		}
	}
	
	$new_file_name="$dirname/$new_file_name";
	
	if($ENV{'symlink'}){
		print "DEBUG: symlinking $src_file to $new_file_name\n" if($debug);
		make_path($dirname);
		my $rv=symlink($src_file,$new_file_name);
		unless($rv){
			print "-ERROR: Unable to symlink ".$ENV{$_}.": $!\n";
			return 0;
			exit 1 if($ENV{'fail_immediate'});
		}
	} else {
		print "DEBUG: moving $src_file to $new_file_name\n" if($debug);
		my $rv=move($src_file,$new_file_name);
		unless($rv){
			print "-ERROR: Unable to rename ".$ENV{$_}.": $!\n";
			return 0;
			exit 1 if($ENV{'fail_immediate'});
		}
	}
	return $new_file_name;
	
}

#START MAIN
my $store=CDS::Datastore->new('remove_filename_portions');

my @filenames;

#foreach(qw/cf_media_file cf_meta_file cf_inmeta_file cf_xml_file/){
#	push @internal_filenames,$ENV{$_} if($ENV{$_});
#}

my @extra_files=split /\|/,$store->substitute_string($ENV{'extra-files'});
#push @filenames,@extra_files;

my $debug=$ENV{'debug'};

#print Dumper(\%ENV);

open $fhtemp,">",$ENV{'cf_temp_file'};

#if($debug){
#	print "remove_filename_portions - list of files to work on:\n";
#	local $Data::Dumper::Pad="\t";
#	print Dumper(@internal_filenames);
#}

#	foreach(@internal_filenames){
#		my $new_filename=
my $failures=0;

foreach(qw/cf_media_file cf_meta_file cf_inmeta_file cf_xml_file/){
	my $dirname;
	
	print "$_=".$ENV{$_}."\n" if($debug);
	next unless($ENV{$_});
	print "Taking valid $_ '".$ENV{$_}."'...\n" if($debug);
	my $new_file_name=conformFile($ENV{$_});
	print "Got new file name $new_file_name\n" if($debug);
	
	if($ENV{'output_path'}){
		$dirname=$store->substitute_string($ENV{'output_path'});
	}
		
	my $rv=do_file_move($ENV{$_},$new_file_name,$dirname,$debug);
	
	if($rv){
		print $fhtemp "$_=$rv\n";
	} else {
		++$failures;
	}
}

foreach(@extra_files){
	my $new_file_name=conformFile($_);
	unless($new_file_name eq $_){
		my $dirname=dirname($_);
		
		if($ENV{'output_path'}){
			$dirname=$store->substitute_string($ENV{'output_path'});
		}
		
		my $rv=do_file_move($_,$new_file_name,$dirname,$debug);
		++$failures unless($rv);
	}
}

close $fhtemp;

if($failures>0){
	exit(1); #flag that the method failed, to the Skeleton.
}

exit 0;
