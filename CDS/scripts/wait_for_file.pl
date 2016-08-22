#!/usr/bin/perl

my $version='$Rev: 472 $ $LastChangedDate: 2013-08-14 14:25:30 +0100 (Wed, 14 Aug 2013) $';

#this script waits for a given file to exist in a given path.   Usual substitutions are allowed in the path specification
#arguments:
#	<take-files>media|{meta|inmeta}		- you need to 'take' media in order to be able to match {filebase},{filename} etc.
#  <check-file-path>/path/to/lockfile	- wait for this file to exist.  Usual substitutions are allowed.
# 	<poll-time>n									- look for the file every n seconds
#	<timeout>n 		[OPTIONAL]				- give up and abort the route after n seconds
#	<invert/>			[OPTIONAL]				- wait until the file does NOT exist
#	<match-exact/>		[OPTIONAL]			- match the exact filename.  Otherwise, the file is judged to exist if a file exists which starts with the given name or has a regex match

use Data::Dumper;
use File::Basename;
use CDS::Datastore;

sub check_args {
	my @args=@_;

	foreach(@args){
		if(not defined $ENV{$_}){
			print "-ERROR: $_ was not specified.  Please check the route file.\n";
			exit 1;
		}
	}
}

#sub url_subst {
#my ($substring,$key,$val)=@_;
#
#$substring=~s/$key/$val/g;
#
#return $substring;
#}

sub have_file {
my($path,$exact,$invert,$debug)=@_;

if($exact and not $invert){
	return -f "$path";
}
if($exact and $invert){
	return not -f "$path";
}

my $filedir=dirname($path);
my $filename=basename($path);

print "INFO Searching directory $filedir...\n";
my @files=< $filedir/* >;
foreach(@files){
	$_=basename($_);
#	print "\t$_\n" if($debug);
	if(/^$filename/){
		return 1 if(not $invert);
		return 0;
	}
}

print "debug: No files found starting with the string $filename\n" if($debug);
return 0 if(not $invert);
return 1;
}

#START MAIN
check_args(qw/poll-time check-file-path/);

#if(defined $ENV{'cf_meta_file'}){
#	$metafile=$ENV{'cf_meta_file'};
#	$meta_parent="meta_source";
#} 
#if(defined $ENV{'cf_inmeta_file'}){
#	$metafile=$ENV{'cf_inmeta_file'};
#	$meta_parent="meta";
#}

my $invert=0;
$invert=1 if(defined $ENV{'invert'});
my $debug=0;
$debug=1 if(defined $ENV{'debug'});
my $checkfile=$ENV{'check-file-path'};
my $polltime=$ENV{'poll-time'};
my $timeout=$ENV{'timeout'};
my $exact=$ENV{'match-exact'};

my $store=CDS::Datastore->new('wait_for_file');

#get the metadata
#if(not defined $ENV{'cf_meta_file'} and not defined $ENV{'cf_inmeta_file'}) {
#	print "-WARNING: Neither meta nor inmeta file was provided, unable to continue\n";
#}

#if(not defined $ENV{'cf_media_file'} or $ENV{'cf_media_file'} eq ''){
#	print "-WARNING: media file was not provided. {filebase} {filename} etc. substitutions will not work.\n";
#}

#if(! -f $metafile and $metafile ne ''){
#	print "-WARNING: The provided metadata file $metafile does not exist.\n";
#	if($debug){
#		print "Dump of variables:";
#		print Dumper(\%ENV);
#	}
#}

#print "INFO: Reading metadata\n";
#my $parser=XML::SAX::ParserFactory->parser(Handler=>saxmeta->new);
#$parser->{'Handler'}->{'config'}->{'keep-simple'}=1;
#$parser->{'Handler'}->{'config'}->{'keep-spaces'}=1;
#$parser->parse_uri($metafile);
#my $metadata=$parser->{'Handler'}->{'content'};
#fix some weird bug in saxmeta.pm
#foreach(keys %{$metadata->{'meta_source1'}}){
#	$metadata->{'meta_source'}->{$_}=$metadata->{'meta_source1'}->{$_};
#}
#delete $metadata->{'meta_source1'};

#$metadata=$metadata->{$meta_parent};
#print Dumper($metadata) if($debug);

#gather data for substitutions
#my $filepath,$filebase,$fileextn;
#if($ENV{'cf_media_file'}=~/^(.*)\/([^\/]+)\.([^\/\.]*)$/){
#	$filepath=$1;
#	$filebase=$2;
#	$fileextn=$3;
#} elsif($ENV{'cf_media_file'}=~/^(.*)\/([^\/]+)$/){
#	$filepath=$1;
#	$filebase=$2;
#	$fileextn="";
#} elsif($ENV{'cf_media_file'}=~/^([^\/]+)$/){
#	$filepath=$ENV{'PWD'};
#	$filebase=$2;
#	$fileextn="";
#} else {
#	print "-WARNING: Unable to determine file name substitutions from media file '".$ENV{'cf_media_file'}."'\n";
#	$filepath='';
#	$filebase='';
#	$fileextn='';
#}

#my $t=localtime;

#make some substitutions
#my $finalstring=url_subst($checkfile,'{year}',$t->year);
#$finalstring=url_subst($finalstring,'{month}',$t->mon);
#$finalstring=url_subst($finalstring,'{day}',$t->mday);
#$finalstring=url_subst($finalstring,'{filebase}',$filebase);
#$finalstring=url_subst($finalstring,'{filepath}',$filepath);
#$finalstring=url_subst($finalstring,'{fileextn}',$fileextn);
#$finalstring=url_subst($finalstring,'{filename}',"$filebase.$fileextn");
#while($finalstring=~/{meta:([^{}]+)}/){
#	my $key=$1;
#	if(defined($metadata->{$key})){
#		$finalstring=url_subst($finalstring,"{meta:$key}",$metadata->{$key});
#	} else {
#		print "-WARNING: Unable to find metadata for substitution {meta:$key}.\n";
#		$finalstring=url_subst($finalstring,"{meta:$key}",'');
#	}
#}
#print "substituting: made '$finalstring' from '$checkfile'.\n" if($debug);

$finalstring=$store->substitute_string($checkfile);

if($invert){
	print STDERR "INFO: waiting for file '$finalstring' to NOT exist\n";
} else {
	print STDERR "INFO: waiting for file '$finalstring' to exist\n";
}

my $starttime=time;

while(not have_file($finalstring,$exact,$invert,$debug)){
	print STDERR "INFO: waiting for file '$finalstring'.\n";
	my $duration=time-$starttime;
	print "debug: waited for $duration seconds out of ".$ENV{'timeout'}."\n" if($debug);
	if($duration>$ENV{'timeout'}){
		print "-ERROR: Giving up after waiting for ".$ENV{'timeout'}." seconds.\n";
		exit 1;
	}
	sleep $polltime;
}

print "+SUCCESS: Found file.\n";
exit 0;
