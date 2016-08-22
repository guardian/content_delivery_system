#!/usr/bin/perl
$|=1;
my $version='$Rev: 514 $ $LastChangedDate: 2013-09-24 13:13:20 +0100 (Tue, 24 Sep 2013) $';

$script_name="checksum.pl $version";

#This is a module to calculate SHA1 and/or MD5 checksums of given
#files in a CDS route
#Arguments:
#
# <take-files>{media}|{xml}|{inmeta}|{meta} - checksum these files
# <extra-files>file1.mp4|{media:filepath}|/path/to/{meta:random_file} - add the following to list (with substitutions)
# <search-paths>/path/one|{meta:basepath}/path/two|{media:filepath} - search the following for files if not found (with substitutions)
# <sha1/> - provide SHA1
# <md5/> - provide MD5
# <sha1-keys>output_key1|media:output_key2|{filename}_key3 [OPTIONAL] - output sha1 checksums to the following keys.  Used in this order:
#     media,inmeta,meta,xml,extra1,extra2....
#     if a file isn't specified then ignore it, so if no inmeta/meta 2nd arg is output for xml.
#     supports a special substitution of {filename}, i.e. the current filename.
#     defaults to {type}:sha1 - e.g. media:sha1,xml:sha1 or {filename}:sha1 for extra-files
#	  if only one file is input then also duplicated to {media:sha1}
# <md5-keys> [OPTIONAL] - as above but for md5

#END DOC

#configurable parameters
$use_full_path=1;
#end configurable parameters

$script_name="checksum.pl";

use Data::Dumper;
use Digest::SHA1;
use Digest::MD5;
use CDS::Datastore;
use File::Basename;

sub get_checksums {
my $mediafile=shift;
my $generateMd5=shift;
my $generateSha=shift;

if($use_full_path==0){
	@path_bits=split(/\//,$mediafile);
	$mediafile=$path_bits[(scalar $path_bits)-1];
}

open FH,"<$mediafile" or die "Couldn't open file '$mediafile'\n";
binmode FH;

if($generateSha){
	print STDERR "MESSAGE: $script_name: Calculating SHA1 for file '$mediafile'...";
	$sha1=Digest::SHA1->new;
	$sha1->addfile(FH);
	$sha1_string=$sha1->hexdigest;
	seek(FH,0,SEEK_SET);
}
if($generateMd5){
	print STDERR "\nMESSAGE: $script_name: Calculating MD5 for file '$mediafile'...";
	$md5=Digest::MD5->new;
	$md5->addfile(FH);
	$md5_string=$md5->hexdigest;
}
	
print STDERR "\nMESSAGE: Done.\n";
close FH;
return ($sha1_string, $md5_string);
}

sub find_file {
my ($basename,$pathlist)=@_;

foreach(@$pathlist){
	my $path_to_test="$_/$basename";
	print "find_file: checking $path_to_test\n" if($debug);
	if(-f $path_to_test){
		print "find_file: found.\n" if($debug);
		return $path_to_test;
	}
}
print "WARNING: find_file unable to find $basename in any of @$pathlist\n";
return undef;
}

sub get_from_envs {

my @rtn;
foreach(@_){
	print "$_=".$ENV{$_}."\n";
	push @rtn,$ENV{$_} if($ENV{$_});
}

return @rtn;
}

sub is_section {
my $item=shift;

return 1 if($item=='media' or $item=='meta' or $item=='track');
return 0;
}

#START MAIN
#START MAIN
print "MESSAGE: In Checksummer v2.\n";
my $store=CDS::Datastore->new('checksum');

$debug=$ENV{'debug'};

my $search_path_string=$store->substitute_string($ENV{'search_paths'});
my @search_paths=split /\|/,$search_path_string;

print "Search paths: ".Dumper(\@search_paths)."\n" if($debug);

my $do_md5=1 if($ENV{'md5'});
my $do_sha1=1 if($ENV{'sha1'});

if(not $do_md5 and not $do_sha1){
	print "-ERROR: Neither MD5 nor SHA1 requested.\n";
	exit 1;
}

#first, group together all of the files we'll need
my @initial_file_list=get_from_envs(qw/cf_media_file cf_inmeta_file cf_meta_file cf_xml_file/);

my $extra_file_string=$store->substitute_string($ENV{'extra_files'});
push @initial_file_list,split /\|/,$extra_file_string;

#now make sure that we have them all.
my @final_file_list;
foreach(@initial_file_list){
	if(-f $_){
		push @final_file_list,$_;
	} else {
		my $actual_path=find_file(basename($_),\@search_paths);
		push @final_file_list,$actual_path if($actual_path);
	}
}

if(scalar @final_file_list < 1){
	print "-ERROR: No existing files given to work on.\n";
	exit 1;
}

my @output_keys;

if($ENV{'sha1_keys'}){
	@sha1_keys=split /\|/,$ENV{'sha1_keys'};
}
if($ENV{'md5_keys'}){
	@md5_keys=split /\|/,$ENV{'md5_keys'};
}

my $single_file=1 if(scalar @final_file_list==1);
my $n=0;

foreach(@final_file_list){
	my $basename=basename($_);
	my ($sha1string,$md5string)=get_checksums($_,$do_md5,$do_sha1);
	
	#now to sort out where we're putting them.
	my $sha1key,$md5key;
	
	if($sha1_keys[$n]){
		$sha1key=$sha1_keys[$n];
		$sha1section='media';
		if($sha1key=~/^([^:]+):/){	#has the user specified a section for the key
			$sha1section=$1 if(is_section($1));
		}
		$sha1key=~s/{filename}/$basename/;
	} else {
		$sha1key="$basename:sha1";
		$sha1section='media';
	}
	
	print "outputting SHA1 to {$sha1section:$sha1key}\n";
	
	if($md5_keys[$n]){
		$md5key=$md5_keys[$n];
		$md5section='media';
		if($md5key=~/^([^:]+):/){	#has the user specified a section for the key
			$md5section=$1 if(is_section($1));
		}
		$md5key=~s/{filename}/$basename/;
	} else {
		$md5key="$basename:md5";
		$md5section='media';
	}
	
	print "outputting MD5 to {$md5section:$md5key}\n";
		
	$store->set($sha1section,$sha1key,$sha1string) if($sha1string);
	$store->set($md5section,$md5key,$md5string) if($md5string);
	
	if($single_file){
		print "also outputting to media:sha1 and media:md5\n";
		$store->set('media','sha1',$sha1string,'md5',$md5string);
	}
	++$n;
}

print "checksummer completed successfully.\n";
exit 0;
