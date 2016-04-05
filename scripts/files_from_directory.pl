#!/usr/bin/perl
$|=1;

my $version='$Rev: 517 $ $LastChangedDate: 2013-10-07 12:07:00 +0100 (Mon, 07 Oct 2013) $';

#This module is an input method which lists the contents of a given directory,
#attempts to classify the files and triggers batch mode processing in cds_run
#This works in the same way as ftp_pull, but when the files are available locally.
#Arguments:
# <input-path>/path/to/input - directory to watch
# <expect-files> {media|meta|inmeta|xml} - files to expect in the directory
# <holdoff-file>/path/to/holdoff.file - temp file to create while we are processing.  If this file exists, then we flag an error and exit.
# <ditch-unexpected-files/> [optional] - whether to remove 'unexpected' files - NOT IMPLEMENTED.
# <working-directory>/path/to/working/folder - place to move the files to, in order to work on them.
#END DOC

#It also expects:
# cf_temp_file
#It sets any of the cf_*_file and also sets batch mode.

use Data::Dumper;
use File::Copy;

sub check_args {
	my @args=@_;

	foreach(@args){
		if(not defined $ENV{$_}){
			print "-FATAL: $_ was not specified.  Please check the route file.\n";
			exit 1;
		}
	}
}

#simple, dumb classification by file extension.
sub classify_file {
	my ($filename)=@_;

	$filename=~/^(.*)\.([^\.]*)$/;
	if($2 eq 'meta' or $2 eq 'inmeta' or $2 eq 'xml'){
		return ($2,$1);
	} else {
		#remember that the meta filename is media_file.mov.meta, not media_file.meta.  hence we need to pass back the _full_ media filename as the basename.
		return ('media',$filename);
	}
}

sub is_selected {
	my ($needle,@haystack)=@_;

	foreach(@haystack){
		print "debug: is_selected: comparing $needle to $_\n" if defined $ENV{'debug'};
		return 1 if $needle=$_;
	}
	return 0;
}

#check arguments
if(not defined $ENV{'cf_temp_file'}){
	print STDERR "-FATAL: cf_temp_file not defined.  This either means you are not running through cds_run or that there has been an internal problem.\n";
	exit 1;
}
check_args('input-path','expect-files','holdoff-file');

if( -f $ENV{'holdoff-file'}){
	print STDERR "-FATAL: files_from_directory appears to already be running.  If it is not, then remove the file \"".$ENV{'holdoff-file'}."\" and re-run.\n";
	exit 8;
}

system("touch \"".$ENV{'holdoff-file'}."\"");


if(not opendir DH,$ENV{'input-path'}){
	print STDERR "-FATAL: couldn't list directory \"".$ENV{'input-path'}."\"\n";
	unlink($ENV{'holdoff-file'});
	exit 2;
}

my @entries=readdir DH;
close DH;

my $files;

foreach(@entries){
	my %temp;
	my $basename,$filetype;
	my @seen;

	if(-f $ENV{'input-path'}."/".$_ and not $_=~/^\./){	#if it's a file, not directory, device, etc....
		($filetype,$basename)=classify_file($_);
		$temp{'name'}=$_;
		$temp{'type'}=$filetype;
		$temp{'safename'}=$_;
		$temp{'safename'}=~tr/:/_/;
		$temp{'safename'}=~tr/\//_/;
		push @{$files->{$basename}},\%temp;
	}
}

print Dumper($files) if defined $ENV{'debug'};

if(scalar (keys %$files)<1){
	print STDERR "-FATAL: No files were available to find in ".$ENV{'input-path'}.".\n";
	unlink($ENV{'holdoff-file'});
	exit 4;
}

if(not open FH,">:utf8",$ENV{'cf_temp_file'}) {
	print STDERR "-FATAL: couldn't open temp file \"".$ENV{'cf_temp_file'}."\"\n";
	unlink($ENV{'holdoff-file'});
	exit 3;
}
print FH "batch=true\n";

my @valid_types=split /\|/,$ENV{'expect-files'};

foreach(keys %{$files}){
	foreach(@{$files->{$_}}){
		#print Dumper($data->{$_});
		print $_->{'type'};
#		print "$_\n";
		print Dumper($_);
		if(is_selected($->{'type'},@valid_types)){
			if(not move($ENV{'input-path'}."/".$_->{'name'},
				$ENV{'working-directory'}."/".$_->{'safename'})){
				print STDOUT "-WARNING: Unable to move file \"".$_->{'name'}."\" to working directory \"".$ENV{'working-directory'}."\"\n";
			} else {
				print FH $ENV{'working-directory'}."/".$_->{'safename'}.",";
				print $ENV{'working-directory'}."/".$_->{'name'}."\n" if defined $ENV{'debug'};
			}
		} else {
		}
	#	print $_;
	}
	print FH "\n";
}

close FH;

unlink($ENV{'holdoff-file'});
