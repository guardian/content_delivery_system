#!/usr/bin/perl

my $version='$Rev: 698 $ $LastChangedDate: 2014-01-23 10:06:54 +0000 (Thu, 23 Jan 2014) $';

#This is a CDS module to request level3 to invalidate given urls.  Whenever you upload to or delete from a CDN, you should send an invalidation request.  This tells the CDN servers that the original media has changed and that they need to re-load their copy
#    <ni>        }
#    <ag>        } identifier parameters for the CDN - Network Identifier, Access Group and something else.
#    <scid>            }
#	   <keyfile> - file which contains the level3 identity key
#    <url-template>blah    } optional - generate the urls as above
#    <url-key>blah        optional - get the urls from a key or keys in the cf_meta/inmeta_file.  Data can be seperated by |
#	   <only_directories/> optional - as opposed to individually invaldating every media file referenced in an m3u8, invalidate ALL files within the relevant paths.
#												For use with apple's bizarre http streaming system.
#    <recurse-m3u/> - if a url   identifies a playlist file (.m3u,.m3u8,.m3u{x}) then add to the list any urls found within. 

#END DOC

#in order to use the API, seems that we need to set two headers
#Content-MD5 to the digest of the data
#Authorization to the string 'MPA {api key id}:{hmac}', where {hmac} has been calculated using hmac_md5($data,{secret_key})
#see Digest::HMAC

#note - level3 uses a credit scheme to limit the number of invals per month
use Data::Dumper;
use LWP::UserAgent;
use XML::Simple;
use Digest::MD5 qw/md5_hex md5_base64/;
use Digest::HMAC_SHA1 qw/hmac_sha1_hex hmac_sha1/;
use DateTime;
use DateTime::Format::HTTP;
use Encode;
use File::Basename;	#for dirname, when extracting paths
use CDS::Datastore;

local $debug=0;

#my $level3_base_url="https://mediaportal.level3.com:443/api/v1.0/invalidations";
#ANDY - update AUG 2013 - new Level3 API semantics as advised by Level3
my $level3_base_url="https://ws.level3.com";
my $level3_api_service="invalidations";
my $level3_api_version="v1.0";

my $max_reqs=50;	#maximum number of paths within one request
my $keydata;

#initialise datastore
my $store=CDS::Datastore->new('level3_invalidate_cache');

sub check_args {
	my @args=@_;

	foreach(@args){
		if(not defined $ENV{$_}){
			print "-ERROR: $_ was not specified.  Please check the route file.\n";
			exit 1;
		}
	}
}

sub have_entry {
my($needle,@haystack)=@_;

foreach(@haystack){
	return 1 if($needle eq $_);
}
return 0;
}

sub extract_paths {
my(@urls)=@_;

my @paths;
print "\nInitial path list:\n";
print "\t$_\n" foreach(@urls);

foreach(@urls){
	my $dir=dirname($_).'/*';
	push @paths,$dir if(not have_entry($dir,@paths));
}

return @paths;
}

sub read_m3u {
my($contents)=@_;
#$debug=1;

my @urls;
print "read_m3u: new file\n---------------\n" if $debug;

my @lines=split/\n/,$contents;
foreach(@lines){
	#print "$_\n"
	#if($debug);
	if(not /^#/){
		chomp;
		#fixme: there should possibly be a more scientific test than this!!
		push @urls,$_ if(/^http:/);
	}
}
print "------------------\n" if $debug;
#print Dumper(\@urls);
return @urls;
}

sub interrogate_m3u8 {
my ($url,$ua)=@_;

my @contents;
my @urls;

print "INFO: interrogating url at $url.\n";

my $response=$ua->get($url);
print $response->as_string if($debug);

if($response->is_success){
	@contents=read_m3u($response->decoded_content);
	foreach(@contents){
		#print "$_\n";
		push @urls,$_;
		my @supplementary_urls=interrogate_m3u8($_,$ua) if(/\.m3u8$/);
		push @urls,@supplementary_urls;
	}
} else {
	print "-WARNING: Unable to retrieve the url '$url'.\n";
}
#print Dumper(\@urls);
return @urls;
}

sub make_url_list {
my ($metadata)=@_;

my @urls;
my @templates=split(/\|/,$ENV{'url_template'});

my $t=localtime;

print "List of urls to check:\n"	if($debug);

my $filepath,$filebase,$fileextn;
if($ENV{'cf_media_file'}=~/^(.*)\/([^\/]+)\.([^\/\.]*)$/){
	$filepath=$1;
	$filebase=$2;
	$fileextn=$3;
} elsif($ENV{'cf_media_file'}=~/^(.*)\/([^\/]+)$/){
	$filepath=$1;
	$filebase=$2;
	$fileextn="";
}

foreach(@templates){
	my $finalstring=$store->substitute_string($_);
	push @urls,$finalstring;
	print "\t'$finalstring' from '$_'.\n" if($debug);
}
return @urls;
}

sub load_keydata {
my ($filename)=@_;

my %data;

open $fh,"<$filename" or return undef;
my @lines=<$fh>;

foreach(@lines){
	chomp;
#	print $_."\n";
	if(/^([^:]+):\s*(.*)$/){
		$data{$1}=$2;
	}
}
close $fh;

print "+MESSAGE: Successfully loaded key data from $filename.\n";

return \%data;
}

#this is a callback handler called by lwp::useragent from the "request_prepare" phase
#the Content-MD5 eader is set to the md5 checksum of what we're sending
#the Authorization header is set to the string 'MPA {api key id}:{hmac}',
#{hmac} is the sha1 HMAC of the string
#{date (utc)}{base URL}{contentType}{HTTP method}{content MD5}
#see documentation for Digest::HMAC
#base URL is the complete url with no request parts
#contentType is text/xml
#HTTP method is GET/PUT/POST/etc.
sub sign_request {
my ($request,$ua,$h)=@_;

if(not defined $keydata){
	die "Unable to find keydata.\n";
}

my $dt=DateTime->now();

$request->header('Date'=>DateTime::Format::HTTP->format_datetime($dt));
$request->header('Content-Type'=>"text/xml");
my $date=$request->header("Date");
my $baseurl=$request->uri;
$baseurl=~/^[A-Za-z]+:\/\/([^\/:]+)[:\/]/;
$request->header('Accept'=>'text/xml');
$request->header('Host'=>$1);

$baseurl=~/^[A-Za-z]+:\/\/[^\/:]+(\/.*)/;
my $requestPath=$1;

my $contentType=$request->header("Content-Type");
my $httpMethod=$request->method;
my $contentmd5;
if(length $request->content>0){
	$contentmd5=md5_base64($request->content);
} else {
	$contentmd5='';
}
my $string="$date\n$requestPath\n$contentType\n$httpMethod\n$contentmd5";

if($debug){
	print "DEBUG: sign_request:\n$string\n\n";
	#print "DEBUG: key data ".Dumper($keydata);
}

my $hmacmaker=Digest::HMAC_SHA1->new($keydata->{'Secret'});
$hmacmaker->add(encode('utf8',$string));
my $hmac=$hmacmaker->b64digest;
my $authstring=encode('utf8',"MPA ".$keydata->{'Key ID'}.":".$hmac."=");

$request->header("Authorization"=>$authstring);
$request->header("Content-MD5"=>$contentmd5) if($contentmd5 ne '');

print "DEBUG: request to be sent: ".$request->as_string."--------------\n\n" if($debug);
#don't need a return value.
}

sub send_request
{
my ($request_body,$ag,$scid,$ni,$ua)=@_;

my $response;
my $attempt=1;
do {
		my $url="$level3_base_url/$level3_api_service/$level3_api_version/$ag/$scid/$ni";
		print "INFO: Posting to $url...\n";
		print "----------------------\n$request_body\n----------------------------\n" if($debug);
		$response=$ua->post($url,Content=>$request_body);
		print $response->as_string if($debug);
		if($response->is_error){
			if($attempt>$max_retries){
				print "-ERROR: Error requesting invalidation from level3. Giving up after $attempt attempts.\n";
				return undef;
			}
			print "-ERROR: Error requesting invalidation from level3. Attempt $attempt of $max_retries.\n";
			print $response->as_string;
			sleep $retry_delay;
		}
		++$attempt;
} while($response->is_error);
return XMLin($response->content);
}


#START MAIN
check_args(qw/ni ag scid keyfile/);
my $metadata,$metafile,$meta_parent;
my @urls;

my $ni=$ENV{'ni'};
my $ag=$ENV{'ag'};
my $scid=$ENV{'scid'};

$debug=1 if(defined $ENV{'debug'});

our $retry_delay,$max_retries;
if($ENV{'retry-delay'}){
	$retry_delay=$store->substitute_string($ENV{'retry-delay'});
} else {
	$retry_delay=5;
}
if($ENV{'max-retries'}){
	$max_retries=$store->substitute_string($ENV{'max-retries'});
} else {
	$max_retries=5;
}
$keydata=load_keydata($ENV{'keyfile'});

if(defined $ENV{'url_key'}){

	my $url_value=$store->get('meta',$ENV{'url_key'});
	if(not defined $url_value){
		print "-ERROR: The key '".$ENV{'url_key'}."', which should provide a URL list, cannot be found.\n";
		exit 1;
	}
	@urls=split(/\|/,$url_value);
} elsif(defined $ENV{'url_template'}){
	@urls=make_url_list($metadata);
} else {
	print "-ERROR: Neither <url_key> nor <url_template> was specified.  You must use one to identify which urls to invalidate.\n";
	exit 1;
}

#start up the useragent
my $ua=LWP::UserAgent->new;
#FIXME: should be able to over-ride
$ua->timeout(10);
$ua->env_proxy;
$ua->add_handler(request_prepare=>\&sign_request);

if(defined $ENV{'recurse_m3u'}){
	foreach(@urls){
		my @extra_urls=interrogate_m3u8($_,$ua) if($_=~/\.m3u8$/);
		push @urls,@extra_urls;
	}
}

@urls=extract_paths(@urls) if(defined $ENV{'only_directories'});

if(scalar @urls <1){
	print "-ERROR: no urls in the list to invalidate.\n";
	exit 1;
}

print "INFO: Requesting invalidation on these urls:\n";
print "\t$_\n" foreach(@urls);

#form the invalidation request
my $request_body="<paths>\n";
my $valid=0;
my $n=0;
#the urls should be of the form http://{ni}/path/to/file.ext, but we just want the path bit
foreach(@urls){
	/([\w\d]+):\/\/([^\/]+)(.*)$/;
	++$n;
	my $proto=$1;
	my $server=$2;
	my $path=$3;
	if($server eq $ni){
		$request_body=$request_body."\t<path>$path</path>\n";
		$valid=1;
	} else {
		print "WARNING: the url $_ does not appear to belong to the CDN $ni.  Not requesting inval.\n";
	}
	if($n>$max_reqs){
		$request_body=$request_body."</paths>\n";
	#	send_request($request_body,$ag,$scid,$ni,$ua);
		$request_body="<paths>\n";
		$n=0;
	}
}
if(not $valid){
	print "-ERROR: No URLs left to invalidate!\n";
	exit 1;
}
$request_body=$request_body."</paths>\n";

my $data=send_request($request_body,$ag,$scid,$ni,$ua);
if(defined $data){
	print Dumper($data);
	print "+SUCCESS: Invalidation requested for given urls.\n";
} else {
	print "-ERROR: Unable to request invalidation.\n";
}
