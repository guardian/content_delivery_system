#!/usr/bin/perl
$|=1;
# output test process, only used for development purposes
my $version='$Rev: 472 $ $LastChangedDate: 2013-08-14 14:25:30 +0100 (Wed, 14 Aug 2013) $';


print STDOUT "MESSAGE: script output_test.pl called\n";

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