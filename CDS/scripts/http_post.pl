#!/usr/bin/perl

my $version='$Rev: 472 $ $LastChangedDate: 2013-08-14 14:25:30 +0100 (Wed, 14 Aug 2013) $';

#this is a CDS module to post key/value pairs to an HTTP/HTTPS form.
#HTTPS support is built-in to LWP, if it doesn't work it means you don't have SSL modules
#etc. installed.  Consult CDS documentation and make sure LWP::Protocol::https is installed.

#arguments:
# <headers>header1|header2|header3... [optional] - use these headers (for authorisation etc.)
#												each item in the list is put on a newline and
#												used as a header
# <url>blah - POST to this URL
# <form_fields>fieldname1|fieldname2|fieldname3|fieldname4... POST these field names
# <form_data>value1|{meta:value2}|{media:value3}|{track:vide:value4}... Use these values for the named fields
# <retries>n - retry this number of times.  Default=5.
# <retry_delay>n - wait this long between retries (in seconds). Default=5s.
# <timeout>n - timeout a request after this time (in seconds). Default=30s.a
# <debug/> - spew debugging information
# <output_keys>key1|key2|key3 [optional] - output the webserver's response to this key in the datastore
# <output_delimiter>c [optional] - use this character/regex to split the servers output for multiple keys.  \n means newline, \t means tab.  Multiple delimiters can be specified like this: [&\n:].  / characters must be escaped like this: \/  Defaults to none.
# <output_skip>n [optional] - ignore this number of fields in the output.

use LWP::UserAgent;
use CDS::Datastore;
use Data::Dumper;

use warnings;

my $debug;
my @headers;

sub check_args {
my(@list)=@_;

foreach(@list){
	unless($ENV{$_}){
		print STDERR "ERROR - you must specify <$_> in the route file.\n";
		exit 1;
	}
}

}

sub dump_request_cb {
my($request,$ua,$h)=@_;

print "debug: Request about to be sent:\n".$request->as_string."\n---------------------------\n";
}

sub request_prepare_cb {
my($request,$ua,$h)=@_;

print STDERR "in request_prepare callback\n" if($debug);
foreach(@headers){
	/^([^:]+):\s*(.*)$/;
	if($debug){
		print STDERR "debug: request_prepare_cb got header name $1 and value $2\n";
	}
	$request->header($1=>$2);
}
}

#START MAIN
#first set up arguments
check_args(qw/url form_fields form_data/);

#FIXME: should validate URL.
my $post_url=$ENV{'url'};

my @fields=split /\|/,$ENV{'form_fields'};
my @data=split /\|/,$ENV{'form_data'};
my $retries=5;
if($ENV{'retries'} and $ENV{'retries'}=~/^\d+$/){
	$retries=$ENV{'retries'};
}
my $retry_delay=5;
if($ENV{'retry_delay'} and $ENV{'retry_delay'}=~/^\d+$/){
	$retry_delay=$ENV{'retry_delay'};
}
my $timeout=30;
if($ENV{'timeout'} and $ENV{'timeout'}=~/^\d+$/){
	$timeout=$ENV{'timeout'};
}
$debug=1 if($ENV{'debug'});

my $delim;

if($ENV{'output_delimiter'}){
	$delim=$ENV{'output_delimiter'};
}

my $skip;
if($ENV{'output_skip'}){
	if($ENV{'output_skip'}=~/^\d+$/){
		$skip=$ENV{'output_skip'};
	} else {
		$skip=0;
	}
}
my @output_keys=split /\|/,$ENV{'output_keys'};

#my @headers;
@headers=split /\|/,$ENV{'headers'} if($ENV{'headers'});

$Data::Dumper::Pad="\t";
	
if($debug){
	print STDERR "http_post v1.  Running with $retries retries at $retry_delay seconds delay.\n\n";
	print STDERR "User-specified headers:";
	print STDERR Dumper(\@headers);
}

my $store=CDS::Datastore->new('http_post');
my $ua=LWP::UserAgent->new;
$ua->add_handler('request_prepare'=>\&request_prepare_cb);
$ua->add_handler('request_prepare'=>\&dump_request_cb) if($debug);
$ua->timeout($timeout);

my %formdata;
my $n=0;

foreach(@fields){
	my $key=$_;
	my $value=$store->substitute_string($data[$n]);
	$formdata{$key}=$value;
	++$n;
}

if($debug){
	print STDERR "Form key/value pairs:\n";
	print STDERR Dumper(\%formdata);
}

my $response;
$n=1;

SENDLOOP: {
do {
	print "\nSending, attempt $n of $retries...\n";
	$response=$ua->post($post_url,\%formdata);

	print "Server response was \n".$response->as_string."\n---------------------------\n";
	if($response->is_error){
		last SENDLOOP if($n>$retries);
		print "-WARNING - server sent an error, sleeping $retry_delay before retry...\n";
		sleep $retry_delay;
		++$n;
	}
} while($response->is_error);
}	#SENDLOOP

if(scalar @output_keys>1 and not defined $delim){
	print "-WARNING - multiple keys selected for output but no delimiter set.  The entire server output will be output to ".$output_keys[0]."\n";
}

if($store->isValid()){
	my @setvars;
	
	push @setvars,'meta';
	if(defined $delim){
		print "INFO: skipping $skip output fields\n";
		my @values=split /$delim/,$response->decoded_content;
		my $n_values=scalar @values;
		my $n_keys=scalar @output_keys;
		if($n_keys ne $n_values-$skip){
			print "-WARNING: $n_keys keys specified but ".$n_values-$skip." values recieved.  Extra keys will be blank.  Extra values will be lost.\n";
		}
		my $n=$skip;
		foreach(@output_keys){
			push @setvars,($_,$values[$n]);
			++$n;
		}
	} else {
		push @setvars,($output_keys[0],$response->decoded_content);
	}
	if($debug){
		print "Data to set:\n";
		print Dumper(\@setvars);
	}
	$store->set(@setvars);
} else {
	print "-WARNING - datastore was not set.  Unable to output content values.  Expect problems.\n";
}

if($response->is_success){
	if($response->decoded_content=~/^ERROR:(.*)$/){
		print "-ERROR - Server program said '$1'.\n";
		exit 1;
	}
	print "+SUCCESS - data posted to $post_url.\n";
	exit 0;
} else {
	print "-ERROR - Server said '".$response->status_line."'\n";
	exit 1;
}
