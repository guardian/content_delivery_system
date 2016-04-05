#!/usr/bin/perl
$|=1;

my $version='$Rev: 472 $ $LastChangedDate: 2013-08-14 14:25:30 +0100 (Wed, 14 Aug 2013) $';

# test input process, only used for development purposes

print STDOUT "script input_test.pl called\n";

# print the current environment variables that are set

if ($ENV{'cf_media_file'})
{
	print "MESSAGE: cf_media_file $ENV{'cf_media_file'}\n";
}

if ($ENV{'cf_meta_file'})
{
	print "MESSAGE: cf_inmeta_file $ENV{'cf_meta_file'}\n";
}

if ($ENV{'cf_inmeta_file'})
{
	print "MESSAGE: cf_inmeta_file $ENV{'cf_inmeta_file'}\n";
}

if ($ENV{'cf_media_file'})
{
	print "MESSAGE: cf_xml_file $ENV{'cf_xml_file'}\n";
}

	my $tmpFile = $ENV{'cf_temp_file'};		
	print "MESSAGE: Open temp file to write name value pair to '$tmpFile'\n";
	my $fileOpenStatus = open CDS_TMP, ">", $tmpFile;
	print CDS_TMP "cf_inmeta_file=dummy_value_from_input_test_process.inmeta\n";
	close CDS_TMP;

exit 0;