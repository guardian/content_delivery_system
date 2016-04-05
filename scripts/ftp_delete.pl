#!/usr/bin/perl

$|=1;

my $version='$Rev: 472 $ $LastChangedDate: 2013-08-14 14:25:30 +0100 (Wed, 14 Aug 2013) $';

# This script attempts to delete the given file from the ftp server
# <specific-file>filename - ONLY attempt to download this file.
# <specific-url>ftp://[username:password@]server/path/to/filename - ONLY attempt to download ths specific
#			FTP URL.  username:password is optional, and is over-ridden by the <username> and <password> option.
#

require 5.008008;
#use strict;
use warnings;

use Net::FTP;

use Data::Dumper;
use CDS::Datastore;

my $scriptName = 'ftp_delete $Rev: 472 $ $LastChangedDate: 2013-08-14 14:25:30 +0100 (Wed, 14 Aug 2013) $';
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
my $debugLevel = 0;
my @fileInfo;

my %collection;
# end config

my $targetfile;
my $targeturl;

sub connect_to_ftp {
my($host,$username,$password,$remotePath)=@_;

# open connection & change to remote path
my $ftp = Net::FTP->new($host, Timeout => 60) or die "-FATAL: ftp cannot contact $host: $!";  
$ftp->login($username,$password) or die "-FATAL: cannot login to $host: ",$ftp->message;

print STDOUT "MESSAGE: logged in and changing to remote directory\n";

$ftp->cwd($remotePath) if(defined $remotePath and (length $remotePath)>0);
$ftp->binary;

return $ftp;
}

print STDOUT "\nMESSAGE:CDS Perl script $scriptName invoked\n\n";


if($ENV{'specific-file'}){
	$targetfile=$store->substitute_string($ENV{'specific-file'});
	print "INFO: SPECIFIC MODE. Only attempting to delete $targetfile.\n";
}
if($ENV{'specific-url'}){
	$targeturl=$store->substitute_string($ENV{'specific-url'});
	if($targeturl=~/ftp:\/\/([^:]*):([^@]*)@([^\/]*)(.*)\/([^\/]+)/){
		$username=$1;
		$password=$2;
		$host=$3;
		$remotePath=$4;
		$targetfile=$5;
		
		print "INFO: SPECIFIC MODE. Attempting to delete $targetfile from $remotepath on $host, user=$username, pass=$password\n";
	} elsif ($targeturl=~/ftp:\/\/([^\/]*)(.*)\/([^\/]+)/){
		$host=$1;
		$remotePath=$2;
		$targetfile=$3;
		print "INFO: SPECIFIC MODE. Attempting to delete $targetfile from $remotepath on $host, user=$username, pass=$password\n";		
	}
}
if($targetfile=~/^([^\?]+)?.*$/){
	$targetfile=$1;
}


print STDOUT "MESSAGE: attemping login to ftp site \n";
my $ftp;

my $attempts=0;
my $retry=1;
while($retry){
	++$attempts;
	eval {
		$ftp=connect_to_ftp($host,$username,$password,$remotePath);
	};
	if($@){
		print "-WARNING: Error on attempt $attempts to connect to ftp: $@\n";
		sleep $pollInterval;
		last if($attempts>$retryLimit);
	} else {
		$retry=0;
		last;
	}
}

if($retry){
	print "-ERROR: Unable to connect to FTP server $host after $attempts tries.  Giving up.\n";
	exit 1;
}

unless($ftp->delete($targetfile)){
	print "-ERROR: Unable to delete file $targetfile from $remotePath on $host.\n";
}
$ftp->quit;

print "+SUCCESS: File $targetfile was deleted from $remotePath on $host.\n";
exit 0;

