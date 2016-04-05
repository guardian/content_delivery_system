#!/usr/bin/perl
$|=1;

my $version='$Rev: 958 $ $LastChangedDate: 2014-07-31 15:58:50 +0100 (Thu, 31 Jul 2014) $';

# A script to read in metadata from the metadata stream and convert it using a template into another format
# All output data should be escaped as XML-compliant.
#FIXME: should implement a <not_xml/> option to disable the XML escaping.  This will need a change to CDS::Datastore.

#Arguments:
# <output_template>blah - use this .tt Template Toolkit format template to output
# <output-template>blah - same as <output_template>
# <template-needs-simple/> - don't interpret or break-down data before passing to the template
# <output_file>blah [optional] - use this as the output filename.  Default is to output an XML file to the same directory as the current media file, using the filename of the current media file with an additional .xml extension.  This file is set to the current XML file for the route on a successful run.
# <array_keys>key1|key2|key3.... [optional] - treat the listed datastore keys as arrays (normally delimited by a | symbol) and break them down.  The original key is still accessible, the array (e.g. for key1) can be accessed in the template as meta.key1_list.
#END DOC

use XML::SAX;
use Data::Dumper;
use Template;
use Getopt::Long;
use CDS::Datastore;

# specific SAX parser (custom module)
# Other parsers may be added in the future.
#use lib "/usr/local/lib/cds_backend";

#use saxmeta;

my $default_template_path="/etc/cds_backend/templates";

sub stopit {
	my($code,$msg)=@_;
	print STDERR $msg;
	exit $code;
}


# input-format currently only works with the value "meta";  in the future other parsers could be added.

my $cds_inputFormat = $ENV{'input-format'};
if($ENV{'output_template'}){
	$cds_outputTemplate = $ENV{'output_template'};
} else {
	$cds_outputTemplate = $ENV{'output-template'};
}
my $cds_templateNeedsSimple = $ENV{'template-needs-simple'};

my $templatename='';
my $templatepath='';
my $outpunamet='';

my $inputMetaFile = $ENV{'cf_meta_file'};


$templatename = $cds_outputTemplate;
$keepsimple = $cds_templateNeedsSimple;
undef $dont_entity;

my $store=CDS::Datastore->new('metaxform');
$store->{'debug'}=$ENV{'debug'};
my $debug=$ENV{'debug'};

my $outputname;

if($ENV{'output_file'}){
	$outputname=$store->substitute_string($ENV{'output_file'});
} else {
	$outputname = $ENV{'cf_xml_file'};
}

if ($outputname eq '')
{
	# derive output file name from input meta file name.
	$outputname = $inputMetaFile;
	$outputname =~ s/.meta/.xml/;
}
if ($outputname eq '')
{
	# derive output file name from input media file name if we've not got a .meta file.
	$outputname = $ENV{'cf_media_file'} . ".xml";
}
if ($outputname eq '')
{
	# if we've still got nothing then look it up in the datastore.
	my ($path,$filename)=$store->get('media','path','filename',undef);
	$outputname=$path."/".$filename.".xml";
}

print "INFO: Outputting to $outputname\n" if($debug);
$templatepath=$default_template_path if($templatepath eq '');
if($templatename eq ''){
	print STDERR "-FATAL: No output template specified.\n";
	exit 2;
}

my @array_keys;

if($ENV{'array_keys'}){
	@array_keys=split /\|/,$ENV{'array_keys'};
} else {	#preserve old behaviour to avoid breaking things....	
	@array_keys=('keyword IDs','keyword');
}

my $output;
my $tt=Template->new(ABSOLUTE=>1);
#if first arg is 1, then don't convert spaces and hyphens to _.  second arg is list of keys to
#expand as arrays.

my $data=$store->get_template_data(0,\@array_keys);
print Dumper($data) if($debug);
$tt->process($templatename,$data,\$output) or die $tt->error;

print "INFO: Outputting to $outputname\n";

if($outputname ne ''){
	open FH,">$outputname" or stopit(3,"- FATAL: Unable to open output file '$outputname'.\n");
	print FH $output;
	close FH;
	
	# now the script needs to pass back the name of the xml file created by using the temporary file.
	my $tmpFile = $ENV{'cf_temp_file'};		
	print "MESSAGE: Open temp file to write name value pair to '$tmpFile'\n";
	my $fileOpenStatus = open CDS_TMP, ">", $tmpFile;
	print CDS_TMP "cf_xml_file=$outputname\n";
	close CDS_TMP;
} else {
	print STDERR "-FATAL: could not create output file.\n";
	print $output;
	exit 1;
}
