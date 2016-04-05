#!/usr/bin/perl

my $version='$Rev: 1564 $ $LastChangedDate: 2016-02-15 23:16:00 +0000 (Mon, 15 Feb 2016) $';

#This is a CDS method to create pages in the Guardian's R2 CMS.
#It performs four actions:
# - builds a list of media URLs based on url-prefix and url-suffix portions, or use pre-compiled ones from datastore substitutions
# - optionally, verifies that the given media URLs exist and are not too old
# - runs the metadata through a given template, in order to generate XML for the R2 endpoints
# - sends the XML to the given endpoint, interprets the reply and sets a collection of metadata keys indicating the success/failure of the operation, page IDs, etc.
#
#    <take-files>media|{meta|inmeta} - let us know whether to use meta file or inmeta file
#    <check-exist></check>    - ensure that the given urls exist as opposed to assuming that they do
#    <check-exist-retry>n - wait n seconds between retries (default is 5s)
#   <check-exist-timeout>n - give up waiting after n seconds (default is 3600s), -1 to wait forever
#  <url-prefix>blah                } make up a list of urls like this: {url-prefix}{cf_media_file [with no extension]}{suffix}
#  <url-suffices>suffix_a|suffix_b|suffix_c|...    } Hence {url-prefix} must include http:// part and {url-suffices} need to include any file extension  <recurse-m3u></recurse>    - [v1.1 only] - if a url identifies a playlist file (.m3u,.m3u8,.m3u{x}) then add to the list any urls found within. A line is considered a url if it does NOT start with # and consists of a number of alphanumeric chars followed by :// followed by alphanumeric chars and optionally dots followed by /.  If it ends with a / it is ignored, the url must identify a media file.
#    <cms-id-key>blah - the cms id is identified by the given key within the .inmeta or .meta file (default is r2cms-id)
#    <template-file>blah - use this .tt file to merge metadata (relative to /etc/cds_backend/templates)
#    <output-url>blah - POST the form to this URL.  An error will be thrown if this does not return OK.
#    <record-url-key>blah - record the url or urls into this key in the cf_meta/inmeta_file
#	 <r2_data_prefix>blah [optional] - prefix this value to metadata keys relating to returned r2 metadata
#   <encoding_extra_args>blah [optional] - put these values into the 'encodings.extra_args' parameter in the template.   Substitutions allowed.  Used for specifying filesize="nnnn" as some formats (m3u8) are collections and don't have a specific file size.
#    <max_attempts>n [optional] - retry at most this many times.  Default: 5
#END DOC

#STILL NEED TO PUT SUBSTITUTIONS INTO OUTPUT_URL

use LWP::UserAgent;
use Data::Dumper;
use Template;
use Time::Piece;
use Date::Manip;
use File::Temp qw/tempfile/;
use File::Copy;
use Encode;
use CDS::Datastore;

my $default_template_path="/etc/cds_backend/templates";
#FIXMEFIXMEFIXME: this SHOULD be specified as config in the route file!! (i think)
#FIXED.  Array is declared here then filled at the start of main - search for $ENV{'array_keys'} to find it.
#tell the datastore that our template expects these to be expanded
my @array_keys; #=qw/keyword_IDs keyword/;
#end

sub check_args {
	my @args=@_;

	foreach(@args){
		if(not defined $ENV{$_}){
			print "-ERROR: $_ was not specified.  Please check the route file.\n";
			exit 1;
		}
	}
}

sub check_valid_age {
my($age,$max)=@_;

return 1 if($max==-1 || $age==-1);
return 1 if($age<$max);
return 0;
}

sub url_subst {
my ($substring,$key,$val)=@_;

$substring=~s/$key/$val/g;

return $substring;
}

sub make_url_list {
my ($store)=@_;

my @urls;
my @templates=split(/\|/,$store->substitute_string($ENV{'url_templates'}));

my $t=localtime;

print "List of urls to check:\n"	if($debug);

foreach(@templates){

	my $finalstring=$store->substitute_string($_);
	push @urls,{ url=>$finalstring };
	print "\t'$finalstring' from '$_'.\n" if($debug);
}
return @urls;
}

sub print_header_data
{
my($key,$value)=@_;
print "\t$key: $value\n";

}

sub dump_request {
my ($request,$ua,$h)=@_;

#test - nuke the content-length header
$request->header('Content-Length'=>undef);
$request->header('Content-Length'=>length($request->content));
print "\nDEBUG: Request about to be sent:\n".$request->as_string."\n------------------------\n";
}

#START MAIN
#ensure that required arguments are given
my $metafile,$meta_parent,$debug,$max_wait,$wait_time,$max_age,$ouput_url,$output_template;
my $meta_template,$url_key;
check_args(qw/url_templates cms_id_key template_file output_url/);

my $store=CDS::Datastore->new('r2_update_multiple');

my $output_template=$store->substitute_string($ENV{'template_file'});
my $output_url=$store->substitute_string($ENV{'output_url'});
my $cms_id_key=$ENV{'cms_id_key'};

my $max_attempts=5;
if($ENV{'max_attempts'}){
	$max_attempts=$store->substitute_string($ENV{'max_attempts'});
}

$url_key=$ENV{'record_url_key'};

if(defined $ENV{'template_path'}){
#	print STDERR "INFO: <template_path> et. al. options are deprecated and ignored as of version 2.0\n";
	$template_path=$store->substitute_string($ENV{'template_path'});
} else {
	$template_path=$default_template_path;
}

$output_template="$template_path/$output_template";

if(defined $ENV{'metadata_template_file'}){
	$meta_template=$template_path."/".$store->substitute_string($ENV{'metadata_template_file'});
} else {
	$meta_template=undef;
}

if(not defined $ENV{'cf_media_file'}){
	print "-ERROR: No media file provided, so it is not possible to make any URLs to which the media file has been uploaded.\n";
	exit 1;
}

if($ENV{'array_keys'}){
	@array_keys=split /\|/,$store->substitute_string($ENV{'array_keys'});
} else {
	@array_keys=('keyword IDs','keyword');
}

if(defined $ENV{'max_age'}){
	$max_age=$store->substitute_string($ENV{'max_age'});
} else {
	$max_age=-1;
}

if(defined $ENV{'check-exist-retry'}){
	$wait_time=$store->substitute_string($ENV{'check-exist-retry'});
} else {
	$wait_time=5;
}

if(defined $ENV{'check-exist-timeout'}){
	$max_wait=$store->substitute_string($ENV{'check-exist-timeout'});
} else {
	$max_wait=3600;
}


$debug=1 if(defined $ENV{'debug'});

if(defined $ENV{'recurse-m3u'}){
	print "WARNING: recurse-m3u option not yet implemented.\n";
}


my $cmsid=$store->get('meta',$cms_id_key);
if(not $cmsid){
	print "-ERROR: The key '$cms_id_key' which should provide the R2 id is not present in the metadata provided.\n";
	exit 1;
}

my $extra_args;
if(defined $ENV{'encodings_extra_args'}){
	$extra_args=$store->substitute_string($ENV{'encodings_extra_args'});
}

my @urls=make_url_list($store);

#initialise user agent
my $ua=LWP::UserAgent->new;
#FIXME: should be able to over-ride
$ua->timeout(10);
$ua->env_proxy;
$ua->add_handler('request_prepare'=>\&dump_request) if($debug);

#check that our given urls are present, and delay if they are
if(defined $ENV{'check_exist'}){
	print "INFO: Checking URLs exist...\n";
	foreach(@urls){
		my $url=$_->{'url'};
		print "INFO: checking $url...\n";
		my $start_time=time;
		my $age;
		my $should_loop=1;# if($response->is_error || not check_valid_age($age,$max_age));
		while($should_loop){
			sleep $wait_time;
			$response=$ua->head($url);
			if($debug){
				print "--------------\nDEBUG: Server response was:\n";
				print $response->as_string."\n" ;
				print "--------------\n";
			}
			my $waited=time-$start_time;
			if(defined($response->header("Last-Modified"))){
				my $delta=DateCalc($response->header("Last-Modified"),ParseDate('now'));
				$delta=~/(\d+):(\d+):(\d+):(\d+)$/;
				$age=$4+$3*60+$2*3600+($1*24*3600);
				print "INFO: Age of $url is $delta=$age seconds\n";
			} else {
				$age=-1;
			}
			if($response->is_error){
				print "WARNING: Unable to verify $url after $waited seconds.  Retrying...\n";
				$should_loop=1;
			} elsif(not check_valid_age($age,$max_age)){
				print "WARNING: $url is too old, waiting for status change...\n";
				$should_loop=1;
			} else {
				$should_loop=0;
			}
			if($waited>$max_wait){
				print "-ERROR: Timeout reached waiting for $url.  Giving up.\n";
				exit 1;
			}
		}
		$_->{'format'}=$response->header("Content-Type");
		$_->{'size'}=$response->header("Content-Length");
		$_->{'extra_args'}=$extra_args;
		print "INFO: $url appears to be OK.\n";
	}
} else {
	print "INFO: Not checking if these urls exist.  If this isn't the behaviour you want, set <check-exist/> in the route file.\n";
	foreach(@urls){
		$_->{'url'}=~/\.([^\.]*)$/;
		$_->{'extra_args'}=$extra_args;
		$_->{'format'}="video/$1";
		$_->{'size'}=$store->get('media','size');	#assume that the file(s) are the same as are being uploaded
	}
}

#ok, next we need to construct a hash which has metadata plus an array of encodings containing type and url
$metadata=$store->get_template_data(0,\@array_keys);
$metadata->{'encodings'}=\@urls;
$metadata->{'extra_args'}=$extra_args;

print Dumper($metadata) if($debug);

my $tt=Template->new(ABSOLUTE=>1);
$tt->process($output_template,$metadata,\$output) or die "-ERROR: problem with template: ".$tt->error;
print $output if($debug);

my $boundarytext='---------------------------34197088917664475041484543167';
#my $boundarytext='AbC01d';
$output="--$boundarytext\r\nContent-Disposition: form-data; name=\"fileData\"; filename=\"add_enc.xml\"\r\nContent-Type: text/xml\r\n\r\n$output\r\n"."--$boundarytext"."--";

my $attempt=0;
my $failed=1;
my $r2error;
my %r2data;

while($failed) {
	$failed=0;
	++$attempt;
	print "Connecting to R2, attempt $attempt/$max_attempts...\n";
	my $response=$ua->post($output_url,'Content-Type'=>"multipart/form-data; boundary=$boundarytext",Content=>$output);
	#my $response=$ua->post($output_url,fileData=>$output);
	print $response->as_string if($debug);
	
	if($response->is_error){
		$failed=1;
		print "-ERROR: Unable to send update to $output_url\n";
		last if($attempt>=$max_attempts);
		next;
	}

	my $answer=$response->decoded_content;

	print "\nGot answer '$answer'\n" if($debug);
	if($answer=~/^ERROR:(.*)$/){
		$failed=1;
		print "-ERROR: R2 said '$1'\n";
		$r2error=$1;
		last if($attempt>=$max_attempts);
		next;
	}elsif($answer=~/^OK:([^;]+);([^;]*);(.*)/){
		$r2data{'editurl'}=$1;
		$r2data{'url'}=$2;
		$r2data{'lastop'}=$3;
		$r2data{'page-status'}='PAGEOK';	#this is needed for Octopus
	} else {
		print "-ERROR: Unrecognisable answer given: $answer\n";
		$failed=1;
		last if($attempt>=$max_attempts);
		next;
	}

};

if($failed){ #if $failed is still set it means that none of the attempts succeeded.
	print "-ERROR: Unable to communicate with R2 after $max_attempts tries.";
	print "  R2 said '$r2error'" if($r2error);
	print "\n";
	exit 1;
}

if ($r2data{'editurl'}=~/content\/([0-9A-Fa-f]+)/) {
	$r2data{'id'} = $1;
} elsif($r2data{'editurl'}=~/video\/(\d+)\/edit/) {
	$r2data{'id'} = $1;
}

my $r2prefix="r2_";
if(defined $ENV{'r2_data_prefix'}){
	$r2prefix=$store->substitute_string($ENV{'r2_data_prefix'});
	$r2prefix=$r2prefix.'_' unless($r2prefix=~/[_-]$/);
}

my @args;
push @args,'meta';
foreach(keys %r2data){
	push @args,($r2prefix.$_,$r2data{$_});
}
if(scalar @args>1){
	$store->set(@args);
}

#$metadata->{'encodings'}=undef;
$output=undef;


#now we need to output the urls into the metadata files
#if(defined $url_key and defined $meta_template){
if(defined $url_key){

	print "INFO: Outputting encoding URLs into the key '$url_key' in the metadata stream\n";
	
	my $url_value;
	$url_value=$url_value.$_->{'url'}."\|" foreach(@urls);
	
	print "DEBUG: URL value to output: $url_value\n";
	chop $urldata;	#remove the last delimiter
	$store->set('meta',$url_key,$url_value);

} else {
	print "INFO: Not outputting encodings into metadata stream, as <url_key> was not set.\n";
}

print "+SUCCESS: R2 notification has been made.\n";
