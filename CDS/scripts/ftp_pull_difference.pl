#!/usr/bin/perl
$|=1;

my $version='';

# This CDS method polls an FTP server, downloading all files that have appeared since the previous run. 
# The previous contents of the FTP server is stored in a text file, specified in the old-file-list option.
#
# Note: there could be multiple files present in the remote folder.  The script will download them all.
# And then it will write the list of files to a temporary file which gets picked up by the cds_run script
# 
# It automatically detects bundles of files by looking for a common basename (e.g., myvideo.mp4/myvideo.xml/myvideo.inmeta).
# You can adjust how basenames are matched by using the filename-skip-portions option (e.g., 1234-myvideo.mp4/5678-myvideo.xml etc.)
#
#Arguments:
# <host>host.mydomain.com		- log into this FTP server
# <username>blah			- log in with this username
# <password>blah			- log in with this password
# <remote-path>/path/to/files		- files are located in this path
# <cache-path>/path/to/download		- download files to this local path.  CDS begins processing on them from here, and can then move them elsewhere
# <old-file-list>/path/to/oldlist	- store the current contents of the FTP server here and check this to see if a file has been 'seen'
# <new-file-list>/path/to/lockfile	- create this file as a lockfile while we are running.  If this file exists when the method starts up, it aborts, to avoid interfering with an on-going download.
# <keep-original/>	[OPTIONAL] 	- don't delete the files after they have been successfully downloaded.  Since ftp_pull_difference is most useful for servers where you don't have write access, this argument is less useful than on others, but can be useful just to make the point in the routefile
#
# <required-files>{media|meta|inmeta|xml} [OPTIONAL] - specify a list of files which must be present in order to trigger a download.  ftp_pull_difference detects 'bundles' of files with common basenames.  If you specify this option, then if the given file types are not present in the bundle, then NONE of the files will be downloaded.  Useful if e.g. metadata tends to arrive on the server later than media, but you asset management system requires metadata and media at the same time.  You would specify media|xml for this option, then only when BOTH media and XML are available for download would a package be downloaded
# <filename-portion-delimiter>	[OPTIONAL] - if skipping portions of a filename for matching, use the specified character (or regex) to separate out the portions of the filename
# <filename-skip-portions>n [OPTIONAL] - specify this many portions of the filename to skip before attempting a filename match.  Some services don't provide files with common basenames, using identifiers or timestamps in the fieldname.  So if you have 1234-mymedia.mp4 and 5678-mymedia.xml then they would not be detected as part of the same bundle.  In this case, you would specify a filename-portion-delimiter of '-' (a single hyphen) and filename-skip-portions of 1 (i.e., skip 1 portion when splitting the filename on '-' characters).
#
# <attempts>n [OPTIONAL] - re-attempt file downloads this many times. Defaults to 2; FTP connection is re-initialised before each attempt.
# <limit>n [OPTIONAL] - limit the number of bundles returned to this number
#END DOC

require 5.008008;
use strict;
use warnings;

use Net::FTP;
use File::Path qw/make_path/;
use Data::Dumper;
use CDS::Datastore;

my $scriptName = "ftp_pull_difference";
my $store=CDS::Datastore->new($scriptName);
# this sub gets called when a file has been sucessfully downloaded.
sub processFileName;
sub outputDownloadedFileDetails;

# a name value pair gets written to a temporary file to be picked up by the parent process
# set up details via environment variables
our $host = $ENV{'host'};
our $username = $ENV{'username'}; 
our $password  = $ENV{'password'};
our $remotePath = $store->substitute_string($ENV{'remote-path'});
our $localPath = $store->substitute_string($ENV{'cache-path'});
our $tempFileName = $ENV{'cf_temp_file'};  # this is where downloaded file names are stored to return to the parent
# etc.
our $oldFileListName = $store->substitute_string($ENV{'old-file-list'});
our $max_attempts=2;
if($ENV{'attempts'}){
	$max_attempts = $store->substitute_string($ENV{'attempts'});
}

our $limit=999999999;
if($ENV{'limit'}){
	$limit = $store->substitute_string($ENV{'limit'});
}

#newFileList is not actually used to store filenames, but to act as a guard for being called more
#than once and hence tripping over ourselves.
my $newFileListName = $store->substitute_string($ENV{'new-file-list'});
my $pollInterval = 5; # in seconds
my $currentFileName;
my $retryCount = 0;
my $retryLimit = 30;
my $localFileName; # local file of file currently downloaded
my $debugLevel = 10;
my @fileInfo;

our @ignored_media_xtns;

#required-files means that we need the {media|meta|inmeta|xml} files to be present in a bundle before
#we download.
my @required_files;
if($ENV{'required-files'}){
	@required_files=split /\|/,$ENV{'required-files'};
}

my %collection;
# end config

#this should get called whenever the program terminates (through exit, die, croak etc. - but NOT through signal-killing.
END {
if(defined $newFileListName){
	print STDERR "MESSAGE: cleaning up and removing lockfile $newFileListName\n";
	close NEWFILELIST;
	unlink($newFileListName);
} else {
	print STDERR "MESSAGE: no lockfile existing, exiting.\n";
}
}

sub signal_terminate {
my($sig)=@_;
if(defined $newFileListName){
	print STDERR "MESSAGE: Caught SIG$sig.  Cleaning up and removing lockfile $newFileListName\n";
	close NEWFILELIST;
	unlink($newFileListName);
} else {
	print STDERR "MESSAGE: no lockfile existing, exiting.\n";
}
}

#this is called at the start of the main block to "plug in" the signal handler.
sub setupSignals {
$SIG{'INT'}=\&signal_terminate;
$SIG{'QUIT'}=\&signal_terminate;
$SIG{'HUP'}=\&signal_terminate;
$SIG{'PIPE'}=\&signal_terminate;
$SIG{'TERM'}=\&signal_terminate;
$SIG{'USR1'}='IGNORE';
$SIG{'USR2'}='IGNORE';
$SIG{'SEGV'}=\&signal_terminate;
}

sub is_in_list
{
my($needle,$haystack)=@_;

foreach(@$haystack){
#	print STDERR "\tDEBUG: comparing '$needle' to '$_'\n";
	if($needle eq $_){
#		print STDERR "DEBUG: FOUND IT\n";
		return 1;
	}
}
return 0;
}

#this sub adds the given file to the FIRST array specified by reference, IF it does not already
#exist within the SECOND array specified by value.  See line 109.
sub add_file_to_list {
	my($filename,$download_list,@oldfiles)=@_;
	
	foreach(@oldfiles){
		chomp;
		#print "add_file_to_list: testing $_ against $filename.\n";
		return 0 if($filename eq $_);
	}
	
	push @$download_list,$filename;
	return 1;
}

sub file_from_bundle
{
my($bundleref,$filetype)=@_;

return $bundleref->{"cf_".$filetype."_file"};
}

#set up a new connection and log into the server
sub initFTP
{
print STDOUT "MESSAGE: attemping login to ftp site \n";

# open connection & change to remote path
my $ftp = Net::FTP->new($host, Timeout => 60, BlockSize=>8192) or die "-FATAL: ftp cannot contact $host: $!";  
$ftp->login($username,$password) or die "-FATAL: cannot login to $host: ",$ftp->message;

print STDOUT "MESSAGE: logged in and changing to remote directory '$remotePath'\n";

if(defined $remotePath and (length $remotePath)>0){
	my $rv=$ftp->cwd($remotePath);
	print "WARNING: Unable to change to '$remotePath'\n" unless($rv);
}
$ftp->binary;

return $ftp;
}

## START MAIN

print STDOUT "\nMESSAGE:CDS Perl script $scriptName invoked\n";

setupSignals;

if(not defined $newFileListName or not defined $oldFileListName){
	print STDERR "-FATAL: no location specified for the file list caches\n";
	exit 2;
}

if( -e $newFileListName){
	print STDERR "-FATAL: ftp_pull_reuters appears to already be running.  If it is not, the remove the file $newFileListName and re-run.\n";
	exit 3;
}

if($ENV{'ignore-media-extensions'}){
	@ignored_media_xtns=split /\|/,$ENV{'ignore-media-extensions'};
}

open OLDFILELIST,"<$oldFileListName" or die "-FATAL Could not open file list cache $oldFileListName to read\n";
open NEWFILELIST,">$newFileListName" or die "-FATAL Could not open file list cache $newFileListName to write\n";

my @oldfiles=<OLDFILELIST>;

close OLDFILELIST;
chomp $_ foreach(@oldfiles);

my $ftp=initFTP;

# get directory listing

#  To get file and sub-directory information, simply loop from 0 to ftp.NumFilesAndDirs - 1
my @files=$ftp->ls();

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
		unlink($newFileListName);
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

#now build a download list, if the file has not been seen before then get it.
my @download_list;
my @ignore_list;

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
	
	#we will download the whole bundle, unless EVERY file is in the old list.
	$take=0;
	foreach(keys %{$current_ref}){
		next if($_ eq 'take');
		my $filename=$current_ref->{$_};
		$take=1 unless(is_in_list($filename,\@oldfiles));
	}
	$collection{$_}{'take'}=$take;
	unless($take){
		print "Bundle for $_ has already had all files downloaded.\n";
		next;
	}
	
	foreach(keys %{$current_ref}){
		next if($_ eq 'take');
		my $filename=$current_ref->{$_};
				push @ignore_list,$filename if($_ eq 'ignore_file');
		print "DEBUG: adding $_ file $filename to the download list\n" if($ENV{'debug'});
		push @download_list,$filename;
	}
	#if we have a limit to the number of files, then ensure that we don't go over it.
	last if(scalar @download_list>=$limit);
}

print "INFO: Ignore list:\n";
print Dumper(\@ignore_list);

print "INFO: Download list:\n";
print Dumper(\@download_list);
if(scalar @download_list == 0){
	print STDERR "-FATAL: No new files seen on $host.  Exiting.\n";
	unlink($newFileListName);
	exit 1;
}

open OLDFILELIST,">>$oldFileListName" or die "-FATAL Could not open file list cache $oldFileListName to write\n";
print OLDFILELIST "$_\n" foreach(@ignore_list);

my $successfulDownloadCount = 0;

if(not -d $localPath){
    print STDOUT "WARNING: output path $localPath does not exist. Trying to create...\n";
	my $dirs_created = make_path($localPath);
	if($dirs_created==0){
		print STDERR "ERROR: Unable to create $localPath.";
		exit(1);
	}
}

foreach(@download_list){
	chdir $localPath;
	print STDOUT "MESSAGE: file $_ has appeared on remote site.  Downloading....\n";
	my $retry=0;
	my $attempts=0;
	do {
		$retry=0;
		$localFileName=$ftp->get($_);
		if($localFileName){
			print OLDFILELIST $_ . "\n";
			$ftp->delete($_) if(not defined $ENV{'keep-original'});
			#This has already been done, above
			#processFileName($localFileName);
			print STDOUT "MESSAGE: Download complete.\n";
			++$successfulDownloadCount;
		} else {
			++$attempts;
			if($attempts<$max_attempts){
				print STDOUT "-WARNING: FTP connection dropped (".$ftp->message."). Retrying (attempt $attempts...)\n";
				#re-initialise FTP connection
				$ftp=initFTP;
				$retry=1;
			} else {
				print STDOUT "-WARNING: Unable to download file $_: ".$ftp->message.".  This will be re-tried the next time this route is run\n";
				$retry=0;
			}
		}
	} while($retry);
}

close OLDFILELIST;
# close connection
$ftp->quit;

# success or fail?

#
# The one thing that the script currently does not do is handle if the number of files in the remote folder
# matches the number of files successfully downloaded.
#
if ($successfulDownloadCount == 0)
{
	print STDERR "-FATAL: in script $, ftp download failed\n";
	unlink($newFileListName);
	exit 1;
}
else
{
	print STDOUT "+SUCCESS: $scriptName: Download successful!\n";
	
	outputDownloadedFileDetails();
	unlink($newFileListName);
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
	
	my $delimiter=$ENV{'filename-portion-delimiter'};
	$delimiter='_' unless($delimiter);
	
	my $skip_n_portions=$ENV{'filename-skip-portions'};
	if($skip_n_portions){
		if($ENV{'debug'}){
			print "INFO: attempting to skip $skip_n_portions portions of the filename $baseName with delimiter $delimiter\n";
		}
		
		my @portions=split /\Q$delimiter/,$baseName;
		if($skip_n_portions > scalar @portions){
			print STDERR "Warning: Cannot skip $skip_n_portions of filename $baseName with delimiter $delimiter because there are only ".scalar @portions." seperate portions\n";
			local $Data::Dumper::Pad="\t";
			print Dumper(\@portions);
		} else {
			$baseName="";
			for(my $n=$skip_n_portions;$n<scalar @portions;++$n){
				$baseName=$baseName.$portions[$n];
				$baseName=$baseName.$delimiter unless($n==scalar @portions - 1);
			}
			#$baseName=~s/\Q$delimiter$//;
			if($ENV{'debug'}){
				print "DEBUG: broken-down filename:\n";
				local $Data::Dumper::Pad="\t";
				print Dumper(\@portions);
				print "DEBUG: final filename: $baseName\n";
			}
		}
	}
	
	$baseName =~ s/\.([^\.]*)$//;
	$fileNameExtension = lc $1;
	
	if($fileNameExtension eq "meta")
	{
		$keyName = "cf_meta_file";
	}
	elsif($fileNameExtension eq "inmeta")
	{
		$keyName = "cf_inmeta_file";
	}
	elsif($fileNameExtension eq "xml" or $fileNameExtension eq "txt")
	{
		$keyName = "cf_xml_file";
	}
	else
	{
		if(is_in_list($fileNameExtension,\@ignored_media_xtns)){
			$keyName="ignore_file";
		} else {
			$keyName = "cf_media_file";
		}
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

	print Dumper(\%collection)."\n" if $ENV{'debug'};

#	if(keys(%collection) > 1)
#	{
		# there is data for groups of related files to write to temp file
		# this name value pair tells cds_run to handle this case 
		print CDS_TMP "batch=true\n";

		my @list;
		foreach(keys %collection){
			next unless($collection{$_}{'take'});
			
			my $basename=$_;
			foreach(keys %{$collection{$_}}){
				next if($_ eq 'take');
				print CDS_TMP $localPath . "/" . $collection{$basename}{$_} . ",";
			}
			print CDS_TMP "\n";
		}
#	}
#	else
#	{
		# we have a single record of file names,  write a name value pair for each hash in the record.
		
		# we have a hash of hashes that contains a single record
#		@keyIndices = keys %collection;
		
		
#		print "DEBUG: key indices @keyIndices\n" if $debugLevel > 0;
		
#		my %hashRecord =  $collection{$keyIndices[0]}; # get the record at index 0
					
#	   	for my $key ( keys %hashRecord )
 #    	{
#         	my $value = $hashRecord{$key};
#	 		print CDS_TMP "$key=$value\n";			
#	     }	    
#	}

	close CDS_TMP;
}
