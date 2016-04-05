package CDS::Brightcove;

use warnings;
use strict;

use LWP::UserAgent;
use JSON;
use Data::Dumper;

my $post_url="http://api.brightcove.com/services/post";
my $get_url="http://api.brightcove.com/services/library";

my $descLengthLimit=249;	#Brightcove's string length limit, in characters

sub new {
my($proto,%args)=@_;
my $class=ref($proto) || $proto;	# allow us to be derived

my $self={};
print Dumper(\%args);

#make everything case-insensitive
foreach(keys %args){
	my $newkey=lc $_;
	if($newkey ne $_){
		$args{$newkey}=$args{$_};
	}
}

if(defined $args{'debug'}){
	$self->{'debug'}=1;
} else {
	$self->{'debug'}=0;
}

#set default values for retries etc.
$self->{'retries'}=5;
$self->{'retries'}=$args{'retries'} if($args{'retries'});
$self->{'retry-delay'}=5;
$self->{'retry-delay'}=$args{'retry-delay'} if($args{'retry-delay'});

#set up a useragent to talk to Brightcove
my $ua=LWP::UserAgent->new;
if(defined $args{'timeout'}){
	$ua->timeout($args{'timeout'});
} else {
	$ua->timeout(10);
}
$ua->env_proxy;
#can add in handler callbacks here via $ua->add_handler();
$ua->add_handler(request_prepare=>\&set_multipart);
$self->{'ua'}=$ua;
bless($self,$class);
return $self;
}

sub loadKey {
my ($self,$filename,$param)=@_;
#the key file can have any number of key=value pairs, so $param specifies the key name to use.
my %data;

print "CDS::Brightcove - using key file $filename" if($self->{'debug'});
open my $fh,"<$filename" or return undef;
my @lines=<$fh>;

foreach(@lines){
	chomp;
#	print $_."\n";
	if(/^([^:]+):\s*(.*)$/){
		$data{$1}=$2;
	}
}
close $fh;

#print Dumper(\%data);
#die;
$self->{'key'}=$data{$param};
}

sub check_args {
my($hash,@arglist)=@_;

foreach(@arglist){
	unless(defined $hash->{$_}){
		print STDERR "CDS::Brightcove - ERROR - missing argument $_\n";
		return 0;
	}
}
return 1;
}

sub set_retries {
my($self,$r)=@_;

$self->{'retries'}=$r;
}

sub set_retry_delay {
my($self,$r)=@_;

$self->{'retry-delay'}=$r;
}

my $boundarytext="AaBbCcDd012";
sub set_multipart {
my($request,$ua,$h)=@_;

$request->header('Content-Type'=>"multipart/form-data; boundary=$boundarytext");
print $request->as_string;
return $request;
}

sub make_request_body {
my($jsontext)=@_;

my $requesttext;
$requesttext="--$boundarytext\r\nContent-Disposition: form-data; name=\"JSON-RPC\"\r\nContent-Type: application/json-rpc";
$requesttext=$requesttext."\r\n\r\n$jsontext\r\n\r\n--$boundarytext--\r\n";

return $requesttext;
}

sub createRemoteVideo {
my($self,%args)=@_;

my %bcdata;

if($self->{'debug'}){
	print STDERR "CDS::Brightcove - debug - called with:\n";
	print STDERR Dumper(\%args);
	print STDERR "-----------------------\n";
}

if(not $self->{'key'}){
	print STDERR "CDS::Brightcove - ERROR - no key set.  You need to load a key with loadKey before calling createVideo*.\n";
	return undef;
}

unless(check_args(\%args,qw/title description refid url size duration codec/)){
	#the error message should have been shown by check_args
	return undef;
}

#%bcdata is the hash representation that we convert to JSON to send to Brightcove
#FIXME - should also support startDate/endDate http://support.brightcove.com/en/docs/media-api-objects-reference#Video
$bcdata{'method'}='create_video';
$bcdata{'params'}{'token'}=$self->{'key'};
#very important - we don't want brightcove mucking around with our nice pristine encodings
$bcdata{'params'}{'H264NoProcessing'}='true';
$bcdata{'params'}{'video'}{'name'}=$args{'title'};
$bcdata{'params'}{'video'}{'shortDescription'}=substr($args{'description'},0,$descLengthLimit);
$bcdata{'params'}{'video'}{'referenceId'}=$args{'refid'};
$bcdata{'params'}{'video'}{'videoFullLength'}{'referenceId'}=$args{'refid'};
$bcdata{'params'}{'video'}{'videoFullLength'}{'remoteUrl'}=$args{'url'};
$bcdata{'params'}{'video'}{'videoFullLength'}{'size'}=$args{'size'};
$bcdata{'params'}{'video'}{'videoFullLength'}{'videoDuration'}=$args{'duration'}*1000;
$bcdata{'params'}{'video'}{'videoFullLength'}{'videoCodec'}=$args{'codec'};

print Dumper(\%bcdata) if($self->{'debug'});
my $jsontext=to_json(\%bcdata,{utf8=>1});
print "\n$jsontext\n" if($self->{'debug'});

my $body=make_request_body($jsontext);

my $response;
my $n=0;

CRV_SENDLOOP: {
do {
	print "INFO - Connecting to Brightcove, attempt $n...\n";
	$response=$self->{'ua'}->post($post_url,Content=>$body);
	++$n;
	if($n>$self->{'retries'}){
		print "Unable to connect to Brightcove (".$response->as_string."), waiting ".$self->{'retry-delay'}."s before retry ($n/".$self->{'retries'}.")...\n";
		sleep($self->{'retry-delay'});
		last CRV_SENDLOOP;
	}
} while($response->is_error);
}

print $response->as_string if($self->{'debug'});
if($response->is_error){
	print "-ERROR - Brightcove returned ".$response->as_string."\n";
	return undef;
}

my $bcresponse=decode_json($response->content);
print Dumper($bcresponse) if($self->{'debug'});
if(defined $bcresponse->{'error'}){
	print "-ERROR: Brightcove said '".$bcresponse->{'error'}->{'message'}."' (error ".$bcresponse->{'error'}->{'code'}.")\n";
	return undef;
}

my $videoid;
if(defined $bcresponse->{'result'}){
	#this should be the Brightcove video ID of the given video
	return $bcresponse->{'result'};
}

print "-ERROR - Brightcove response not an error or success???\n";
print Dumper($bcresponse);
return undef;
}

sub addRemoteImageToVideo {
my($self,%args)=@_;

my %imagedata;

my $videoid=$args{'videoid'};
unless($videoid=~/\d+/){
	print STDERR "CDS::Brightcove - ERROR - You need to specify a valid numeric Brightcove ID to add images\n";
	return undef;
}

my $imagetype=$args{'type'};
if(lc $imagetype eq "thumbnail" or lc $imagetype eq "video_still"){
	$imagetype=uc $imagetype;
} else {
	print STDERR "CDS::Brightcove - ERROR - You need to specify the image type as 'thumbnail' or 'video_still'\n";
	return undef;
}

unless(check_args(\%args,qw/refid url/)){
	#the error message should have been shown by check_args
	return undef;
}

$imagedata{'method'}='add_image';
$imagedata{'params'}{'image'}{'type'}=$imagetype;
$imagedata{'params'}{'image'}{'referenceId'}=$args{'refid'};
$imagedata{'params'}{'image'}{'remoteUrl'}=$args{'url'};
$imagedata{'params'}{'token'}=$self->{'key'};
$imagedata{'params'}{'video_id'}=$videoid;
$imagedata{'params'}{'resize'}=$args{'resize'} if(defined $args{'resize'});

print Dumper(\%imagedata) if($self->{'debug'});
my $jsontext=to_json(\%imagedata,{utf8=>1});
print "\n$jsontext\n" if($self->{'debug'});

my $body=make_request_body($jsontext);

my $n=0;
my $response;

ARI_SENDLOOP: {
do {
	print "INFO - Connecting to Brightcove, attempt $n...\n";
	$response=$self->{'ua'}->post($post_url,Content=>$body);
	++$n;
	if($n>$self->{'retries'}){
		print "Unable to connect to Brightcove (".$response->as_string."), waiting ".$self->{'retry-delay'}."s before retry ($n/".$self->{'retries'}.")...\n";
		sleep($self->{'retry-delay'});
		last ARI_SENDLOOP;
	}
} while($response->is_error);
}

print $response->as_string if($self->{'debug'});
if($response->is_error){
	print "-ERROR - Brightcove returned ".$response->as_string."\n";
	return undef;
}

my $bcresponse=decode_json($response->content);
print Dumper($bcresponse) if($self->{'debug'});
if(defined $bcresponse->{'error'}){
	print "-ERROR: Brightcove said '".$bcresponse->{'error'}->{'message'}."' (error ".$bcresponse->{'error'}->{'code'}.")\n";
	return undef;
}

if(defined $bcresponse->{'result'}){
	return $bcresponse->{'result'}->{'id'};
}

}