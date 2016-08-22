#!/usr/bin/perl

use File::Basename;
use File::Temp;
use CDS::Datastore;

#VERSION=$Rev: 1006 $ $LastChangedDate: 2014-09-05 14:34:12 +0100 (Fri, 05 Sep 2014) $

#This script is a CDS method to upload files using the s3cmd utility
#You should set up the s3cmd utility config file before running this method
#by running s3cmd --configure from the Terminal.  Otherwise it will fail because it does not
#have the relevant login keys available.
#
#You have the option to specify an alternate configuration file in the route, to support multiple
#configurations
#
#Arguments:
# <take-files>{media|meta|inmeta|xml} - upload these files
# <bucket> bucketname				- upload to this S3 bucket
# <upload_path>/upload/path/in/bucket [optional] - upload to this path within the bucket
#
# <config-file>/path/to/config	[optional]- use this config file for s3cmd
# <dry_run/>	[optional]			- runs s3cmd with the --dry-run option
# <encrypt/>	[optional]			- runs s3cmd with the --encrypt option
# <force/>		[optional]			- runs s3cmd with the --force option
# <recursive/>	[optional]			- runs s3cmd with the --recursive option
# <acl_public/>	[optional]			- runs s3cmd with the --acl-public option
# <acl_private/> [optional]			- runs s3cmd with the --acl-private option
# <mime_type>type [optional]		- tell s3cmd that the objects to upload have this MIME type
# <verbose/>	[optional]			- tell s3cmd to be verbose
# <follow_symlinks/> [optional]		- tell s3cmd to follow symlinks as files
#
# <extra_files>file1|file2|{media:url}|... - add the following files to the upload list.  Substitutions are accepted
# <recurse_m3u/> [optional]			- interrogate any m3u8 HLS manifests found and add their contents to the processing list.  Expects <basepath> to be set
# <basepath>/path/to/m3u8/contents	- use this path to find the contents that the HLS manifests are pointing to.  In order to upload an HLS rendition, it's assumed that all of the bits must be held locally.... So we remove the http://server.name.com/ part of the URL and replace with the contents of this parameter (substitutions accepted) in order to find them to upload.

#END DOC

our $debug;

sub read_m3u {
my($filename,$basepath)=@_;
#$debug=1;

my @urls;

print "read_m3u: new file\n---------------\n" if $debug;

open $fh,"<$filename" or sub { print "Unable to open file.\n"; return undef; };

my @lines=<$fh>;

foreach(@lines){
	#print "$_\n"
	#if($debug);
	if(not /^#/){
		chomp;
		#fixme: there should possibly be a more scientific test than this!!
		if(/^http:/){
			if(/\/([^\/]+\/[^\/]+)$/){
				my $filename="$basepath/$1";
				push @urls,$filename;
				print "debug: read_m3u: got filename $filename.\n";
			}
		}
	}
}
print "------------------\n" if $debug;
close $fh;
#print Dumper(\@urls);
return @urls;
}

sub interrogate_m3u8 {
my ($url,$basepath)=@_;

my @contents;
my @urls;
my $filename;

print "INFO: interrogating url at $url.\n";

if($url=~/^http:/){	#we've been passed a real URL.  Assume that any contents is in subdirs relative to $basepath.
	if($url=~/\/([^\/]+\/[^\/]+)$/){
		$filename="$basepath/$1";
		print "debug: interrogate_m3u - got 'real' file at $filename.\n";
	} else {
		print "debug: interrogate_m3u - URL $url doesn't look like it corresponds to something in $basepath.\n";
	}
} else {
	$filename=$url;
}

if(-f $filename){
	@contents=read_m3u($filename,$basepath);
	foreach(@contents){
		#print "$_\n";
		push @urls,$_;
		my @supplementary_urls=interrogate_m3u8($_,$basepath) if(/\.m3u8$/);
		push @urls,@supplementary_urls;
	}
} else {
	print "-WARNING: Unable to find file '$filename'.\n";
}
#print Dumper(\@urls);
return @urls;
}

sub do_upload
{
my($targetfile,$s3_bucket,$s3_path,$s3_opts)=@_;

my $filebase=basename($targetfile);

	my $cmd;
	if($s3_path){
		$cmd="s3cmd $s3_opts put \"$targetfile\" \"s3://$s3_bucket/$s3_path/$filebase\"";
	} else {
		$cmd="s3cmd $s3_opts put \"$targetfile\" \"s3://$s3_bucket/$filebase\"";
	}
	print "I will run $cmd" if($ENV{'debug'});
	#TEMPFILE=`mktemp -t s3_put_simple`
	my $fh=File::Temp->new;
	my $tempfile=$fh->filename;
	#ok, ok, I know this is ugly...
	system("$cmd | tee $tempfile");
	#s3cmd ${S3_OPTS} put $1 s3://${S3_BUCKET}/${S3_PATH}/`basename "$1"` | tee ${TEMPFILE}
	system("grep -e \"^ERROR:\" $tempfile");
	if($?==0){
		print STDERR "-ERROR: Problem uploading to S3";
		return 0;
	} else {
		return 1;
	}
}

sub check_args
{

foreach(@_){
	unless($ENV{$_}){
		print "-ERROR - You must specify <$_> in the route file configuration.  Consult the s3_put section in the CDS methods documentation if you are unsure as to what to use.\n";
		exit 1;
	}
}
return 0;
}

#START MAIN

check_args(qw/bucket/);
my $store=CDS::Datastore->new('s3_put');

my $s3_bucket=$store->substitute_string($ENV{'bucket'});

my $s3_path;
if($ENV{'upload_path'}){
	$s3_path=$store->substitute_string($ENV{'upload_path'});
} else {
	$s3_path="";
}

foreach(qw/dry_run encrypt force recursive acl_public verbose follow_symlinks/){
	my $cds_arg=$_;
	my $cl_arg=$_;
	$cl_arg=~s/_/-/g;
	$s3_opts=$s3_opts." --$cl_arg" if($ENV{$cds_arg});
}

if($ENV{'mime_type'}){
	my $type=$store->substitute_string($ENV{'mime_type'});
	if($type=~/^([^ \|&;]+).*/){
		$type=$1;
	}
	$s3_opts=$s3_opts." --mime-type=$type";
}

#if [ "${dry_run}" != "" ]; then
#	S3_OPTS="${S3_OPTS} --dry-run"
#fi
#if [ "${encrypt}" != "" ]; then
#	S3_OPTS="${S3_OPTS} --encrypt"
#fi
#if [ "${force}" != "" ]; then
#	S3_OPTS="${S3_OPTS} --force"
#fi
#if [ "${recursive}" != "" ]; then
#	S3_OPTS="${S3_OPTS} --recursive"
#fi
#if [ "${acl_public}" != "" ]; then
#	S3_OPTS="${S3_OPTS} --acl-public"
#fi
#if [ "${acl_private}" != "" ]; then
#	S3_OPTS="${S3_OPTS} --acl-private"
#fi
#if [ "${mime_type}" != "" ]; then
#	REAL_MIME=`${DATASTORE_ACCESS} subst "${mime_type}"`
#	S3_OPTS="${S3_OPTS} --mime-type=${REAL_MIME}"
#fi
#if [ "${verbose}" != "" ]; then
#	S3_OPTS="${S3_OPTS} --verbose"
#fi
#if [ "${follow_symlinks}" != "" ]; then
#	S3_OPTS="${S3_OPTS} --follow-symlinks"
#fi

$s3_opts=$s3_opts." --progress";

my @files;
foreach(qw/media meta inmeta xml/){
	push @files,$ENV{'cf_'.$_.'_file'} if($ENV{'cf_'.$_.'_file'});
}

foreach(split /\|/,$ENV{'extra_files'}){
	print "extra file=$_\n" if($debug);
	push @files,$store->substitute_string($_);
}

if(defined $ENV{'basepath'}){
	$basepath=$store->substitute_string($ENV{'basepath'});
	unless(-d $ENV{'basepath'}){
		print "-WARNING: Unable to find the path '".$basepath."' specified as <basepath> in the route file.\n";
	}
}

#my $delay;
#if($ENV{'retry-delay'}){
#	$delay=$ENV{'retry-delay'};
#} else {
#	$delay=5;
#}

if(defined $ENV{'recurse_m3u'}){
	if(not defined $ENV{'basepath'}){
		print "-WARNING: <recurse_m3u/> specified in route file but <basepath> has not been set.  Assuming that basepath is '".$ENV{'PWD'}."'.  Expect problems.\n";
		$basepath=$ENV{'PWD'};
	}
	foreach(@files){
		my @extra_files=interrogate_m3u8($_,$basepath) if($_=~/\.m3u8$/);
		push @files,@extra_files;
	}
}

if(scalar @files<1){
	print "-ERROR: No files to upload!\n";
	exit 0;
}

my $to_upload=scalar @files;
print "INFO: Files to upload:\n";
foreach(@files){
	print "\t$_\n";
}

my $failures=0;

foreach(@files){
	my $rtn=do_upload($_,$s3_bucket,$s3_path,$s3_opts);
	++$failures unless($rtn);
}

print "$failures / $to_upload uploads failed.\n";
if($failures==$to_upload){
	print "-ERROR: No files succeeded in upload.\n";
	exit 1;
}
if($failures==0){
	print "+SUCCESS: $to_upload files correctly uploaded\n";
	exit 0;
}
print "-WARNING: only ".$to_upload-$failures." files uploaded.\n";
exit 0;
