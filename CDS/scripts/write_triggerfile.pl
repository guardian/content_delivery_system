#!/usr/bin/perl

my $version='$Rev: 472 $ $LastChangedDate: 2013-08-14 14:25:30 +0100 (Wed, 14 Aug 2013) $';

use Data::Dumper;
use CDS::Datastore;

#This module writes out a "trigger file".  A "trigger file" is defined as a file which
#contains metadata in key=value<newline> pairs.

#Arguments:
#<take-files>media - to get filenames to use {filebase} etc. substitutions or access paths for output
#<output_fields>meta:field1|meta:field2|media:field1|track:vide:field3 - output these fields from the datastore into the trigger file.  If the {meta|media|track} part is excluded, meta is assumed.
#   Special cases  are {MEDIA|META|INMETA|XML}FILE
#<output_path>/path/to/file.trg - output the trigger file to this location.  Substititions accepted, e.g. /path/to/{filebase}_{meta:octopus ID}.trg
#<set_file>xml	[optional] - set the XML file in the currently processing bundle to the trigger file.  Not very useful.
#<fieldname_only/> [optional] - don't output meta:,media: etc. specifiers into trigger file
#<caps/>	   [optional] - capitalise all field names
#<collapse/>	   [optional] - remove all spaces/_ from field names

sub check_args {
	my @args=@_;

	foreach(@args){
		if(not defined $ENV{$_}){
			print "-FATAL: $_ was not specified.  Please check the route file.\n";
			exit 1;
		}
	}
}

#START MAIN
check_args(qw/output_fields output_path/);

$store=CDS::Datastore->new('write_triggerfile');

my $debug=$ENV{'debug'};
my $fieldname_only=$ENV{'fieldname_only'};

my @getdata;
my @fields=split(/\|/,$ENV{'output_fields'});
foreach(@fields){
	my @getspec;
	my @parts=split(/:/,$_);
	if(scalar @parts>1){ #i.e., we've got a :
		$getspec[0]=$parts[0];
		$getspec[1]=$parts[1];
		$getspec[2]=$parts[2] if($parts[2]);	#for track:type:spec
	} elsif($_=~/(MEDIA|META|INMETA|XML)FILE/){
		print STDERR "debug: got special $_\n";
		$getspec[0]=$_;
	} else {		#assume we're after meta field
		print STDERR "debug: defaulting to meta for $_\n";
		$getspec[0]='meta';
		$getspec[1]=$_;
	}
	push @getdata,\@getspec;
}

if($debug){
	print "Fields to output:\n";
	print Dumper(\@getdata);
}

my @data;
foreach(@getdata){
	my $value;
	if(scalar @$_<2){	#i.e., no section so a 'special'
		$value=$ENV{'cf_media_file'} if(@$_[0] eq 'MEDIAFILE');
		$value=$ENV{'cf_meta_file'} if(@$_[0] eq 'METAFILE');
		$value=$ENV{'cf_inmeta_file'} if(@$_[0] eq 'INMETAFILE');
		$value=$ENV{'cf_xml_file'} if(@$_[0] eq 'XMLFILE');
	} else {
		$value=$store->get(@$_);
	}
	push @data,$value;
}

if($debug){
	print "Values obtained:\n";
	print Dumper(\@data);
}

my $outputfilename=$store->substitute_string($ENV{'output_path'});
print "INFO: Outputting trigger file to $outputfilename\n";

open FH,'>:utf8',$outputfilename or die "Unable to open '$outputfilename' for writing.\n";
for(my $n=0;$n<scalar @getdata;++$n){
	my $key;
	if($fieldname_only){
		if(defined $getdata[$n]->[1]){
			$key=$getdata[$n]->[1];
			$key=$getdata[$n]->[2] if($getdata[$n]->[0] eq 'track');
		} else {
			$key=$getdata[$n]->[0];
		}
	} else {
		if(defined $getdata[$n]->[1]){
			$key=$getdata[$n]->[0].':'.$getdata[$n]->[1];
			$key=$key.':'.$getdata[$n]->[2] if($getdata[$n]->[0] eq 'track');
		} else {
			$key=$getdata[$n]->[0];
		}
	}
	$key=uc $key if($ENV{'caps'});
	$key=~tr/ // if($ENV{'collapse'});
	$key=~tr/_// if($ENV{'collapse'});

	print FH "$key=".$data[$n]."\n";
}
close FH;
print "+SUCCESS: Fields output successfully.\n";
exit 0;
