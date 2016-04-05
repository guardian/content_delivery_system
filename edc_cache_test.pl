#!/usr/bin/perl

use lib ".";
use CDS::Encodingdotcom::Cache;

my $cache=CDS::Encodingdotcom::Cache->new('db'=>'encodingdotcom.cache','client'=>'edc_cache_test.pl');

my $rv=$cache->store('rubbish',5678);
print "Unable to store cached value\n\n\n" unless($rv);

$rv=$cache->store('duplicate',5678);
print "Unable to store cached value\n\n\n" unless($rv);


my $id=$cache->lookup('rubbish','Timeout'=>15);

if($id){
	print "Retrieved an id of $id.\n";
} else {
	print "Did not retrieve an id.\n";
}