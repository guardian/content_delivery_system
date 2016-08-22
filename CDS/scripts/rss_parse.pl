#!/usr/bin/perl

my $version='$Rev: 652 $ $LastChangedDate: 2014-01-01 17:10:27 +0000 (Wed, 01 Jan 2014) $';

#This script parses an RSS feed XML that is passed in as the route's XML file (it will usually have been downloaded with the http_get method)
#It is assumed that the XML feed contains links to media files that need downloading and processing, as well as their metadata.
#It will download the media files it finds into a cache location and then it will put the route into batch mode to process everything in turn.
#This was originally written to parse RSS data from CNBC.
#
#The XML is interpreted by means of XPath expressions specified in the route file.  This means that in order to set this method up, you need to have a sample copy of the RSS XML feed to hand and a working knowledge of XPath. You may find this link handy: http://www.w3schools.com/xpath/xpath_intro.asp .  It is also possible to download tools to visually help you to work out the necessary xpath expressions.
#
#Arguments:
#  <find-media-at>[xpath] - find the media links at the given place in the XML
#  <find-format-at>[xpath] - find the media format specifiers at the given place in the XML
#  <find-media-delimiter>[character] - the XML file uses this character to delimit the media formats
#  <format-preference>format-name1|format-name2... - by preference, use only media with the given format names in the document
#  <output-directory>/path/to/cache - download media files to this location (substitutions encoraged!)
#  <get-media/> - tells the method to download media links it comes across and get the route to process them
#  <set-xml/> - tells the method to output the extracted metadata for each media link into an XML file and set it as the corresponding xml file for the batch processing
#  <include-generic-xml/> - tells the method to include "generic" information about the feed in each of the output XML files
#
#Example:
#LITERAL
#<input-method name="rss-parse">
#<take-files>xml</take-files>
#<!-- this value is actually an XPATH WITHIN the item object -->
#<find-media-at>metadata:formatLink</find-media-at>
#<!-- ditto.  If this is the same then assume that the XPATH gives us a delimited list -->
#<find-format-at>metadata:formatLink</find-media-at>
#<find-media-delimiter>|</find-media-delimiter>
#<!-- We will only download an encoding that has ONE of these as ONE of the delimited sections, automatically
#detecting which delimited section is a URL -->
#<format-preference>mpeg4_1100000_Download|mpeg4_500000_Download</format-preference>
#<!-- this will be created if it doesn't exist already -->
#<output-directory>/Volumes/MediaTransfer/Raw Agency Feeds/CNBC/media/{year}{month}{day}</output-directory>
#<!-- this tells us to download the media URL and set it to cf_media_file [we set batch mode]-->
#<get-media/>
#<!-- this tells us to create a corresponding XML file for the item containing the metadata, untranslated from the RSS feed -->
#<!-- the XML file is given the same name as the corresponding media file -->
#<set-xml/>
#<!-- this tells us to include the "header" portion of the RSS in each output XML file -->
#<include-generic-xml/>
#</input-method>
#<!-- the rss-parse method should now have put us into batch mode.  We can now transcode etc. -->
#END LITERAL
#END DOC

use XML::XPath;
use XML::XPath::Parser;
use Data::Dumper;
use LWP::Simple;
use CDS::Datastore;
use File::Path qw /make_path/;
use File::Spec;

sub get_media_refs
{
my($commonRefPath,$mediaRefPath,$formatRefPath,$formatDelimiter,$item,$xp)=@_;

my %mediaRefsList;

my $mediaRef;
my $formatRef;
	
#print Dumper($item);
if($commonRefPath){
	my $pathNodes=$xp->find($mediaRefPath,$item);
	#print Dumper($pathNodes->get_nodelist);
	foreach my $node ($pathNodes->get_nodelist){
		my $path=$node->string_value; #XML::XPath::XMLParser::as_string($node);
		#print "debug: $path\n";
	
		my @parts=split /$formatDelimiter/,$path;
		for(my $n=0;$n<scalar @parts;++$n){
			if($parts[$n]=~/^[a-zA-Z0-9]+:\/\//){	#this looks like a URL
				if($n>0){
					$formatRef=$parts[$n-1];
					$mediaRef=$parts[$n];
				} else {
					$formatRef=$parts[$n];
					$mediaRef=$parts[$n+1];
				}
			}
		}
		print "debug: got media reference $mediaRef from $mediaRefPath and format reference $formatRef from $formatRefPath\n" if($debug);
		#push @mediaRefsList,{ $formatRef=>$mediaRef,'formatRef'=>$formatRef };
		$mediaRefsList{$formatRef}=$mediaRef;
	}
} else {
	$mediaRef=$xp->findvalue($mediaRefPath,$item);
	$formatRef=$xp->findvalue($formatRefPath,$item);
}

return \%mediaRefsList;
}

sub escape_delimiter
{
my($v)=@_;

$v=~s/\|/\\\|/;
return $v;
}

sub output_xml
{
my($item,$filename)=@_;

return undef unless($item);
open $fh,">:utf8",$filename;
unless($fh){
	print STDERR "-ERROR: Unable to open $filename to output XML.\n";
	return undef;
}
print $fh "<?xml version=\"1.0\"?>\n\n";
print $fh XML::XPath::XMLParser::as_string($item);
close $fh;
return 1;
}

sub check_args
{

foreach(@_){
	unless($ENV{$_}){
		print "-ERROR: You must specify <$_> in the routefile.\n";
		exit 1;
	}
}
}

sub get_filename_from_url
{
my $url=shift;

if($url=~/\/([^\/]+)$/){
	return $1;
} elsif($url=~/\/([^\/]+)\/$/){
	return $1;
}
return undef;
}

#START MAIN
my $inputRssFile=$ENV{'cf_xml_file'};
unless(-f $inputRssFile){
	print STDERR "Input file '".$ENV{'cf_xml_file'}."' could not be found.  Ensure that <take-files>xml</take-files> is set in the route file.\n";
	exit 1;
}

my $store=CDS::Datastore->new('rss_parse');

print STDERR "*INFO: Reading from '$inputRssFile'...\n";
check_args(qw/find_media_at find_format_at format_preference/);

$debug=$ENV{'debug'};

my $mediaRefPath=$store->substitute_string($ENV{'find_media_at'});
my $formatRefPath=$store->substitute_string($ENV{'find_format_at'});
my $formatDelimiter=escape_delimiter($ENV{'find_media_delimiter'});
my $commonRefPath=1 if($mediaRefPath eq $formatRefPath);

my @wantedFormats=split /\|/,$store->substitute_string($ENV{'format_preference'});

my $outputPath=$store->substitute_string($ENV{'output_directory'});
my $doGetMedia=$ENV{'get_media'};
my $doSetXML=$ENV{'set_xml'};
my $doIncludeGeneric=$ENV{'include_generic_xml'};

my $xp=XML::XPath->new(filename=>$inputRssFile);
unless($xp){
	print STDERR "Unable to read '".$ENV{'cf_xml_file'}."\n";
	exit 1;
}

#ok, now we should have the RSS read in get an array of items
my $successfullyDownloaded=0;
my $downloadErrors=0;
my @processedFiles;

my $itemNodes=$xp->find('/rss/channel/item');
ITEM_LOOP: foreach my $item ($itemNodes->get_nodelist){
	my $selectedFormat;
	
	my $mediaRefs=get_media_refs($commonRefPath,$mediaRefPath,$formatRefPath,$formatDelimiter,$item,$xp);
	
	print STDERR "*INFO: Got item '".$xp->findvalue('title',$item)."'\n";
	print STDERR Dumper($mediaRefs) if($debug);
	FMT_SEARCH_LOOP: foreach(@wantedFormats){
		if($mediaRefs->{$_}){
			$selectedFormat=$_;
			last FMT_SEARCH_LOOP;
		}
	}
	unless($selectedFormat){
		print STDERR "-WARNING: Item '".$xp->findvalue('title',$item)."' does not have any preferred media formats.\n";
		next ITEM_LOOP;
	}
	#print "debug: got media reference $mediaRef from $mediaRefPath and format reference $formatRef from $formatRefPath\n";

	my $localMediaFilename=get_filename_from_url($mediaRefs->{$selectedFormat});
	my $outputFile=File::Spec->catfile($outputPath,$localMediaFilename);
	my $outputXML;
	if($outputFile=~/^(.*)\.[^\.]+$/){
		$outputXML=$1.".xml";
	} else {
		$outputXML=$outputFile.".xml";
	}

	if($doGetMedia and $outputPath){
		print "Downloading '".$mediaRefs->{$selectedFormat}."' to $outputFile...";
		STDOUT->flush();
		make_path($outputPath);
		if(getstore($mediaRefs->{$selectedFormat},$outputFile)){
			push @processedFiles,$outputFile;
			++$successfullyDownloaded;
			print "done.\n";
		} else {
			print STDERR "\n-WARNING: Unable to download '".$mediaRefs->{$selectedFormat}."' to '$outputFile'\n";
			++$downloadErrors;
		}
	} else {
		print "INFO: Not downloading '".$mediaRefs->{$selectedFormat}."'.  If you want to download media files, set <get_media/> and <output_directory> in the route file.\n";
	}
	if($doSetXML and $outputPath){
		print "Outputting metadata to $outputXML...\n";
		output_xml($item,$outputXML);
		push @processedFiles,$outputXML;
	} else {
		print "INFO: Not outputting metadata.  If you want to output metadata, then ensure that <set_xml/> and <output_directory> are set in the route file.\n";
	}
	
	print "\n\n";
}

print "INFO: Successfully downloaded $successfullyDownloaded files and had $downloadErrors errors.\n";
if($doGetMedia){
	if($successfullyDownloaded<1){
		print "-ERROR: No files were downloaded or processed.\n";
		exit 1;
	}
	if($downloadErrors>0){
		print "-WARNING: Some files were not downloaded correctly.  Continuing to process those that were.\n";
	}
}

if($debug){
	print STDERR "Dump of processed files:\n";
	print STDERR Dumper(\@processedFiles);
}

open $tempFile,">:utf8",$ENV{'cf_temp_file'};
if($tempFile){
	#tell CDS we want batch mode
	print $tempFile "batch=true\n";
	foreach(@processedFiles){
		print $tempFile "$_\n";
	}
	close $tempFile;
} else {
	print "-ERROR: Unable to output file list to temp file '".$ENV{'cf_temp_file'}."'\n";
	exit 1;
}

print "+OK: Completed successfully.\n";
