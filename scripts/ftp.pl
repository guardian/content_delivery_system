#!/usr/bin/perl
$|=1;

$longversion='ftp.pl from master revision $Rev: 651 $ $LastChangedDate: 2014-01-01 16:57:45 +0000 (Wed, 01 Jan 2014) $';
$version='ftp.pl $Rev: 651 $';

#This CDS module uploads a given file, or set of files, via FTP.
#If an M3U8 HLS file list is specified, it can be parsed and all referenced files are uploaded as well
#Arguments:
#  <take-files>{media|meta|inmeta|xml} - upload the given files
#  <extra_files>/path/to/file1|/path/to/file2|{meta:anotherfilepath} - also upload files in this list.
#      Datastore substitutions (including time/date) are allowed.
# <hostname>blah - upload to this FTP server
# <username>blah - use this username to log in. Specify "anonymous" if using anonymous FTP
# <password>blah - use this password to log in.
# <remote-path>/path/to/upload/files - change to this directory on the remote server before uploading.
#      Datastore substitutions are allowed.
# <throttle>n - limit upload speed to this number of MBits/sec
# <recurse_m3u/> - if ANY requested file ends in .m3u8, then parse it as an m3u8 and upload anything referenced.
#		m3u8's are parsed recursively, i.e. if the first one references a second, that is passed as well, etc.
# <basepath>/path/to/m3u/repository - you SHOULD SET THIS IF USING RECURSE_M3U8. Assume that all files
#       referenced by the m3u8 can be found locally at this path.
# <max-retries>n - retry FTP operation at most this many times
# <retry-delay>n - wait this many seconds before retrying
# <passive/> - use "passive FTP" mode.
# <debug/> - output loads of debug information, including what's being uploaded from and to where.
#END DOC

use Data::Dumper;
use Net::FTP;
use Net::FTP::Throttle;
use CDS::Datastore;

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

sub setup_ftp {
my($hostname,$username,$password,$maxit,$delay,$remotepath,$passive,$maxbandwidth)=@_;

my $success,$tries;
while(not $success){
	++$tries;
	if($tries>$maxit){
		print "-FATAL: Unable to get an FTP session after $tries attempts.  Giving up.\n";
		exit 1;
	}
	
	print "INFO: Connecting to $hostname...\n";
	if($maxbandwidth){
		$ftp=Net::FTP::Throttle->new($hostname,Passive=>$passive_ftp,MegabitsPerSecond=>$maxbandwidth,Debug => $ENV{'debug'});
	} else {
		$ftp=Net::FTP->new($hostname,Passive=>$passive_ftp,Debug => $debug);
	}

	unless($ftp){
		$success=0;
		print "-WARNING: Unable to connect to $hostname: $@ (attempt $tries/$maxit)\n";
		sleep($delay);
		next;	#re-loop
	}
	
	print "INFO: Logging in as $username\n";
	
	$success=$ftp->login($username,$password);
	unless($success){
		print "-WARNING: Unable to log in to $hostname as $username: ".$ftp->message." (attempt $tries/$maxit)\n";
		sleep($delay);
		next;
	}
	
	print "INFO: Uploading to $remotepath...\n";
	if(defined $remotepath and (length $remotepath)>0){
	#the second arg asks to recursively make the directory
	unless($ftp->cwd($remotepath)){
		$ftp->mkdir($remotepath,1);
		$success=$ftp->cwd($remotepath);
		unless($success){
			print "-WARNING: Unable to change to directory $remotepath on remote server.\n";
			sleep($delay);
			next;
		}
	}
	}
	$ftp->binary;
} 
return $ftp;
}

#START MAIN

if($ENV{'debug'}){
	print "$longversion\n";
} else {
	print "$version\n";
}

# A script to upload the given files to a given location, via FTP. 

# SETTINGS
if($ENV{'max-retries'} ne "")
{
	$maxit= $ENV{'max-retries'};
}
else
{
	$maxit=5;
}

if($ENV{'passive'} ne "")
{
	$passive_ftp = $ENV{'passive'};
}
else
{
	$passive_ftp = 1;
}

if($ENV{'debug'} ne "")
{
	$debug= $ENV{'debug'};
}
else
{
	$debug=0;
}

$script_name = "ftp.pl";
$hostname = $ENV{'hostname'};
$username = $ENV{'username'};
$password = $ENV{'password'};
$remotepath = $ENV{'remote-path'};	#substitution is carried out below.
$maxbandwidth = $ENV{'throttle'};
#END  SETTINGS

my $store=CDS::Datastore->new($script_name);

my @filesToFTP;
my $basepath;

# check the environment variable has a value and that the file does exist
# for the 4 different possible files to upload

my $filename = $ENV{'cf_media_file'};
print "cf_media_file=$filename\n" if($debug);
if ( $filename ne '' && -e "$filename")
{
	push (@filesToFTP, $filename);	
}

$filename = $ENV{'cf_meta_file'};
print "cf_meta_file=$filename\n" if($debug);
if ( $filename ne '' && -e "$filename")
{
	push (@filesToFTP, $filename);	
}

$filename = $ENV{'cf_inmeta_file'};
print "cf_inmeta_file=$filename\n" if($debug);
if ( $filename ne '' && -e "$filename")
{
	push (@filesToFTP, $filename);	
}

$filename = $ENV{'cf_xml_file'};
print "cf_xml_file=$filename\n" if($debug);
if ( $filename ne '' && -e "$filename")
{
	push (@filesToFTP, $filename);	
}

foreach(split /\|/,$ENV{'extra_files'}){
	print "extra file=$_\n" if($debug);
	push @filesToFTP,$store->substitute_string($_);
}

if(defined $ENV{'basepath'}){
	$basepath=$store->substitute_string($ENV{'basepath'});
	unless(-d $ENV{'basepath'}){
		print "-WARNING: Unable to find the path '".$basepath."' specified as <basepath> in the route file.\n";
	}
}

my $delay;
if($ENV{'retry-delay'}){
	$delay=$ENV{'retry-delay'};
} else {
	$delay=5;
}

if(defined $ENV{'recurse_m3u'}){
	if(not defined $ENV{'basepath'}){
		print "-WARNING: <recurse-m3u/> specified in route file but <basepath> has not been set.  Assuming that basepath is '".$ENV{'PWD'}."'.  Expect problems.\n";
		$basepath=$ENV{'PWD'};
	}
	foreach(@filesToFTP){
		my @extra_files=interrogate_m3u8($_,$basepath) if($_=~/\.m3u8$/);
		push @filesToFTP,@extra_files;
	}
}
$numFiles = @filesToFTP;


if($numFiles == 0)
{
	print STDERR "FATAL: no files specifed to ftp\n";
	exit 1;
}

print "MESSAGE: $script_name: start uploading content\n";
print "MESSAGE: files to upload are: '@filesToFTP'\n";

my $ftp,$tries;

#while(not defined $ftp){
#	++$tries;
#	if($maxbandwidth eq "true"){
#		$ftp=Net::FTP::Throttle->new($hostname,Passive=>$passive_ftp,MegabitsPerSecond=>$maxbandwidth,Debug => $debug);
#	} else {
#		$ftp=Net::FTP->new($hostname,Passive=>$passive_ftp,Debug => $debug);
#	}
#	unless($ftp){
#		if($tries>$maxit){
#			print "FATAL: Unable to connect to $hostname after $maxit attempts: $@. Giving up.\n";
#			exit 1;
#		}
#		print "WARNING: Cannot connect to $hostname: $@ (attempt $tries/$maxit)\n";
#		sleep($delay);
#	}
#}

if($ENV{'cf_media_file'}=~/^(.*)\/([^\/]+)\.([^\/\.]*)$/){
	$filepath=$1;
	$filebase=$2;
	$fileextn=$3;
} elsif($ENV{'cf_media_file'}=~/^(.*)\/([^\/]+)$/){
	$filepath=$1;
	$filebase=$2;
	$fileextn='';
}

my $finalstring=$store->substitute_string($remotepath);

#print "Logging in as $username...\n";
#$tries=1;
#while(not $ftp->login($username,$password)){
#	++$tries;
#	print "WARNING: Cannot login to $hostname: ".$ftp->message." (attempt $tries/$maxit)\n";
#	if($tries>$maxit){
#		print "FATAL: Unable to log in after $tries attempts.  Giving up.\n";
#		exit 1;
#	}
#	sleep($delay);
#}

#print "INFO: Uploading to path $finalstring\n";

#if(defined $remotepath and (length $remotepath)>0){
#	#the second arg asks to recursively make the directory
#	unless($ftp->cwd($finalstring)){
#		$ftp->mkdir($finalstring,1);
#		if(not $ftp->cwd($finalstring)){
#			print "-ERROR: Unable to change to directory $finalstring on remote server.\n";
#			exit 1;
#		}
#	}
#}
#$ftp->binary;

$ftp=setup_ftp($hostname,$username,$password,$maxit,$delay,$finalstring,$passive_ftp,$maxbandwidth);
my $nFailed=0;

for ( my $i = 0; $i < $numFiles; $i++)
{
	my $tries=1;
	if(-f $filesToFTP[$i]){
        my $result=0;
		while(! $result){
			die "FATAL: $script_name: Couldn't upload $filesToFTP[$i] after $tries attempts, giving up\n" if($tries>$maxit);
            eval {
                $result=$ftp->put($filesToFTP[$i])
            };
            last if($result);
            $_=$ftp->message;
            chomp;
            print STDERR "WARNING: $script_name: $_ retrying (attempt $tries)...\n";
            sleep($delay);
            #re-initialise FTP connection
            eval {
                $ftp->quit;
            };
			$ftp=setup_ftp($hostname,$username,$password,$maxit,$delay,$finalstring,$passive_ftp,$maxbandwidth);
			++$tries;
		}
	} else {
		++$nFailed;
		print "-WARNING: Unable to find file to FTP '".$filesToFTP[$i]."'\n";
	}
}

$ftp->quit;

if($nFailed>0){
	print STDOUT "+WARNING: $nFailed/$numFiles files were not found and failed to upload.\n";
} else {
	print STDOUT "SUCCESS: $script_name: Upload successful!\n";
}
exit 0;
