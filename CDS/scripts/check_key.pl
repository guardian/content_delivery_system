#!/usr/bin/perl

#This is a CDS module to check that the given keys exist within the metadata stream
#A later version will give the ability to verify them against regexes in the route file
#
#Arguments:
# <key>keyname - check that this key exists (within the meta section)
# <keys>keyname1|keyname2|etc. - check that the list of keys (separated by | characters) exist (within the meta section)
#END DOC

my $version='$Rev: 514 $ $LastChangedDate: 2013-09-24 13:13:20 +0100 (Tue, 24 Sep 2013) $';
use XML::SAX;
use Data::Dumper;
use CDS::Datastore;

#START MAIN
my $metafile,$meta_parent,$nonfatal,$debug,$has_failed;
my @keys;
my $store=CDS::Datastore->new('check_key');

$metafile=$ENV{'cds_datastore_location'};

$debug=1 if(defined $ENV{'debug'});
$nonfatal=1 if(defined $ENV{'nonfatal-error'});

if(defined $ENV{'key'}){
	push @keys,$ENV{'key'};
}

if(defined $ENV{'keys'}){
	push @keys,split(/\|/,$ENV{'keys'});
}

print "INFO: checking for keys ";
print $_." " foreach(@keys);
print ".\n";

foreach(@keys){
	my $value=$store->get('meta',$_);
	if(not defined $value){
		print "-ERROR: key '$_' is not defined in the datastore $metafile.\n";
		exit 1 unless($nonfatal);
		$has_failed=1;
	} elsif($nonfatal){
		print "+SUCCESS: key '$_' is defined in the datastore $metafile.\n";
	}
}
print "+SUCCESS: all keys exist within $metafile.\n" unless($has_failed);
