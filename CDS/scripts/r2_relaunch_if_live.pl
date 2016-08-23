#!/usr/bin/perl

our $version='$Rev$ $LastChangedDate$';

#This method checks if a given page is live in R2.  If it is, then it will request it to be
#re-launched; this should re-index it in the content API and ensure that all encodings are up to date.
#It is intended to be used in supplementary upload routes, in a similar vein to doing a CDN cache flush
#once content has been updated.
#
#Arguments:
# <r2_id>nnnn [OPTIONAL] - use this value as the R2 ID.  Substitutions encouraged. Defaults to the value of the key r2-id in the datastore.
# <octopus_id>nnn [OPTIONAL] - use this value as the Octopus ID (used to remote-launch). Substitutions encouraged. Defaults to the value of the key "octopus ID"
# <r2_host>r2.host.name [OPTIONAL] - send requests to this hostname. Defaults to cms.gucode.gnl
# <test/> [OPTIONAL] - don't actually relaunch the content, but output to the log if it would be relaunched.
# <timeout>n [OPTIONAL] - timeout HTTP connection after this many seconds
#END DOC

use CDS::Datastore;
use LWP::UserAgent;

sub make_url
{
my ($section,$endpoint,$args)=@_;

return "http://$hostname/$root_path/$section/$endpoint/$args";
}

#START MAIN
our $hostname="cms.guprod.gnl";
our $store=CDS::Datastore->new('r2_relaunch_if_live');
our $r2_id=$store->get("meta","r2-id");
our $oct_id=$store->get("meta","octopus ID");
our $testing=0;
our $timeout=10;

if($ENV{'r2_host'}){
	$hostname=$store->substitute_string($ENV{'r2_host'});
}
if($ENV{'r2_id'}){
	$r2_id=$store->substitute_string($ENV{'r2_id'});
}
if($ENV{'octopus_id'}){
	$oct_id=$store->substitute_string($ENV{'octopus_id'});
}
if($ENV{'timeout'}){
	$timeout=$store->substitute_string($ENV{'timeout'});
}
if($ENV{'test'}){
	$testing=1;
}
our $max_attempts=10;

our $root_path="/tools/newspaperintegration";

print "r2_relaunch_if_live version $version\n";

unless($r2_id=~/^\d+$/){
	print "-ERROR: $r2_id does not look like an R2 ID (not numeric or zero-length).\n";
	exit 1;
}
unless($oct_id=~/^\d+$/){
	print "-ERROR: $oct_id does not look like an Octopus ID (not numeric or zero-length).\n";
	exit 1;
}
my $ua=LWP::UserAgent->new;
$ua->timeout($timeout);

my $response;

print "Testing to see if page with R2 ID '$r2_id' is actually live...\n";
my $attempts=0;
do{
	++$attempts;
	$response=$ua->get(make_url('article','live',$r2_id));
	if($attempts>$max_attempts){
		print "-ERROR: Unable to commumicate with R2 after $attempts tries: ".$response->status_line."\n";
		exit 1;
	}
} while(not $response->is_success);
my $r2_string=$response->decoded_content;
if($ENV{'debug'}){
	print "debug: R2 returned $r2_string\n";
}

unless($r2_string=~/^OK:(.*)$/){
	print "Page $r2_id does not appear to be live (R2 said $r2_string).\n";
	exit 0;
}
my $page_url=$1;

print "Page $r2_id appears to be currently live at $page_url.\n";

unless($testing){
	print "Attempting to re-launch the page using Octopus ID $oct_id...\n";
	my $attempts=0;
	do{
		++$attempts;
		$response=$ua->get(make_url('article','launch',$oct_id));
		if($attempts>$max_attempts){
			print "-ERROR: Unable to commumicate with R2 after $attempts tries: ".$response->status_line."\n";
			exit 1;
		}
	} while(not $response->is_success);
	$r2_string=$response->decoded_content;
	if($ENV{'debug'}){
		print "debug: R2 returned $r2_string\n";
	}
	unless($r2_string=~/^OK:/){
		print "-ERROR: R2 said: $r2_string\n";
		exit 1;
	}
	print "+SUCCESS: Re-launched the page at $page_url with Octopus ID $oct_id and R2 ID $r2_id\n"; 
} else {
	print "-WARNING: Not re-launching the page as we are running in test mode. To enable re-launching, remove <test/> from this method configuration in the routefile\n";
}

exit 0;