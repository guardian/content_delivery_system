#!/usr/bin/perl
my $version='$Rev: 660 $ $LastChangedDate: 2014-01-06 18:08:23 +0000 (Mon, 06 Jan 2014) $';

#This CDS method pushes the route's metadata onto an Amazon SQS queue for further processing in the cloud.
#
#Arguments:
#  <aws_key>blah - Amazon api key to access the queue
#  <secret>blah - Secret key portion ("password") corresponding to <key> to access the queue
#  <queue_url>https://queue/url - URL where we can find the queue to push onto.  HTTPS access is HIGHLY recommended
#  <meta_format/> - use .meta format
#  <inmeta_format/> - use .inmeta format
#  <json_format/> - use JSON format
#END DOC

$|=1;
use Amazon::SQS::Simple;
use CDS::Datastore::Episode5;
use JSON;
use Data::Dumper;

sub check_args
{
foreach(@_){
	unless($ENV{$_}){
		print "-ERROR - You must specify <$_> in the route file configuration.  Consult the s3_put section in the CDS methods documentation if you are unsure as to what to use.\n";
		exit 1;
	}
}
return 0;
}

#START MAIN
check_args(qw/aws_key secret queue_url/);

my $debug=$ENV{'debug'};
my $store=CDS::Datastore::Episode5->new('sqs_send');

my $sqs=Amazon::SQS::Simple->new($ENV{'aws_key'},$ENV{'secret'});

my $q=$sqs->GetQueue($ENV{'queue_url'});
unless($q){
	print "-ERROR: Unable to get the queue at ".$ENV{'queue_url'}."\n";
	exit 1;
}

my $content;
if($ENV{'inmeta_format'}){
	print "INFO: Using inmeta format for message...\n";
	$store->export_inmeta(\$content);
}elsif($ENV{'meta_format'}){
	print "INFO: Using .meta format for message...\n";
	$store->export_meta(\$content);
}elsif($ENV{'json_format'}){
	print "INFO: Using JSON format for message...\n";
	$content=to_json($store->get_template_data(1));
}else {
	print "-ERROR: You did not specify which format to use to send data.  You should specify <inmeta_format/>, <meta_format/> or <json_format/> to output data\n";
	exit 1;
}

my $response=$q->SendMessage($content);
print Dumper($response);

print "+SUCCESS: Message sent.  Probably.  Still need to check the response codes.\n";
exit 0;
