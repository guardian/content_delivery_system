#!/usr/bin/php

<?php
/*
#elastic_transcode $Rev: 687 $ $LastChangedDate: 2014-01-22 20:55:56 +0000 (Wed, 22 Jan 2014) $
#Converts the relevant media files via Amazon's Elastic Transcoder.
#Requires the installation of the AWS SDK for PHP. This will be done automatically by
#the installation script if phar etc. are installed
#
#It expects the following arguments:
#  <region>blah - AWS region where the pipeline is
#  <presets>preset name 1|preset name 2|preset name 3 - Presets to use for transcoding
#  <pipeline>blah - Name of the pipeline to submit the job to.
#
#  <output_prefix>blah [optional] - 'prefix', or path specification, for the outputs in the output bin.
#  <filename>blah [optional] - filename of the file to transcode. This is expected to exist in
#the S3 bucket that is designated as the input bucket of the pipeline.  If this is not specified,
#then the media file is used (<take-files>media</take-files>)
#  <key>blah [optional] - AWS access key
#  <secret>blah [optional] - AWS access secret. If key/secret are not specified, then the system
# attempts to use AWS Roles to obtain them
#END DOC
*/

require 'AWSSDKforPHP/aws.phar';
use Aws\ElasticTranscoder\ElasticTranscoderClient;

#FIXME - should look for cds_datastore a bit better than this!
$datastore='/usr/local/bin/cds_datastore.pl';

function substitute_string($inputstring)
{
global $datastore;

$outputstring=`$datastore subst "$inputstring"`;
return $outputstring;
}

function get_extension_for_preset($presetid)
{
global $presetList;

return $presetList[$presetid]['Container'];
}

#START MAIN

$debug=$_ENV['debug'];

if($_ENV['filename']){
	$filename=substitute_string($_ENV['filename']);
} else {
	$filename=pathinfo($_ENV['cf_media_file'], PATHINFO_FILENAME);
}

$region=rtrim($_ENV['region']);
if($region == ""){
	$region='eu-west-1';
}

if($_ENV['key'] and $_ENV['secret']){
	print "Using login credentials from routefile...\n";
	$client = ElasticTranscoderClient::factory( array(
		'key' => rtrim($_ENV['key']),
		'secret' => rtrim($_ENV['secret']),
		'region' => $region
	));
} else {
	print "Attempting to connect using AWS roles...\n";
	$client=ElasticTranscoderClient::factory( array( 'region' => $region ));
}

$presetList=array();
#First thing - get a list of all the preset info
do {
	if($presetInfoPage['NextPageToken']){
		$presetInfoPage=$client->listPresets(array('Ascending'=>"true",'PageToken'=>$presetInfoPage['NextPageToken']));
	} else {
		$presetInfoPage=$client->listPresets(array('Ascending'=>"true"));
	}

	//var_dump($presetInfoPage);
	//die;

	$content=$presetInfoPage['Presets'];

	//var_dump($content);
	//foreach($content as &$lump){
	//	foreach($lump as &$currentPreset){
	foreach($content as &$currentPreset){
		var_dump($currentPreset);
			$name=$currentPreset['Name'];
			$presetList[$name]=$currentPreset;
//		}
	}
//	die;
} while($presetInfoPage['NextPageToken']);

if($debug){
	print "DEBUG: List of presets detected\n";
	var_dump($presetList);
}

die;

$pipelineList=array();
//Next thing - get a list of all the pipeline info
do {
	//FIXME: declare the $pipelineInfoPage variable to prevent warnings when executing
	if($pipelineInfoPage['NextPageToken']){
		$pipelineInfoPage=$client->listPipelines(array('Ascending'=>"true",'PageToken'=>$pipelineInfoPage['NextPageToken']));
	} else {
		$pipelineInfoPage=$client->listPipelines(array('Ascending'=>"true"));
	}

	foreach($pipelineInfoPage as &$currentPreset){
//		var_dump($currentPreset[0]);
		$name=$currentPreset[0]['Name'];
		$pipelineList[$name]=$currentPreset[0];
	}

} while($pipelineInfoPage['NextPageToken']);

/*
if($debug){
	print "\nDEBUG: List of pipelines detected:\n";
	var_dump($pipelineList);
}
*/

$requestedEncodings=explode("|",substitute_string($_ENV['presets']));

if($debug){
	print "\nDEBUG: List of requested encodings:\n";
	var_dump($requestedEncodings);
}

$outputsArray=array();

$n=0;
foreach($requestedEncodings as &$enc){
	++$n;
	//$preset=get_preset_info($enc);
	$preset=$presetList[$enc];
	
	$outputFile=pathinfo($filename, PATHINFO_FILENAME) . "_$n" . get_extension_for_preset($enc);

	if($debug){
		print "\nDEBUG: Output file name is $outputFile\n";
	}

	$output=array(
		'Key' => $outputFile,
		'ThumbnailPattern' => "",
		'Rotate' => "0",
		'PresetId' => $preset['Id']
	);
	array_push($outputsArray, $output);
}

if($debug){
	print "\nDEBUG: Outputs requested:\n";
	var_dump($outputsArray);
}

$pipelineName=substitute_string($_ENV['pipeline']);
if(! $pipelineList[$pipelineName]){
	print "-ERROR:The pipeline '$pipelineName' does not exist in your AWS account\n";
	exit(2);
}

if($debug){
	print "\nDEBUG: Submitting to pipeline:\n";
	var_dump($pipelineList[$pipelineName]);
}

$job = $client->createJob( array(
	'PipelineId' => $pipelineList[$pipelineName],
	'Input' => array(
		'Key' => $filename,
		'FrameRate' => 'auto',
		'Resolution' => 'auto',
		'AspectRatio' => 'auto',
		'Interlaced' => 'auto',
		'Container' => 'auto'
	),
	'Outputs' => $outputsArray,
	'OutputKeyPrefix' => substitute_string($_ENV['output_prefix'])
));

while($job['Status']=="Progressing" or $job['Status']=="Submitted"){
	$job=readJob($job['Id']);
	print "Current job status: " . $job['Status'] . "\n";
	sleep(10);
}

if($job['Status']!="Complete"){
	var_dump($job);
	print "-ERROR: Elastic transcoder failed to complete the job.\n";
	exit(1);
}

var_dump($job);
print "+SUCCESS: Transcoding completed.\n";

//Tell CDS about the transcoded file.
$fp=fopen($_ENV['cf_temp_file'],"w");
if(!$fp){
	print "-ERROR: Unable to open tempfile " .$_ENV['cf_temp_file']. " for writing.\n";
	exit(1);
}
fwrite($fh,"cf_media_file=$outputFile\n");
fclose($fp);

//FIXME: need to update the datastore with metadata from $job about the transcoded file(s)
?>
