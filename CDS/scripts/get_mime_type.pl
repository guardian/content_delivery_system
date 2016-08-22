#!/usr/bin/perl

my $version='$Rev: 1067 $ $LastChangedDate: 2014-09-26 11:59:03 +0100 (Fri, 26 Sep 2014) $';

#This CDS method attempts to use the system 'file' command to determine the mime type of the given media file
#Arguments:
# <take-files>media - you should give this access to the media file
# <output_key>keyname [OPTIONAL] - output the mime type to this key (default: movie:mimetype)
#END DOC

use CDS::Datastore;

sub sanitise_argument
{
    my $arg=shift;
    
    $arg=~s/'/\'/g;
    return $arg;
}

sub get_file_mimetype
{
    my $targetfile=shift;
    
    my $result=`$filecmd -b --mime-type '$targetfile'`;
    if($?!=0){
        my $rtncode=$?>>8;
	chomp $result;
        print "-ERROR: Unable to run $filecmd -b --mime-type $targetfile: $result ($rtncode)";
        return undef;
    }
    chomp $result;
    return $result;
}

#START MAIN
print "get_mime_type version $version\n";

our $filecmd=`which file`;
chomp $filecmd;

unless(-x $filecmd){
    print "-ERROR: the file command '$filecmd' does not appear to either be installed or executable.\n";
    exit(1);
}

my $store=CDS::Datastore->new('get_mime_type');

my $targetfile=$ENV{'cf_media_file'};
unless(-f $targetfile){
    print "-ERROR: the media file '$targetfile' does not exist\n";
    exit(1);
}

$targetfile=sanitise_argument($targetfile);

my $mimetype=get_file_mimetype($targetfile);
unless($mimetype){
    exit(1);    #error message has been shown by subroutine
}

my $section='media';
my $key='mimetype';
if($ENV{'output_key'}){
    print "INFO: using ".$ENV{'output_key'}." as output key specifier\n";
    my @parts=split /:/,$ENV{'output_key'};
    if($parts[1]){
        $section=$parts[0];
        $key=$parts[1];
    } else {
        $key=$ENV{'output_key'};
    }
}
print "INFO: Outputting found mime type '$mimetype' to datastore key '$section:$key'...";
$store->set($section,$key,$mimetype);
exit(0);
