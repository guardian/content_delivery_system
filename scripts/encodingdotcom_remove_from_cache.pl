#!/usr/bin/perl

#This is a simple CDS method to remove the given URL portion from the encoding.com cache.
#It is intended for use in master update routes, to invalidate the existence of a previous record.

#It expects the following arguments:
# <cachefile>/path/to/relevant/cache - work on the file stored here
# <sourceurl>blah [OPTIONAL] - use this value as the source URL.  Anything in the cache that contains this string will be removed (blank strings not allowed). If this is not given, then the name of the current media file will be used instead.

use Data::Dumper;
use CDS::Datastore;
use CDS::Encodingdotcom::Cache;
use File::Basename;

my $store=CDS::Datastore->new('encodingdotcom_remove_from_cache');

my $cachefile=$store->substitute_string($ENV{'cachefile'});
print "INFO: Using cache file '$cachefile'\n";

my $sourceurl;

if($ENV{'sourceurl'}){
	$sourceurl=$store->substitute_string($ENV{'sourceurl'});
} else {
	$sourceurl=basename($ENV{'cf_media_file'});
}

print "INFO: I will try to invalidate the encoding.com cache record for $sourceurl\n";
my $cache=CDS::Encodingdotcom::Cache->new('db'=>$cachefile,'client'=>'encodingdotcom_remove_from_cache','debug'=>0);

die "-FATAL: Unable to connect to cache database '$cachefile'" unless($cache);

my $r=$cache->remove_all_by_name($sourceurl);
print "INFO: Encodingdotcom::Cache returned $r.\n";
}

