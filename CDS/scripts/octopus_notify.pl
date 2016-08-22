#!/usr/bin/perl

my $version='$Rev: 651 $ $LastChangedDate: 2014-01-01 16:57:45 +0000 (Wed, 01 Jan 2014) $';

use Data::Dumper;
use CDS::Datastore;
use CDS::octopus_simple;

#This is a CDS method to use the octopustutil program to deliver a message to a user via Octopus Multimedia. 
#It is intended to be used for logging progress and errors in a user-readable manner.
#
#arguments:
#<event>{queued|transcoded|uploaded} - Tell Octopus that the event is one of these. Required.
#<message>blah - descriptive text to show the user. Supports substitutions
#<octopus_id_key>blah [optional] - use this datastore key for octopus id (default: octopus_ID)
#<destination_key>blah [optional] - use this datastore key for the route destination to give to Octopus (default: upload_destination)
#END DOC

#use File::Temp qw/ tempfile tempdir/;
#use File::Basename;

#Configuration
#my $template_path="/etc/cds_backend/templates";
#my $event_field="octopus_event";
#my $message_field="octopus_message";
my @valid_events=qw/Queued Transcoded Uploaded/;
#End config

sub put_back_spaces {
	my ($data)=@_;
	
	foreach(keys %{$data}){
		my $newkeyname=$_;
		$newkeyname=~tr/_/ /;
		print "debug: put_back_spaces: old key name was $_ new key name is $newkeyname\n" if defined $ENV{'debug'};
		if($newkeyname ne $_){
			$data->{$newkeyname}=$data->{$_};
			delete $data->{$_};
		}
	}
}
	
sub check_args {
	my @args=@_;

	foreach(@args){
		if(not defined $ENV{$_}){
			print "-FATAL: $_ was not specified.  Please check the route file.\n";
			exit 1;
		}
	}
}

sub check_event {
	my($test,@events)=@_;
	
	foreach(@events){
		return 1 if($test eq $_);
	}
	print "-WARNING: $test is not a valid Octopus event.  Expect problems.\n";
	return 0;
}

#Check that we've been given the correct arguments
check_args(qw/event message/);

my $store=CDS::Datastore->new('octopus_notify_2');

my $input_xml;
my $output_template;
my $key;


#Off we go....
print "octopus_notify.pl v1.\n";
print "Using incoming XML file $input_xml\n";


#Now, we modify the data.
check_event($ENV{'event'},@valid_events);
#if(defined $content->{$key}->{$event_field}){
#	if($content->{$key}->{$event_field} ne $ENV{'previous_event'}){
#		print "-WARNING: The current event ".$content->{$key}->{$event_field}." was not expected.  Expecting ".$ENV{'previous_event'}.".\n";
#		print "\tThis may indicate a problem, but continuing anyway.\n";
#	}
#}
my $msg=$store->substitute_string($ENV{'message'});

if(not $msg=~/^\w*#.*$/){
	print "-WARNING: The message '$msg' does not conform to the expected standard - {status}#{message}.  This may cause problems in Octopus.\n";
}

#$content->{$key}->{$event_field}=$ENV{'event'};
#$content->{$key}->{$message_field}=$ENV{'message'};
if($ENV{'octopus_id_key'}){
	$key=$ENV{'octopus_id_key'};
} else {
	$key='octopus ID';
}
print "INFO: using key $key for octopus ID\n";

my $octopusid=$store->get('meta',$key);
if(not $octopusid or not ($octopusid=~/^\d+$/)){
	print "-FATAL: Got '$octopusid' for the Octopus ID, which doesn't look valid (zero-length or non-digit characters)\n";
	exit 1;
}

if($ENV{'destination_key'}){
	$key=$ENV{'destination_key'};
} else {
	$key='upload_destination';
}

print "INFO: using key $key for upload destination\n";

my $dest=$store->get('meta',$key);

my $rv=CDS::octopus_simple::create_event($octopusid,$msg,$ENV{'event'},$dest,$ENV{'debug'});
#This assumption (exit code=0 => no error, exit code>0 => error) seems valid in testing...
if($rv>1){
	print "-ERROR: Unable to create Octopus event.\n";
	exit 1;
}

print "+SUCCESS: Log operation completed successfully.\n";
