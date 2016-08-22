#!/usr/bin/perl
$|=1;

my $version='$Rev: 690 $ $LastChangedDate: 2014-01-22 23:24:31 +0000 (Wed, 22 Jan 2014) $';

# ftp_pull.pl
#
# A script to poll an FTP server and trigger the route (via the commandline) when file(s) arrive(s). 
#
# <specific-file>filename - ONLY attempt to download this file.
# <specific-url>ftp://[username:password@]server/path/to/filename - ONLY attempt to download ths specific
#			FTP URL.  username:password is optional, and is over-ridden by the <username> and <password> option.
#
# Note: there could be multiple files present in the remote folder.  The script will download them all.
# And then it will write the list of files to a temporary file which gets picked up by the cds_run script
# 
# The first line in the file must be a name value pair which indicates to the parent process, multiple files are to
# be processed.
#
# The key name is "batch" and the value is set to "true"."
#
# It is possible that there could be multiple files for each media clip. The files should all have the same basename.
# If a file does not have a correpsonding media file, the file should be moved to a bit bucket and a warning logged.
#
#

require 5.008008;
#use strict;
use warnings;

use Net::FTP;

use Data::Dumper;
use CDS::Datastore;

my $scriptName = 'ftp_pull version $Rev: 690 $';
my $store=CDS::Datastore->new($scriptName);
# this sub gets called when a file has been sucessfully downloaded.
sub processFileName;
sub outputDownloadedFileDetails;

# a name value pair gets written to a temporary file to be picked up by the parent process
# set up details via environment variables
my $host = $ENV{'host'};
my $username = $ENV{'username'}; 
my $password  = $ENV{'password'};
my $remotePath = $store->substitute_string($ENV{'remote-path'});
my $localPath = $store->substitute_string($ENV{'cache-path'});
my $tempFileName = $ENV{'cf_temp_file'};  # this is where downloaded file names are stored to return to the parent
# etc.
my $pollInterval = 5; # in seconds
my $currentFileName;
my $retryCount = 0;
my $retryLimit = 30;
my $localFileName; # local file of file currently downloaded
my $debugLevel = 5;
my @fileInfo;

our %collection;
# end config

my $targetfile;
my $targeturl;print STDOUT "\nMESSAGE:CDS Perl script $scriptName invoked\n\n";


if($ENV{'specific-file'}){
	$targetfile=$store->substitute_string($ENV{'specific-file'});
	print "INFO: SPECIFIC MODE. Only attempting to download $targetfile.\n";
}
if($ENV{'specific-url'}){
	$targeturl=$store->substitute_string($ENV{'specific-url'});
	print "INFO: SPECIFIC MODE.  Working on URL $targeturl...\n";
	if($targeturl=~/ftp:\/\/([^:]*):([^@]*)@([^\/]*)(.*)\/([^\/]+)/){
		$username=$1;
		$password=$2;
		$host=$3;
		$remotePath=$4;
		$targetfile=$5;
		
		print "INFO: SPECIFIC MODE. Attempting to download $targetfile from $remotepath on $host, user=$username, pass=$password\n";
	} elsif ($targeturl=~/ftp:\/\/([^\/]*)(.*)\/([^\/]+)/){
		$host=$1;
		$remotePath=$2;
		$targetfile=$3;
		print "INFO: SPECIFIC MODE. Attempting to download $targetfile from $remotepath on $host, user=$username, pass=$password\n";		
	}
}
if($targetfile=~/^([^\?]+)?.*$/){
	$targetfile=$1;
}

print STDOUT "MESSAGE: attemping login to ftp site \n";

# open connection & change to remote path
my $ftp = Net::FTP->new($host, Timeout => 60) or die "-FATAL: ftp cannot contact '$host': $!";  
$ftp->login($username,$password) or die "-FATAL: cannot login to $host: ",$ftp->message;

print STDOUT "MESSAGE: logged in and changing to remote directory\n";

$ftp->cwd($remotePath) if(defined $remotePath and (length $remotePath)>0);
$ftp->binary;

# get directory listing

#  To get file and sub-directory information, simply loop from 0 to ftp.NumFilesAndDirs - 1
my @files;

if($targetfile){
	@files=($targetfile);
} else {
	@files=$ftp->ls();
}


while (scalar @files == 0) {
	print "WARNING: ";
    print $ftp->message . "\n";
	# TO DO: if no files are present keep trying
    
    sleep ($pollInterval);

	@files = $ftp->ls();
	
	$retryCount++;
	
	if ($retryCount == $retryLimit)
	{
		print STDERR "-FATAL: no files are available for download; exit $scriptName\n";
		exit 1;
	}    
}

#bundle the filenames into the global %collection hash
print STDOUT "MESSAGE: bundling files\n";
foreach(@files){
	processFileName($_);
}

if($ENV{'debug'}){
	print STDOUT "DEBUG: bundled file list:\n";
	local $Data::Dumper::Pad="\t";
	print Dumper(\%collection);
}

#now build a download list
my @download_list;

foreach(keys %collection){
	my $take=1;
	my $current_ref=\%{$collection{$_}};
	#print Dumper($current_ref) if($ENV{'debug'});
	foreach(@required_files){
		unless(file_from_bundle($current_ref,$_)){
			print "Not downloading the bundle:\n";
			print Dumper($current_ref);
			print " as the $_ file is missing, and the route file says it's required\n";
			$take=0;
			last;
		}
	}
	$collection{$_}{'take'}=$take;
	next unless($take);
	
	foreach(keys %{$current_ref}){
		next if($_ eq 'take');
		my $filename=$current_ref->{$_};
		print "DEBUG: adding $_ file $filename to the download list\n" if($ENV{'debug'});
		push @download_list,$filename;
	}
}

print "INFO: Download list:\n";
print Dumper(\@download_list);
if(scalar @download_list == 0){
	print STDERR "-FATAL: No new files seen on $host.  Exiting.\n";
	unlink($newFileListName);
	exit 1;
}

my $successfulDownloadCount = 0;

foreach(@download_list){
	chdir $localPath;
	print STDOUT "MESSAGE: file $_ has appeared on remote site.  Downloading....\n";
	$retryCount=0;
	do {
		$localFileName=$ftp->get($_);
		unless($localFileName){
			++$retryCount;
			print "FTP error downloading '$_' on attempt $retryCount: ".$ftp->message."\n";
		}
	} while(not defined $localFileName and $retryCount<$retryLimit);
	
	#no point in continuing if the download failed.  Move on to the next file.
	next if($retryCount>=$retryLimit);
	
	++$successfulDownloadCount;
	$ftp->delete($_) if(not defined $ENV{'keep-original'});
	#processFileName("$localPath/$localFileName");
	print STDOUT "MESSAGE: Download complete.\n";
	#+$successfulDownloadCount;
}

# close connection
$ftp->quit;

# success or fail?

#
# The one thing that the script currently does not do is handle if the number of files in the remote folder
# matches the number of files successfully downloaded.
#
if ($successfulDownloadCount == 0)
{
	#print STDERR "-FATAL: in script $, ftp download failed\n";
	print STDERR "-FATAL: No files were downloaded.  This is probably because there were no files there.\n";
	exit 1;
}
else
{
	print STDOUT "+SUCCESS: $scriptName: Download successful!\n";
	
	outputDownloadedFileDetails();
	exit 0;
}


#
# Based on the file type add name value pair to the temporary file.
#
# The temporary file name is held in an environement variable.
#
sub processFileNameOld()
{
	my $fileName = shift(@_);	

	# check the file exists...

	my $keyName;
			
	$fileName =~ /\.([^\.]*)$/;
	my $fileNameExtension = $1;
	
	if($fileNameExtension eq "meta")
	{
		$keyName = "cf_meta_file";
	}
	elsif($fileNameExtension eq "inmeta")
	{
		$keyName = "cf_inmeta_file";
	}
	elsif($fileNameExtension eq "xml")
	{
		$keyName = "cf_xml_file";
	}
	else
	{
		$keyName = "cf_media_file";
	}

	# open file to append a name value pair to it.
	if($successfulDownloadCount > 1)
	{
		my $fileOpenStatus = open CDS_TMP, ">>", $tempFileName;
	}
	else # open file and overwrite the contents
	{
		my $fileOpenStatus = open CDS_TMP, ">", $tempFileName;			
	}

	print CDS_TMP "$keyName=$fileName\n";
	close CDS_TMP;		
}

sub processFileName()
{
	my $fileName = shift(@_);	
	my $keyName;
	my $baseName = $fileName;
	my $fileNameExtension;

	return if not defined $fileName;
			
	$baseName =~ s/\.([^\.]*)$//;
	$fileNameExtension = $1;

	if(not defined $fileNameExtension){
		$keyName = "cf_media_file";
	}	
	elsif(lc $fileNameExtension eq "meta")
	{
		$keyName = "cf_meta_file";
	}
	elsif(lc $fileNameExtension eq "inmeta")
	{
		$keyName = "cf_inmeta_file";
	}
	elsif(lc $fileNameExtension eq "xml" or lc $fileNameExtension eq "txt")
	{
		$keyName = "cf_xml_file";
	}
	else
	{
		$keyName = "cf_media_file";
	}	
	
	$collection{$baseName}{$keyName} = "$fileName";	 
}


#
#
#
sub outputDownloadedFileDetails()
{
	my @keyIndices;
	my $baseName;

	open CDS_TMP, ">", $tempFileName or die "-FATAL: script $scriptName cannot open $tempFileName: $!\n";

	print Dumper(\%collection)."\n" if $debugLevel > 0;

	if(scalar keys(%collection) > 1)
	{
		# there is data for groups of related files to write to temp file
		# this name value pair tells cds_run to handle this case 
		print CDS_TMP "batch=true\n";

		my @list;
		foreach(keys %collection){
			my $basename=$_;
			foreach(keys %{$collection{$_}}){
				print CDS_TMP $localPath . "/" . $collection{$basename}{$_} . "," if(not $collection{$basename}{$_}=~/^$/);
			}
			print CDS_TMP "\n";
		}
	}
	else
	{
		# we have a single record of file names,  write a name value pair for each hash in the record.
		
#			ftp_pull: $VAR1 = {
#	ftp_pull:           '130111Ticket_7115695' => {
#	ftp_pull:                                       'cf_media_file' => '130111Ticket_7115695.mov'
#	ftp_pull:                                     }
#	ftp_pull:         };

		foreach(keys %collection){
			foreach my $key (keys %{$collection{$_}}){
				my $value=$collection{$_}{$key};
				print CDS_TMP "$key=$value\n";
				print "$key=$value\n";
			}
		}
		
		# we have a hash of hashes that contains a single record
#		@keyIndices = keys %collection;
		
		
#		print "DEBUG: key indices @keyIndices\n" if $debugLevel > 0;
		
#		my %hashRecord =  $collection{$keyIndices[0]}; # get the record at index 0
					
 #   	for my $key ( keys %hashRecord )
#    	{
 #      	my $value = $hashRecord{$key};
#	 		print CDS_TMP "$key=$value\n";			
#	     }	    
	}

	close CDS_TMP;
}
