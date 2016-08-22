#!/usr/bin/perl

use lib ".";
use CDS::Datastore::Master;
use CDS::Datastore::Episode5;

use Data::Dumper;

$ENV{'cf_datastore_location'}="./test.db";

if(-f $ENV{'cf_datastore_location'}){
	unlink $ENV{'cf_datastore_location'};
}

my $master=CDS::Datastore::Master->new('datatest');
$master->init;

#die;

my $store=CDS::Datastore::Episode5->new('datatest');

$store->import_episode($_) foreach(@ARGV);

#$store->set('meta','title','This is a test video','keywords','testing, test, another test','object id','437623642378');
#$store->set('media','filename','test.mov','path','/this/is/a/test/path','escaped_path','/this/is/a/test/path/test.mov');

my @data=$store->get('meta','title','filename','FCS_asset_ID','something that\'s not valid','r2-devpath');
print Dumper(\@data);

my @data=$store->get('track','vide','bitrate','format','width','height');
print Dumper(\@data);

my @data=$store->get('track','audi','bitrate','format','width','height');
print Dumper(\@data);

my @data=$store->get('media','bitrate','format','duration','size');
print Dumper(\@data);

$store->set('meta','title','Over-ridden by script <>"!\'\'&&');
print Dumper($store->get_meta_hashref);

my @data=$store->getMultiple('meta','title');
print Dumper(\@data);

my $data=$store->get_template_data;
print Dumper($data);

my $translated;
$store->export_meta(\$translated);
print $translated;

my $teststring="On {weekday} {day}/{month}/{year} at {hour}:{min}:{sec}, I had a file called \"{meta:title}\" with video track size of {track:vide:size} in {media:path}/{media:filename} or {media-file}\n";
my $subbd=$store->substitute_string($teststring);
print "\n\n$subbd";
