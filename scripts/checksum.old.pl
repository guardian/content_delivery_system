#!/usr/bin/perl
$|=1;
#DEPRECATED CDS IMPLEMENTATION DO NOT USE
#END DOC

# checksum.pl
#

#usage: checksum <.meta file>
#checksums corresponding media file - worked out by extracting the file name(s) from the passed .meta file

#configurable parameters
$use_full_path=1;
#end configurable parameters

$script_name="checksum.pl";

use Data::Dumper;
use Digest::SHA1;
use Digest::MD5;
use CDS::Datastore;

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

#START MAIN
$metafile=$ARGV[0];

print "MESSAGE: In Checksummer.\n";
my $store=CDS::Datastore->new('checksum');

if($ENV{'debug'}){
	print "Input args:\n";
	print Dumper(\%ENV);
	print "----------------------\n";
}

#if($metafile eq "")
#{
	# get meta file name from environment
	
#	$metafile = $ENV{'cf_meta_file'};
	
#	if($metafile eq "")
#	{
#		print STDERR "-FATAL: meta file not available\n";
#		exit 1;
#	}
#}

#($fh, $tempfile)=File::Temp::tempfile();
#open FH_INMETA,"<$metafile" or die "-FATAL: Couldn't open metafile '$metafile'\n";

my $generateMd5 = $ENV{'md5'};

my $generateSha = $ENV{'sha1'};

my $mediafile=$store->get('media','filename');
my $path=$store->get('media','path');
my $mediafile="$path/$mediafile";

($sha1_string, $md5_string) = &get_checksums($mediafile,$generateMd5,$generateSha);
$store->set('media','sha1',$sha1_string,'md5',$md5_string,undef);

if($ENV{'debug'}){
	print "Got SHA1 $sha1_string and MD5 $md5_string from file '$mediaFile'\n";
}

#print STDERR "MESSAGE: $script_name: Reading from $metafile\n";
#print STDERR "MESSAGE: $script_name: Outputting to $tempfile\n";

#@lines=<FH_INMETA>;
#foreach(@lines){
#	print { $fh } $_;
#	if(/^\s*<meta name=\"movie\" value=\"file:\/\/([\w\d%_\/\.]+)/){
#		$mediafile=$1;
		#$mediafile=~s/%20/ /g;
		#Translate any %char-value expressions back into characters so that we can open the file
#		my $n=0;
#		while($mediafile=~/%([\dA-Fa-f]{2})/){
#			++$n;
#			my $char=chr hex $1;
#			$mediafile=~s/%$1/$char/g;
#			die "-FATAL: Program error: excessive iterations replacing escaped chars.  [$1,$char] String so far: '$mediafile'\n" if($n>2000);
#		}
#		print "MESSAGE: Got mediafile '$mediafile'\n";

#		if(
#		if($generateMd5)
#		{
#			print { $fh } "\t\t<meta name=\"sha1\" value=\"$sha1_string\"/>\n";
#		}
		
#		if($sha1)
#		{
#			print { $fh } "\t\t<meta name=\"md5\" value=\"$md5_string\"/>\n";
#		}
#	}
#}

#close FH_INMETA;
#close $fh;

#print STDERR "MESSAGE $script_name: Renaming $tempfile to $metafile\n";
#unlink $metafile;
#move($tempfile,$metafile);

