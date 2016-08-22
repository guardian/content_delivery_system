#!/usr/bin/perl
$|=1;

my $version='$Rev: 517 $ $LastChangedDate: 2013-10-07 12:07:00 +0100 (Mon, 07 Oct 2013) $';

#THIS METHOD HAS BEEN DEPRECATED. DO NOT USE.
#Instead, you should use read_fcs to import the FCS XML file into the datastore.
#this script takes the FCS XML file specified in cf_xml_file and converts it into a new .inmeta file, setting cf_inmeta_file in the process.
#Arguments:
#  <template_path> [OPTIONAL] - path to the fcs2inmeta.tt template
#END DOC

#internal config
my $template_name="inmeta.tt";
my $default_template_path="/etc/cds_backend/templates";
#end config

use XML::SAX;
#use lib "/usr/local/lib/cds_backend";
use CDS::Parser::saxfcs;
use Data::Dumper;
use File::Basename;
use Template;

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
check_args(qw(cf_xml_file cf_temp_file));

if(! -f $ENV{'cf_xml_file'}){
	print STDERR "-FATAL: Unable to find XML file " . $ENV{'cf_xml_file'} ."\n";
	exit 2;
}
my $fcs_parser = XML::SAX::ParserFactory->parser(Handler =>CDS::Parser::saxfcs->new);
$fcs_parser->parse_uri($ENV{'cf_xml_file'});
my $fcs_data=$fcs_parser->{'Handler'}->{'content'};
print Dumper($fcs_data) if defined $ENV{'debug'};;

my $n=0;
my $data;
my $tt=Template->new(ABSOLUTE=>1);

#build a data hash for the template.
foreach(keys %{$fcs_data->{'asset'}}){
	if($n>1){
		print STDERR "-WARNING: Multiple assets found in FCS XML.  Only processing the first."
	} else {
		my $id=$_;
		$data->{'meta_source'}->{'asset_id'}=$_;
		foreach(keys %{$fcs_data->{'asset'}->{$_}}){
			my $key=lc $_;
			$key=~tr/ /_/;
			my $value=$fcs_data->{'asset'}->{$id}->{$_}->{'value'};
			$data->{'meta_source'}->{$key}=$value;
		}
		print Dumper($data) if defined $ENV{'debug'};
		#work out the output filename
		my $output_filename=$fcs_data->{'asset'}->{$id}->{'File Name'}->{'value'}.".inmeta";
		my $output_path=dirname($ENV{'cf_xml_file'});
		open FH,">:utf8",$output_path."/".$output_filename or die "Could not create inmeta file '".$output_path."/".$output_filename."'\n";

		my $output;
		$tt->process($default_template_path."/".$template_name,$data,\$output);
		print FH $output;
		close FH;
		
		open FH,">:utf8",$ENV{'cf_temp_file'} or die "Could not open temporary file '".$ENV{'cf_temp_file'}."'\n";
		print FH "cf_inmeta_file=$output_path/$output_filename\n";
		close FH;
		++$n;
	}
}

