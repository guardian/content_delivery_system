#!/usr/bin/perl

my $version='$Rev: 472 $ $LastChangedDate: 2013-08-14 14:25:30 +0100 (Wed, 14 Aug 2013) $';

use Data::Dumper;
use CDS::Datastore::Episode5;

#This module reads a "trigger file".  A "trigger file" is defined as a file which
#contains metadata in key=value<newline> pairs.
#Special cases are METAFILE, INMETAFILE, MEDIAFILE and XMLFILE
#If these exist then the relevant cf_*_file is set.
#Any requested fields can then be output into a cf_meta_file or cf_inmeta_file

#Arguments:
#<take-files>xml	- the "trigger file" should be specified as a cf_xml_file
#<output-fields>field1|field2... - output these fields from the trigger file into the meta/inmeta file
#<prepend-path>		- prepend this path to any path given for META, INMETA etc. files

sub check_args {
	my @args=@_;

	foreach(@args){
		if(not defined $ENV{$_}){
			print "-FATAL: $_ was not specified.  Please check the route file.\n";
			exit 1;
		}
	}
}

sub output_meta_file {
my ($metafile,$output)=@_;

my ($fh, $filename) = tempfile();
print "DEBUG: outputting metadata to temp file $filename.\n" if $debug;
print $fh $output;

close $fh;

print "DEBUG: deleting $metafile and replacing with $filename.\n" if $debug;
unlink($metafile);
move($filename,$metafile);
}

#START MAIN
check_args(qw/output_fields/);
my $store=CDS::Datastore::Episode5->new('read_triggerfile');

my $debug=1 if($ENV{'debug'});

my $triggerfile=$ENV{'cf_xml_file'};
if(not -f $triggerfile){
	print "-FATAL: Trigger file '$triggerfile' does not exist.\n";
	exit 1;
}

#read in the data from the triggerfile
my %triggerdata;

open FH,"<$triggerfile" or die  "-FATAL: Unable to open trigger file '$triggerfile' even though it exists!.\n";

while(<FH>){
	#my ($key,$value)=split /=/;
	if(/^([^=]+)=(.*)$/){
		my $key=$1;
		my $value=$2;
		chomp $value;
		$triggerdata{$key}=$value;
	} else {
		print "-WARNING - could not get key/value pair from line $_.\n";
	}
}
close FH;

print Dumper(\%triggerdata) if($debug);

#ok, now tell CDS skeleton if any component files need updating
my $tempfile=$ENV{'cf_temp_file'};

open TEMPFILE,">$tempfile" or die "-FATAL: Unable to open return temp file '$tempfile' for writing.\n";

my $prepend;
if(defined $ENV{'prepend_path'}){
	$prepend=$ENV{'prepend_path'};
}

my $metafile;
my $metaparent;

if(defined $triggerdata{'METAFILE'}){
	print TEMPFILE "cf_meta_file=$prepend".$triggerdata{'METAFILE'}."\n";
	$metafile=$prepend.$triggerdata{'METAFILE'};
	$metaparent="meta";
	$store->import_episode($metafile,0);	#2nd arg=> take all of the file, not just the bits that Episode doesn't muck up
}
if(defined $triggerdata{'INMETAFILE'}){
	print TEMPFILE "cf_inmeta_file=$prepend".$triggerdata{'INMETAFILE'}."\n";
	$metafile=$prepend.$triggerdata{'INMETAFILE'};
	$metaparent="meta";
	$store->import_episode($metafile,0);
}
print TEMPFILE "cf_media_file=$prepend".$triggerdata{'MEDIAFILE'}."\n" if(defined $triggerdata{'MEDIAFILE'});
print TEMPFILE "cf_xml_file=$prepend".$triggerdata{'XMLFILE'}."\n" if(defined $triggerdata{'XMLFILE'});

close TEMPFILE;

#now update the datastore

my @args;
push @args,'meta';
foreach(split /\|/,$ENV{'output_fields'}){
	print "\tdebug: outputting $_=".$triggerdata{$_}.".\n" if($debug);
	push @args,($_,$triggerdata{$_});
#	$metadata->{$metaparent}->{$_}=$triggerdata{$_};
}
#this is more efficient than looping calls to $store->set, as this way the data store only commits to storage once.
$store->set(@args);

print "+SUCCESS: ".$ENV{'output_fields'}." have been output to the metadata stream.\n";
