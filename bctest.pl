#!/usr/bin/perl

use lib ".";
use CDS::Brightcove;
use Data::Dumper;

my $bcobj=CDS::Brightcove->new(Debug=>1);

$bcobj->loadKey('keys/brightcove.api','Secret');

print Dumper($bcobj);

my $rc=$bcobj->createRemoteVideo(title=>'Test title',description=>'Test description',refid=>'Ref ID',url=>'http://this.is/a/test/url',fileSize=>432,duration=>3,codec=>'h264');

if($rc){
	print "+SUCCESS - brightcove asset created as ID $rc.\n";
}
