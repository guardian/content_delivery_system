#!/usr/bin/perl
$|=1;

my $version='$Rev: 897 $ $LastChangedDate: 2014-06-11 16:39:45 +0100 (Wed, 11 Jun 2014) $';

use XML::SAX;
use Data::Dumper;
use Template;
use File::Temp;
use CDS::Datastore;

#This script updates specified logging fields in Final Cut Server to
#tell it when a file has been uploaded.
#It uses the data store to get the Asset ID of the file
#and a .tt file to format the output.
#It uses a temp filename for the output xml

# it expects the following variables:
# cf_media_file
# cf_datastore_location
# cf_routename
# 
# date-format
# message
# fcs-field
# fcs-read-path
# fcs-id-key - use this metadata key to obtain the FCS ID.  defaults to 'FCS asset id'
# datatype - tell FCS that 'message' is this type of data.  defaults to 'string'. but could be 'boolean', integer, etc.
# messagetype - same as datatype

# it supports the following transforms:
# {date}
# {media-file}
# {meta-file}
# {routename}
# {meta-value-{keyname}}

#config
my $template_path="/etc/cds_backend/templates";
my $template_name="finalcutserver.tt";
my $path_sep="/";
#end config

sub check_args {
	my @args=@_;

	foreach(@args){
		if(not defined $ENV{$_}){
			print "-FATAL: $_ was not specified.  Please check the route file.\n";
			exit 1;
		}
	}
}

sub do_substitution {
	my($org_string,$key,$subst)=@_;

	$org_string=~s/$key/$subst/g;

	print "substituting key $key: result $org_string\n" if defined $ENV{'debug'};
	return $org_string;
}

#START MAIN
my $metafile;
check_args(('cf_media_file','cf_routename','message','fcs_field','fcs_read_path'));


#read in the metadata
my $store=CDS::Datastore->new('log_to_finalcutserver');


my $fcsid;
my $keyname;

if(defined $ENV{'fcs_id_key'}){
	$fcsid=$store->get('meta',$ENV{'fcs_id_key'});
	$keyname=$ENV{'fcs_id_key'};
} else {
	$fcsid=$store->get('meta','FCS asset ID');
	$keyname='FCS_asset_ID';
}

if($fcsid=~/^\d+$/){
	$fcsid="/asset/$fcsid";
}
unless($fcsid=~/^\/asset\/\d+$/){
	print "-FATAL: Unable to get Final Cut Server ID from $keyname.  The best I got was '$fcsid'.\n";
	exit 1;
}

#do some substitutions.....
my $date;
if(defined $ENV{'date_format'}){
	my $cmd="date \"+".$ENV{'date_format'}."\"";
	$date=`$cmd`;
	chomp $date;
}

$final_message=$store->substitute_string($ENV{'message'});

$final_message=do_substitution($final_message,'{date}',$date) if defined $date;

my $final_datatype;
if($ENV{'datatype'}){
	$final_datatype=$store->substitute_string($ENV{'datatype'});
} elsif ($ENV{'messagetype'}){
	$final_datatype=$store->substitute_string($ENV{'messagetype'});
} else {
	$final_datatype='string';
}

#construct data suitable for the template
my $output_hash;
$output_hash->{'FinalCutServer'}->{'entityId'}= $fcsid;
foreach(($ENV{'fcs_field'})){
	my %temp_hash;
	$temp_hash{'name'}=$_;
	$temp_hash{'type'}=$final_datatype;
	$temp_hash{'data'}=$final_message;
	$store->escape_for_xml(\%temp_hash);
	push @{$output_hash->{'Fields'}},\%temp_hash;
}

#$store->escape_for_xml($output_hash);

print Dumper($output_hash) if defined $ENV{'debug'};

my $tt=Template->new(ABSOLUTE=>1);
my $output;
unless($tt->process($template_path.'/'.$template_name,$output_hash,\$output)){
	print STDERR "-ERROR: Error with template - ".$tt->error()."\n";
	exit 1;
}
print $output if defined $ENV{'debug'};

my $outputfilename=tmpnam();
$outputfilename=~/\/([^\/]*)$/;
$outputfilename=$ENV{'fcs_read_path'} . $path_sep . $1 . ".xml";

open FH,">:utf8",$outputfilename or die "-FATAL: Unable to open output file $outputfilename";
print FH $output;
close FH;

print "+SUCCESS: Final Cut Server notification output to $outputfilename\n";
