#!/usr/bin/perl

$|=1;
#this is a CDS module to pull down media or metadata via HTTP
#arguments:
# <url>blah - download from this URL.  Standard substitutions are allowed.
# <output-directory>blah - download to this location.  Standard substitutions.
# <set-output>{media|meta|inmeta|xml}|{meta:key}... - set the given file selectors OR datastore keys with the output file path
# <output-filename>blah [OPTIONAL] - over-ride the filename portion of the URL with this.  Standard substitutions.
# <keyfile>blah [OPTIONAL] - use this file to get access keys.  NOT IMPLEMENTED YET.
# <retries>n [OPTIONAL -defaults to 10]
# <retry-delay>n [OPTIONAL -defaults to 5]

use Net::SSL;	#force SSLeay version - https://stackoverflow.com/questions/17756776/perl-lwp-ssl-verify-hostname-setting-to-0-is-not-working
use LWP::UserAgent;
use CDS::Datastore;
use File::Spec;
use HTTP::Status;

sub check_args {
my(@haystack)=@_;

foreach(@haystack){
	unless($ENV{$_}){
		print "You should specify <$_> in the route file.\n";
		return 0;
	}
}
return 1;
}

#convenience function to output any filenames
sub set_cds_file {
my($spec,$path)=@_;

unless($ENV{'cf_temp_file'}){
	print STDERR "-ERROR - cf_temp_file not set.  Unable to output filenames.\n";
	exit 1;
}
print STDERR "debug: outputting location to ".$ENV{'cf_temp_file'}."\n";
open FH,'>>:utf8',$ENV{'cf_temp_file'};
print FH "cf_".$spec."_file=$path\n";
print "cf_".$spec."_file=$path\n";
close FH;
}

#START MAIN
my $store=CDS::Datastore->new('http_download');

#first check our arguments
unless(check_args(qw/url output-directory set-output/)){
	exit 1;
}
$debug=$ENV{'debug'};

my $url=$store->substitute_string($ENV{'url'});
my $rawdir = $ENV{'output-directory'};

my $outputdir=$store->substitute_string($rawdir);
my $outputfile;

if($ENV{'output-filename'}){
	$outputfile=$store->substitute_string($ENV{'output-filename'});
} else {
	if($url=~/\/([^\/]+)\?.*$/){
		$outputfile=$1;
	} else {
		$url=~/\/([^\/]+)$/;
		$outputfile=$1;
	}
	if(length $outputfile<1){
		print "-ERROR - unable to determine output filename from $url.  Please specify a name with <output-filename> in the route.\n";
	}
}

my $outputpath=File::Spec->catdir(($outputdir,$outputfile));
print "*MESSAGE - downloading from $url to $outputpath\n";

my $attempt=0;
my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 });
my $rc;
do{
	++$attempt;
	$rc=$ua->get($url, ':content_file'=>$outputpath);
	if($rc->is_success) {
		print "INFO - Downloaded content from $url, saved to $outputpath...\n";
	} else {
		if($attempt>$retries){
			print "-ERROR - unable to download from $url after $attempt attempts: ". $rc->status_line .".  Giving up.\n";
			exit 1;
		}
		print "-WARNING - unable to download (".status_message($rc).").  Retrying in $retrydelay seconds...\n";
		sleep $retrydelay;
	}
} while(! $rc->is_success);

#ok so the downloaded content should now be saved to $outputfile.
my @locations=split /\|/,$ENV{'set-output'};
push @locations,$ENV{'set-output'} if(scalar @locations==0);
foreach(@locations){
	print "$_\n";
	if(/{([^}]+)/){
		my $temp=$1;
		my @datastore_path=split /:/,$temp;
		#we will just assume that the bit in squirlies is a valid datastore path (like meta:key or track:vide:key)
		#and let the store tell us otherwise
		my $result=$store->set(@datastore_path,$outputpath);
	} else {
		set_cds_file($_,$outputfile);
	}
}
print "+SUCCESS: Data downloaded from $url and output to $outputpath.\n";
exit 0;
