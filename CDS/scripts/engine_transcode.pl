#!/usr/bin/perl
$|=1;
my $version='$Rev: 517 $ $LastChangedDate: 2013-10-07 12:07:00 +0100 (Mon, 07 Oct 2013) $';

#This method encodes a file via Episode Engine, also handling metadata issues.
#Metadata from the datastore is output to a .inmeta file for encoding, and metadata from the output .meta file is read back into the datastore at the end.
#Arguments:
# <output-profile>profile_name - use this watchfolder for encoding.  The source file will be placed in ${EPISODE_INPUT_ROOT}/profile_name, and the encoded file will be waited for at ${EPISODE_OUTPUT_ROOT}/profile_name.  The subdirectory should contain only one output profile at present. ${EPISODE_INPUT_ROOT} and ${EPISODE_OUTPUT_ROOT} must be set by altering the static configuration lines in the script itself at /usr/local/lib/cds_backend/engine_transcode.pl
# <warn-time>nnnn - wait for this number of seconds before we start outputting warnings that the file hasn't been seen
# <fail-time>nnnn - wait for this number of seconds before giving up and deciding that the file is never coming.  This will emit an error to cds_run, and terminate the route unless <nonfatal/> is set.
# <enforce-underscore-only/> - ensure that there are no - characters etc. in the filename. For improving compatibility, e.g. with GNM Octopus.
# <ignore-file-extensions>jpg|JPG|tif|TIF.... etc. - if the media-file has one of these extensions, don't transcode it.  For use in feeds where e.g. stills are present.
# <holding-path>/path/to/graveyard - if something fails, move the remnants to this location
# <keep-original/> - copy, instead of move, the source file into Episode
# <symlink/> - use a symlink instead of a copy/move to input the source file.  Improves reliability and speed, but only really useful in a SAN-based system where the file paths are the same for all clients and servers so the symlink will always resolve.
# 

#END DOC

require 5.008008;
#use strict;
use warnings;

use File::Basename;
use File::Copy;
#use FastGlob qw(glob);
sub isFileTranscoded;

#use XML::SAX;
#use Template;
use Data::Dumper;
#use lib "/usr/local/bin";
#use saxmeta;
use CDS::Datastore::Episode5;

print "\nMESSAGE: Perl script engine_transcode invoked\n";

#start up the data store
my $store=CDS::Datastore::Episode5->new('engine_transcode') or die "-FATAL: Unable to access data store.\n";

my $outputProfile = $store->substitute_string($ENV{'output-profile'});
my $warnTime = $ENV{'warn-time'}; 
my $failTime = $ENV{'fail-time'}; 

my $enforce_octopus=$ENV{'enforce-underscore-only'};

my $ignoreXtnList= $ENV{'ignore-file-extensions'};
my @ignoreList=split /\|/,$ignoreXtnList if defined $ignoreXtnList;

my $graveyardPath = $store->substitute_string($ENV{'holding-path'});

my $keepOriginal;

if(defined($ENV{'keep-original'}))
{
	$keepOriginal = $ENV{'keep-original'};	
}
else
{
	$keepOriginal = "false";	
}

my $trancodedFileExtension;
my $transcodedFileName;
my $fileName;
my $inmetaFile;

my $rootPathCopyTo = "/Volumes/MediaTransfer/Episode Input/";
my $rootPathOutput = "/Volumes/MediaTransfer/Episode Output/";
my $rootPathArchive = "/Volumes/MediaTransfer/Episode Archive/";
my $rootArchivePath = "/Volumes/MediaTransfer/UploaderArchive/";

#Modifications by Andy G.  Since Episode Engine .meta files do not have entities properly encoded,
#we extract the incoming data keys from the .inmeta and over-write them in the output .meta.
#We therefore need to rreference the meta.tt output template in order to output a valid .meta file.
#my $template_path="/etc/cds_backend/templates";
#my $output_template=$template_path."/meta.tt";
#hash reference for the data
#my $inmeta_keys;


my $debugLevel = 10;


unless ( -d $rootPathCopyTo)
{
	print STDERR "-FATAL: episode engine folder '$rootPathCopyTo' does not exist\n";
	exit 1;
}
unless ( -d $rootPathOutput)
{
	print STDERR "-FATAL: episode engine folder '$rootPathOutput' does not exist\n";
	exit 1;
}
else
{
	#$rootPathCopyTo = $rootPathCopyTo . "/";
	#$rootPathOutput = $rootPathOutput . "/";

	my $sourceMediaFile;
	
	unless ($outputProfile && $warnTime && $failTime && $ENV{'cf_media_file'})
	{
		print STDERR "-FATAL: required arguments missing\n";
		print STDERR "outputProfile=$outputProfile, warnTime=$warnTime, failTime=$failTime, mediaFile=".$ENV{'cf_media_file'}."\n";
		exit 1;
	}
	
	$sourceMediaFile = $ENV{'cf_media_file'};		
	my $sourceMetaFile = $ENV{'cf_inmeta_file'};

	unless ( -e $sourceMediaFile)
	{
		print STDERR "-FATAL: media file $sourceMediaFile does not exist\n";
		exit 1;
	}

#	if( $sourceMetaFile ne "")
#	{
#        unless ( -e $sourceMetaFile)
#        {
#        	print STDERR "-FATAL: meta-file $sourceMetaFile does not exist\n";
#            exit 1;
#        }
        
        #Modification by Andy G.  Episode Engine has a nasty bug whereby it removes entities
        #from a .inmeta XML and does not put them back when it outputs a .meta, breaking
        #any standards-based XML parser that tries to read it.
        #Therefore, we read the data out of the inmeta files here and put it back, using a template,
        #once the transcode operation is complete.
#        print STDOUT "*MESSAGE: Reading in metadata from $sourceMetaFile...\n";
#        $inmeta_keys=read_inmeta_info($sourceMetaFile);
#        print STDOUT "+SUCCESS: Metadata read in.\n" if defined $inmeta_keys;
#        print Dumper($inmeta_keys) if $debugLevel>1;
#	}
	
	if(defined $ignoreXtnList and isInIngoreList($sourceMediaFile,@ignoreList))
	{
		print STDERR "-WARNING: file '$sourceMediaFile' is being ignored due to file extension";
	}
	else
	{
		$fileName = fileparse($sourceMediaFile);
	
		my $destFileName = $rootPathCopyTo . $outputProfile . "/".  $fileName;
	
		if(defined $ENV{'symlink'}){
			system("ln -s \"$sourceMediaFile\" \"$destFileName\"");
			if(! -f $destFileName){
				print STDERR "-FATAL: Unable to create a symlink from $sourceMediaFile to $destFileName\n";
				exit 1;
			}
		}elsif($keepOriginal eq "true")
		{
			unless(copy ($sourceMediaFile, $destFileName))
			{
				print STDERR "-FATAL: file failed to copy to location\n";	
				exit 1;			
			}
		}
		else
		{
			unless(move ($sourceMediaFile, $destFileName))
			{
				print STDERR "-FATAL: file failed to move to location\n";	
				exit 1;			
			}		
		}		

		$transcodedFileName = $rootPathOutput . $outputProfile . "/".  $fileName;

		#Now we have the datastore, we don't rely on cf_inmeta_file.
		#We use CDS::Datastore::Episode5 to create one on the fly from the
		#contents of the datastore
		my $inmetaOutputName=basename($sourceMediaFile).".inmeta";
		$destFileName=$rootPathCopyTo.$outputProfile."/".$inmetaOutputName;
		$store->export_inmeta($destFileName);

#	    $fileName = fileparse($sourceMetaFile);
#		$destFileName = $rootPathCopyTo . $outputProfile . "/".  $fileName;

#		if($keepOriginal eq "true")
#		{
#			if( $sourceMetaFile ne "" ){
#		        unless(copy ($sourceMetaFile, $destFileName))
#		        {
#		        	print STDERR "-FATAL: meta-file failed to copy to location\n";
#		           	exit 1;
#		        }
#			}
#		}
#		else
#		{
#			if( $sourceMetaFile ne "" ){
#		        unless(move ($sourceMetaFile, $destFileName))
#		        {
#		        	print STDERR "-FATAL: meta-file failed to move to location\n";
#		            exit 1;
#		        }
#			}		
#		}
	
		print STDOUT "MESSAGE: check if file '$sourceMediaFile' has been transcoded\n";
	
		# has the file been created?
		my $startTime=time;
		my $currentTime=time;

		while(not isFileTranscoded($sourceMediaFile))
		{
			sleep(5);
			$currentTime=time;
			if($currentTime-$startTime > $warnTime){
				print STDERR "-WARNING: transcoded media '$transcodedFileName' not available\n";
			}
			if($currentTime-$startTime > $failTime){
	            		print STDERR "-FATAL: transcoded media '$transcodedFileName' not available\n";
 	               	exit 1;
			}
		}	
		
		# SUCCESS	
		print STDOUT "+SUCCESS:media transcoded '$transcodedFileName'\n";
		
	} #if(isInIgnoreList)
	
	# now to archive the media and inmeta file if specifed
	my $archiveFileName = "";
	
	unless(move($sourceMediaFile, $archiveFileName) )
	{
		print STDERR "-WARNING: could not archive media file $sourceMediaFile\n";
	}
	
#	if ($ENV{'cf_inmeta_file'})
#	{
#		$inmetaFile = $ENV{'cf_inmeta_file'};
#		$archiveFileName = "";		
#		unless(move($inmetaFile, $archiveFileName) )
#		{
#			print STDERR "-WARNING: could not archive media file $sourceMediaFile\n";
#		}
#	}
}


# get the file name minus the root and check if any files in the output folder match. 
#
sub isFileTranscoded()
{
	my $filePathOriginal = shift(@_);
	$filePathOriginal=~/\/([^\/]*)$/;
	my $filenameOriginal=$1;
	my $fileNameNoExtension = $filenameOriginal;
	$fileNameNoExtension =~ s/\.[^\.]*$//;
	
	my $searchArgument = $rootPathOutput . $outputProfile . "/".  $fileNameNoExtension . "*";

	# print "DEBUG:glob argument '$searchArgument'\n";
	
	#my @results = glob ($searchArgument);
	my @results = < "$searchArgument" >;
	for(my $n=0;$n<scalar @results;++$n){
		#we're not interested in the result if it's a .meta file - we pick these up seperately
		#"results" in this context only means the media file
		$_=$results[$n];
		if(/\.meta$/){
			splice(@results,$n,1);
			print "DEBUG: removing $_ from results list\n";
		}
	}
	if( @results)
	{
		print "DEBUG: results @results\n" if $debugLevel > 0;
		my $newFileName;
		if($enforce_octopus){
		# store the transcoded media file name in a the temp file
		#we have another potential problem, in that EE _sometimes_ decides to use a - as a seperator to the profile
		#part of the filename, not a _.  This causes problems for Octopus.  So we use a regex to ensure that the - gets changed
		#to a _.
		#the regex means: find me a hyphen, followed by anything that is not a hyphen or period (repeated any number of times, including 0)
		#followed by a period, followed by any number of word or digit characters (i.e. the file extension) followed by the end of the
		#string.  Then replace this with an underscore, followed by the first part captured above, followed by a period, followed by the
		#second part captured above.
			$newFileName=$results[0];
			$newFileName=~s/-([^\-\.]*).([\w\d]*)$/_\1.\2/;
			if($newFileName ne $results[0]){
				print "MESSAGE: Output file ".$results[0]." does not conform to Octopus naming conventions.  Renaming to $newFileName...\n"; 
				move($results[0],$newFileName);
				move($results[0].".meta",$newFileName.".meta") if( -f $results[0].".meta");
			}
		} else {
			$newFileName=$results[0];
		}
		my $tmpFile = $ENV{'cf_temp_file'};		
		print "MESSAGE: Open temp file '$tmpFile' to write name value pairs to.\n";
		my $fileOpenStatus = open CDS_TMP, ">", $tmpFile;

		#read the .meta file into the datastore
		#FIXME: this uses a standards-based XML parser, hence will break when Episode outputs invalid XML.
		#solution - write a truncate_meta which strips out the user-gen section prior to parsing.
		#this can be based on replace_meta_info below.
		#UPDATE: implemented in CDS::Datastore::Episode5.  The second parameter can be set to 'true' to enable
		#this behaviour.
		$store->import_episode("$newFileName.meta",1);

		# a brilliant hack; assuming that only one media file exists...
		# write a name value pair to the text file and that is it.
		print CDS_TMP "cf_media_file=$newFileName\n";
		if(-f "$newFileName.meta"){
			print "INFO: Removing un-needed .meta file $newFileName.meta\n";
			unlink("$newFileName.meta");
		}
#		print CDS_TMP "cf_meta_file=$newFileName.meta\n";
		close CDS_TMP;
		
#		if(-f $results[0].".meta"){
#			print STDOUT "*MESSAGE: Replacing potentially invalid XML in output .meta...\n";
#			replace_meta_info($results[0].".meta",$inmeta_keys);
#		}
	}
	
	my $size = scalar @results;
	
	if ($size > 0)
	{
		return 1;
	}
	else
	{
		return 0;
	}
}

sub isInIngoreList
{
	my($sourceMediaFile,@ignoreList)=@_;
	
	$sourceMediaFile=~/\.([^\.]*)$/;
	my $sourceMediaXtn=$1;
	
	foreach(@ignoreList){
		print "debug: comparing file extension '$sourceMediaXtn' to $_";
		return 1 if($sourceMediaXtn eq $_);
	}
	return 0;
}

#metadata handling functions by Andy
#sub read_inmeta_info {
#	my $filename=shift;
	
#	my $handler=saxmeta->new;
#	$handler->{'config'}->{'keep-simple'}=1;
	#do not change the key names etc.
#	$handler->{'config'}->{'keep-spaces'}=1;

#	my $parser=XML::SAX::ParserFactory->parser(Handler=>$handler);
#	$parser->parse_uri($filename);
#	$parser->{'Handler'}->escape_for_xml;
#	my $content=$parser->{'Handler'}->{'content'};
#	
#	return $content->{'meta'};
#}

#sub replace_meta_info {
#	my ($filename,$inmeta_info)=@_;
#	
#	my $chopped_xml;
#	
#	open FHREAD,"<$filename";
#	my @invalid_xml_lines=<FHREAD>;
#	close FHREAD;
#	
#	my $is_dumping=1;
#		
#	foreach(@invalid_xml_lines){
#		if(/<meta name="meta-source"/){
#			$is_dumping=0;
#		} elsif ($is_dumping==0 and /<\/meta>/){
#			$is_dumping=1;
#		} else {
#			$chopped_xml=$chopped_xml.$_ if($is_dumping);
#		}
#	}
#	
#	print $chopped_xml;
#	#die;
	
	#first read in the .meta file
#	my $handler=saxmeta->new;
#	$handler->{'config'}->{'keep-simple'}=1;
#	#do not change the key names etc.
#	$handler->{'config'}->{'keep-spaces'}=1;
#
#	my $parser=XML::SAX::ParserFactory->parser(Handler=>$handler);
#	#$parser->parse_uri($filename);
#	$parser->parse_string($chopped_xml);
#	$parser->{'Handler'}->escape_for_xml;
#	my $content=$parser->{'Handler'}->{'content'};
#	
#	$content->{'meta'}=$inmeta_info;
#	
#	print Dumper($content) if $debugLevel>1;
#	#Use Template Toolkit to write out the modified data.
#	my $tt=Template->new(ABSOLUTE=>1);
#
#	if(not -f $output_template){
#		print STDERR "-FATAL: Unable to find output template $output_template.\n";
#		exit 4;
#	}
#
#	print "Using output template $output_template.\n";
#	my $output;
#	$tt->process($output_template,$content,\$output);
#	open OUT_FH,">:utf8",$filename;
#	print OUT_FH $output;
#	close OUT_FH;
#}
