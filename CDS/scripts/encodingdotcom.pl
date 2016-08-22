#!/usr/bin/perl

local $|=1;
my $version='$Rev: 517 $ $LastChangedDate: 2013-10-07 12:07:00 +0100 (Mon, 07 Oct 2013) $';


#This script is a CDS method to send media to encoding.com and receive it back.
#It is expected that the media has been put somewhere accessible to encoding.com by URL (e.g., by ftp)
#and that another method (e.g., ftp_pull) will download the encoded media again.  See examples in the documentation for the best way of implementing this.
#Arguments:
# <keyfile>blah - get the encoding.com API key from this file.  should contain userid=nnn and userkey=nnnnn, separated by newlines.
# <source_url>blah - substitutions allowed.  URL e.g. of the form ftp://user:password@server/path/to/file.mov
# <output_url_base>blah - substitutions allowed.  Base url of where to output to, e.g. ftp://user:password@server/path/to.  file.{format} is then created at this location.
#				you can list multiple destinations by creating a list, {dest1}|{dest2}|{dest3} etc.
# <output_url_key>blah - set this metadata key to the location of the returned media
# <output_append>blah [OPTIONAL] - substitutions allowed. append this string Episode-style to the end of the output name.
# <passive/> - tell encoding.com to use passive ftp.  use this to help sort firewall probs.
# <error_value>blah [OPTIONAL] - return this value (substitutions allowed) if an error occurs
# <encoding_profile>blah [OPTIONAL] - encoding settings are either specified by this XML file or by the following args
# <format>blah - encode to this format
# <vcodec>blah - encode to this video codec (see ffmpeg/encoding.com documentation)
# <acodec>blah - encode to this audio codec
# <vbitrate>xxxk - (e.g., 1024k) - use this video bitrate for CBR or as average for VBR
# <vmaxrate>xxxk - as above, maximum bitrate for VBR
# <vminrate>xxxk - as above, minimum bitrate for VBR
# <vprofile>{main|baseline|high} - use this profile level for h.264. defaults to 'main'.
# <vbframes>n - use this many b-frames to increase encoding efficiency (but not playable on some mobile devs)
# <width>n - width of encoded video frame, in pixels
# <height>n - height of encoded video frame, in pixels
# <abitrate>xxxk - as vbitrate, use this audio bitrate
# <asamplerate>xxxx [OPTIONAL] - (e.g., 44100) - use this sample rate for audio encoding
# <achannels>n	[OPTIONAL] - (e.g., 5) - use this number of channels for audio encoding
# <vframerate>n [OPTIONAL] (e.g., 25) - use this output framerate
# <turbo/>	[OPTIONAL] - use turbo option.
#
# <cache-timeout>n [OPTIONAL] - wait this long for a cached id to become available.  Default: 3600s (1 hour)
# <cache-location>/path/to/cache/db [OPTIONAL] - use this location for the cache database.  Default: /var/spool/cds_backend/encodingdotcom.cache
#END DOC

use Data::Dumper;
use CDS::Datastore;
use CDS::Encodingdotcom::Cache;
use LWP::UserAgent;
use Template;
use XML::Simple;
use Net::SSL;
use Time::Piece;

my $version='encoding.com CDS interface. $Rev: 517 $ $LastChangedDate: 2013-10-07 12:07:00 +0100 (Mon, 07 Oct 2013) $';

my $target='https://manage.encoding.com';
our $encoding_profile_path='/etc/cds_backend/settings';

our $default_cache_location='/var/spool/cds_backend/encodingdotcom.cache';
our $default_cache_timeout=3600;

my $passiveftp=1;


my $generalTemplate='<?xml version="1.0"?>
<query>
	<userid>[% userid %]</userid>
	<userkey>[% userkey %]</userid>
	';

my $queryTemplate='<?xml version="1.0"?>
<query>
<!-- Main fields -->
    <userid>[% userid %]</userid>
    <userkey>[% userkey %]</userkey>
    <action>[% action %]</action>
    <mediaid>[% mediaid %]</mediaid>
</query>
';

#to do an add media call, use addMediaTemplate with encodingTemplate concatenated on.
#to use a cached media id, use existingMediaTemplate with encodingTemplate concatenated on.

my $addMediaTemplate='<?xml version="1.0"?>
<query>
<!-- Main fields -->
    <userid>[% userid %]</userid>
    <userkey>[% userkey %]</userkey>
    <action>[% action %]</action>
    <source>[% sourceURL %]</source>
';

my $existingMediaTemplate='<?xml version="1.0"?>
<query>
<!-- Main fields -->
    <userid>[% userid %]</userid>
    <userkey>[% userkey %]</userkey>
    <action>[% action %]</action>
    <mediaid>[% mediaid %]</mediaid>
';

my $encodingTemplate='

    <region>eu-west-1</region> 
<!--
<notify>[NotifyURL]</notify>
    <notify_encoding_errors>[NotifyEncodingErrorURL]</notify_encoding_errors>
-->

    <format>

        <!-- Format fields -->
        <!--<noise_reduction>luma_spatial:chroma_spatial:luma_temp</noise_reduction>-->
        <output>[% outputformat %]</output>
        <video_codec>[% vcodec %]</video_codec>
        <audio_codec>[% acodec %]</audio_codec>
        <bitrate>[% video.bitrate %]</bitrate>
        <audio_bitrate>[% audio.bitrate %]</audio_bitrate>
        <audio_sample_rate>[% audio.samplerate %]</audio_sample_rate>
        <audio_channels_number>[% audio.channels %]</audio_channels_number>
<!--
		<audio_volume>[Volume]</audio_volume>       
        <audio_normalization>[0-100]</audio_normalization>       
-->
		<framerate>[% video.framerate %]</framerate>
        <!--<framerate_upper_threshold>[Frame Rate Upper Threshold]</framerate_upper_threshold>-->
        <size>[% video.width %]x[% video.height %]</size>
<!--
        <fade_in>[FadeInStart:FadeInDuration]</fade_in>
        <fade_out>[FadeOutStart:FadeOutDuration]</fade_out>
-->

        <keep_aspect_ratio>no</keep_aspect_ratio>
        <!--<set_aspect_ratio>[ASPECT_RATIO|source]</set_aspect_ratio>-->
        <add_meta>yes</add_meta>
        <hint>yes</hint>
        
        <!--<rc_init_occupancy>[RC Occupancy]</rc_init_occupancy>-->
        <minrate>[% video.minrate %]</minrate>
        <maxrate>[% video.maxrate %]</maxrate>
        <!-- <bufsize>[RC Buffer Size]</bufsize>
        <keyframe>[Keyframe Period (GOP)]</keyframe>
        <start>[Start From]</start>
        <duration>[Result Duration]</duration> -->
 
 <!--       <keyframe>[% video.keyframeperiod %]</keyframe>  -->
        <bframes>[% video.bframes %]</bframes>
       <!-- <gop>[cgop|sgop]</gop> -->

        <!-- Metadata fields (OPTIONAL) -->
       <metadata> 
            <title>[% meta.title %]</title>
            <copyright>[% meta.copyright %]</copyright> 
            <author>[% meta.author %]</author> 
            <description>[% meta.description %]</description> 
            <album>[Album]</album>
        </metadata> 
	
        <!-- Destination fields --> 
       [%- FOREACH url IN destURLs -%]
        <destination>[% url %]</destination> 
		[%- END -%]


		
        <!-- Video codec parameters (OPTIONAL, while only for libx264 video codec) --> 
<!--        <video_codec_parameters> To see the example for parameters please follow this link below
        * </video_codec_parameters> 
-->

        <!-- Profile & Level (OPTIONAL, while only for libx264 video codec) --> 
        <profile>[% video.profile %]</profile>

        <!--<level>[11/30/51]</level>--><!--drop the decimal, example 3.0 is 30--> 

        <!-- Turbo Encoding switch (OPTIONAL) --> 
        <turbo>[% turbo %]</turbo>

<!--
        <audio_sync>[1..N]</audio_sync> 
        <video_sync>old|passthrough|cfr|vfr|auto</video_sync>
        <force_interlaced>tff|bff|no</force_interlaced>
        <strip_chapters>[yes|no]</strip_chapters> 
-->
    </format> 
</query>';

my $cropTemplate='
        <crop_left>[% crop.left %]</crop_left>
        <crop_top>[% crop.top %]</crop_top>
        <crop_right>[% crop.right %]</crop_right>
        <crop_bottom>[% crop.bottom %]</crop_bottom>
';

sub getKeyData {
my $filename=shift;

open $fhkey,"<$filename";
return undef unless($fhkey);

my %rtn;

while( <$fhkey> ){
#	print "getKeyData: got $_\n";
	next if(/^$/);
	/^([^=]+)=(.*)$/;
	$rtn{$1}=$2;
}
close $fhkey;

#print "getKeyData: loaded info:\n";
#print Dumper(\%rtn);
#my %rtn;
#$rtn{'userid'}=17410;
#$rtn{'userkey'}='5c85a4ebab9190ab11b5ed83ba573d96';

return \%rtn;
}

sub addMedia {
my($ua,$sourceURL,$destURLs,$settings,$keydata)=@_;

my $headerxml;

my $request;

$request=$settings;
$request->{'userid'}=$keydata->{'userid'};
$request->{'userkey'}=$keydata->{'userkey'};
$request->{'action'}='AddMedia';

$request->{'sourceURL'}=$sourceURL;
if($settings->{'passive'}){
	$request->{'sourceURL'}=$request->{'sourceURL'}."?passive=yes";
}

my $tt=Template->new;

$tt->process(\$addMediaTemplate,$request,\$headerxml);

return setupEncoding($ua,$headerxml,$destURLs,$settings);
}

sub useExistingMedia {
my($ua,$mediaId,$destURLs,$settings,$keyData)=@_;

my $headerxml;

my $request;

unless($mediaId=~/^\d+$/){
	print "-ERROR: media ID must be numeric only.\n";
	return undef;
}

$request=$settings;
$request->{'userid'}=$keyData->{'userid'};
$request->{'userkey'}=$keyData->{'userkey'};
$request->{'action'}='UpdateMedia';

$request->{'mediaid'}=$mediaId;

my $tt=Template->new;

$tt->process(\$existingMediaTemplate,$request,\$headerxml);

my $r=setupEncoding($ua,$headerxml,$destURLs,$settings);

#this line isn't needed, as encoding.com will start it automatically
#queryGeneric('ProcessMedia',$ua,$mediaId,$keyData,undef);
return 1;

}


sub setupEncoding {
my($ua,$headerportion,$destURLs,$settings)=@_;

restartsetup:
my $request;
$request=$settings;

if($settings->{'passive'}){
	foreach(@$destURLs){
		push @{$request->{'destURLs'}},$_."?passive=yes";
	}
} else {
	foreach(@$destURLs){
		push @{$request->{'destURLs'}},$_;
	}
}

my $tt=Template->new;

my $xmlContent;
my %formdata;

$tt->process(\$encodingTemplate,$request,\$xmlContent);
$formdata{'xml'}=$headerportion.$xmlContent;

print "data to send: ".$formdata{'xml'}."\n" if($debug); #unless($args{'quiet'});

#return 123456;

my $response=$ua->post($target,\%formdata);
if($response->is_success){
	#print "info: got ".$response->decoded_content."\n";
	my $replydata=XMLin($response->decoded_content);
	if($debug){
		print "got reply:\n";
		print Dumper($replydata);
	}
	if($replydata->{'errors'}){
		print "-ERROR: Encoding.com said ".$replydata->{'errors'}->{'error'}."\n";
		if($replydata->{'errors'}->{'error'} =~/Could not update media with Status/){
			my $timeout=$ENV{'cache-timeout'};
			$timeout=30 unless($timeout);
			print "Re-trying after $timeout seconds\n"; 
			sleep($timeout);
			goto restartsetup;
		}
		die;
	}
	return $replydata->{'MediaID'};
} else {
	print "-ERROR: ".$response->status_line."\n";
	return undef;
}
return undef;
}

sub queryMediaInfo {

return queryGeneric('GetMediaInfo',@_);
}

sub queryStatus {
#my ($ua,$mediaId,$keydata,%args)=@_;

return queryGeneric('GetStatus',@_);
}

sub queryGeneric {
my ($op,$ua,$mediaId,$keydata,%args)=@_;

my %request;

$request{'userid'}=$keydata->{'userid'};
$request{'userkey'}=$keydata->{'userkey'};
$request{'action'}=$op;
$request{'mediaid'}=$mediaId;

my $tt=Template->new;
my $xmlContent;
$tt->process(\$queryTemplate,\%request,\$xmlContent);

print "data to send: $xmlContent\n" unless($args{'quiet'});

my %formdata;
$formdata{'xml'}=$xmlContent;

my $response=$ua->post($target,\%formdata);
if($response->is_success){
	my $replydata=XMLin($response->decoded_content);
	print "info: got ".$response->decoded_content."\n" unless($args{'quiet'});
	return $replydata;
} else {
	print "-ERROR: ".$response->status_line."\n";
	return undef;
}
return undef;
}

sub dumpRequestHandler {
my($request,$ua,$h)=@_;

print Dumper($request);
}

our $validVideoCodec;
@{$validVideoCodec->{'flv'}}=qw/flv libx264 vp6/;
#flv: flv, libx264, vp6
@{$validVideoCodec->{'fl9'}}=qw/libx264/;
@{$validVideoCodec->{'mpegts'}}=qw/libx264/;
#fl9, mpegts: libx264
@{$validVideoCodec->{'wmv'}}=qw/wmv2 msmpeg4/;
$validVideoCodec->{'zune'}=$validVideoCodec->{'wmv'};
#wmv, zune: wmv2, msmpeg4
@{$validVideoCodec->{'3gp'}}=qw/h263 mpeg4 libx264/;
$validVideoCodec->{'android'}=$validVideoCodec->{'3gp'};
#3gp, android: h263, mpeg4, libx264
@{$validVideoCodec->{'m4v'}}=qw/mpeg4/;
#m4v: mpeg4
@{$validVideoCodec->{'mp4'}}=qw/mpeg4 libx264/;
$validVideoCodec->{'ipod'}=$validVideoCodec->{'mp4'};
$validVideoCodec->{'iphone'}=$validVideoCodec->{'mp4'};
$validVideoCodec->{'ipad'}=$validVideoCodec->{'mp4'};
$validVideoCodec->{'appletv'}=$validVideoCodec->{'mp4'};
$validVideoCodec->{'psp'}=$validVideoCodec->{'mp4'};
#mp4, ipod, iphone, ipad, appletv, psp: mpeg4, libx264
@{$validVideoCodec->{'ogg'}}=qw/libtheora/;
#ogg: libtheora
@{$validVideoCodec->{'webm'}}=qw/libvpx/;
#webm: libvpx
@{$validVideoCodec->{'mp3'}}=qw/ /;
@{$validVideoCodec->{'wma'}}=qw/ /;
#mp3, wma: none
@{$validVideoCodec->{'mpeg2'}}=qw/mpeg2video/;
#mpeg2: mpeg2video
@{$validVideoCodec->{'mpeg1'}}=qw/mpeg1video/;
#mpeg1: mpeg1video

our $validAudioCodec;
@{$validAudioCodec->{'mp3'}}=qw/libmp3lame/;
#mp3: libmp3lame
@{$validAudioCodec->{'m4a'}}=qw/libfaac dolby_aac dolby_heaac dolby_heaacv2/;
#m4a: libfaac, dolby_aac, dolby_heaac, dolby_heaacv2
@{$validAudioCodec->{'flv'}}=qw/libmp3lame libfaac dolby_aac dolby_heaac dolby_heaacv2/;
#flv: libmp3lame, libfaac, dolby_aac, dolby_heaac, dolby_heaacv2
@{$validAudioCodec->{'mp4'}}=qw/libfaac dolby_aac dolby_heaac dolby_heaacv2/;
$validAudioCodec->{'fl9'}=$validAudioCodec->{'mp4'};
$validAudioCodec->{'m4v'}=$validAudioCodec->{'mp4'};
$validAudioCodec->{'ipod'}=$validAudioCodec->{'mp4'};
$validAudioCodec->{'iphone'}=$validAudioCodec->{'mp4'};
$validAudioCodec->{'ipad'}=$validAudioCodec->{'mp4'};
$validAudioCodec->{'appletv'}=$validAudioCodec->{'mp4'};
$validAudioCodec->{'psp'}=$validAudioCodec->{'mp4'};
$validAudioCodec->{'wowza'}=$validAudioCodec->{'mp4'};
$validAudioCodec->{'roku_hls'}=$validAudioCodec->{'mp4'};
$validAudioCodec->{'kindle_fire'}=$validAudioCodec->{'mp4'};
#fl9, mp4, m4v, ipod, iphone, ipad, appletv, psp, wowza, roku_*, kindle_fire: libfaac, dolby_aac, dolby_heaac, dolby_heaacv2
@{$validAudioCodec->{'mov'}}=qw/libfaac dolby_aac dolby_heaac dolby_heaacv2 eac3/;
#mov: libfaac, dolby_aac, dolby_heaac, dolby_heaacv2, eac3
@{$validAudioCodec->{'iphone_stream'}}=qw/libfaac dolby_aac dolby_heaac dolby_heaacv2/;
@{$validAudioCodec->{'ipad_stream'}}=qw/libfaac dolby_aac dolby_heaac dolby_heaacv2/;
@{$validAudioCodec->{'wowza_multibitrate'}}=qw/libfaac dolby_aac dolby_heaac dolby_heaacv2/;
@{$validAudioCodec->{'roku_hls'}}=qw/libfaac dolby_aac dolby_heaac dolby_heaacv2/;
@{$validAudioCodec->{'smooth_streaming'}}=qw/libfaac dolby_aac dolby_heaac dolby_heaacv2/;
@{$validAudioCodec->{'hds'}}=qw/libfaac dolby_aac dolby_heaac dolby_heaacv2/;
#iphone_stream, ipad_stream, wowza_multibitrate, roku_hls, smooth_streaming, hds: libfaac, dolby_aac, dolby_heaac, dolby_heaacv2
@{$validAudioCodec->{'wmv'}}=qw/wmav2 libmp3lame/;
@{$validAudioCodec->{'wma'}}=qw/wmav2 libmp3lame/;
@{$validAudioCodec->{'zune'}}=qw/wmav2 libmp3lame/;
#wmv, wma, zune: wmav2, libmp3lame
@{$validAudioCodec->{'ogg'}}=qw/libvorbis/;
@{$validAudioCodec->{'webm'}}=qw/libvorbis/;
#ogg, webm: libvorbis
@{$validAudioCodec->{'3gp'}}=qw/libamr_nb/;
#3gp: libamr_nb
@{$validAudioCodec->{'android'}}=qw/libamr_nb libfaac/;
#android: libamr_nb, libfaac
@{$validAudioCodec->{'mpeg2'}}=qw/pcm_s16be pcm_s16le mp2/;
#mpeg2: pcm_s16be, pcm_s16le
@{$validAudioCodec->{'mpeg1'}}=qw/mp2 copy/;
#mpeg1: mp2, copy
@{$validAudioCodec->{'mpegts'}}=qw/ac3/;
#mpegts: ac3

sub listContains {
my($needle,$haystack)=@_;

#print "listContains: looking for $needle in ".@$haystack.".\n";

foreach(@$haystack){
	return 1 if($needle eq $_);
}
return 0;
}

sub validateFormatAndCodec {
my($format,%args)=@_;

my $isValid;

#print Dumper($validVideoCodec);
#print Dumper($validAudioCodec);


if($args{'video'}){
	if($validVideoCodec->{$format}){
		#print Dumper($validVideoCodec);
		if(listContains($args{'video'},\@{$validVideoCodec->{$format}})){
			$isValid=1;
		} else {
			print "-ERROR: ".$args{'video'}." is not a valid codec for encoding to $format in this system.\n" unless($args{'silent'});
		}
	} else {
		print "-ERROR: $format is not a valid format for encoding video.\n" unless($args{'silent'});
		return 0;
	}
}
if($args{'audio'}){
	if($validVideoCodec->{$format}){
		if(listContains($args{'audio'},\@{$validAudioCodec->{$format}})){
			$isValid=1;
		} else {
			print "-ERROR: ".$args{'audio'}." is not a valid codec for encoding to $format in this system.\n" unless($args{'silent'});
			$isValid=0;
		}
	} else {
		print "-ERROR: $format is not a valid format for encoding audio.\n" unless($args{'silent'});
		return 0;
	}
}
return $isValid;
}

sub check_args {
	my @args=@_;

	foreach(@args){
		if(not defined $ENV{$_}){
			print "-FATAL: $_ was not specified.  Please check the route file.\n";
			exit 1;
		}
	}
}

END {
	if($urlcache){
		print "Attempting to release cache lock on $mediaId...\n";
		my $r=$urlcache->release($mediaId);
		unless($r){
			print "WARNING: Attempt to release cache lock failed. Further attempts to use this media might run into problems.\n";
		}
	} else {
		print "No URL cache reference available, unable to attempt to release cache lock.\n";
	}
}

#START MAIN
$ENV{HTTPS_VERSION} = 3;
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

#START MAIN
my $store=CDS::Datastore->new('encodingdotcom');

#check arguments
our $debug=$ENV{'debug'};

print "INFO: Extended debugging information is ON\n" if($debug);
check_args(qw/keyfile output_url_key source_url output_url_base/);

my $keyfile=$store->substitute_string($ENV{'keyfile'});
print "Loading key data from $keyfile.\n";# if($debug);
my $keydata=getKeyData($keyfile);

unless($keydata and $keydata->{'userid'} and $keydata->{'userkey'}){
	print "-ERROR: Unable to load encoding.com API key details from $keyfile.\n";
	exit 1;
}

my $cache_location=$default_cache_location;
if($ENV{'cache-location'}){
	$cache_location=$ENV{'cache-location'};
}

my $cache_timeout=$default_cache_timeout;
if($ENV{'cache-timeout'}){
	$cache_timeout=$ENV{'cache-timeout'};
}

print "INFO: Using cache database '$cache_location' with a timeout value of $cache_timeout seconds.\n";

my $clientstring="unknown CDS route\n";
$clientstring=$ENV{'cf_routename'} if($ENV{'cf_routename'});
$clientstring=$clientstring.": ".$ENV{'cf_media_file'} if($ENV{'cf_media_file'});

our $urlcache=CDS::Encodingdotcom::Cache->new('db'=>$cache_location,'client'=>$clientstring,'debug'=>$debug);
die "-FATAL: Unable to initialise cache" unless($urlcache);


print "INFO: Cache initialised.\n";

my $settings;
my $have_settingsfile=0;

if($ENV{'encoding_profile'}){
	my $settingsname=$store->substitute_string($ENV{'encoding_profile'});
	
	$settingsname=$encoding_profile_path.'/'.$settingsname unless(-f $settingsname);
	
	print "Loading initial settings from $settingsname.\n";
	eval {
		$settings=XMLin($settingsname);
	};
	if($!){
		print "ERROR loading settings from $settingsname: $!\n";
	} else {
		$have_settingsfile=1;
	}
	if($debug){
		print "Dump of initial settings loaded in:\n";
		print Dumper($settings) ;
	}
}

$settings->{'outputformat'}=$store->substitute_string($ENV{'format'});
$settings->{'vcodec'}=$store->substitute_string($ENV{'vcodec'});
$settings->{'acodec'}=$store->substitute_string($ENV{'acodec'});

my $source=$store->substitute_string($ENV{'source_url'});
unless($source){
	print "-ERROR: You must specify <source_url> in the route file.\n";
	exit 1;
}
my @output_appends=split /\|/,$store->substitute_string($ENV{'output_append'});
my $n=0;

foreach(split /\|/,$ENV{'output_url_base'}){
	my $outputbase=$store->substitute_string($_);
	unless($outputbase){
		print "-ERROR: You must specify <output_url_base> in the route file.\n";
		exit 1;
	}
	unless($source=~/\/([^\/]+)\.[^\.]+$/){
		print "-ERROR: <source_url> does not appear to be correctly formed.\n";
	}
	my $outputfile=$1;
	$outputbase=$outputbase.'/' unless($outputbase=~/\/$/);
	
	if($output_appends[$n]){
		push @dests,$outputbase.$outputfile.$output_appends[$n].'.'.$settings->{'outputformat'};
	} else {
		push @dests,$outputbase.$outputfile.'.'.$settings->{'outputformat'};
	}
	++$n;
	
}

print "Source URL: $source.\n";
print "Destination URLs:\n";
print "\t$_\n" foreach(@dests);

unless(validateFormatAndCodec($settings->{'outputformat'},'video'=>$settings->{'vcodec'},'audio'=>$settings->{'acodec'})){
	print "-ERROR: The specified video codec '".$settings->{'vcodec'}."' and/or the specified audio codec '".$settings->{'acodec'}."' are not compatible with the format '".$settings->{'format'}."'.\n";
	exit 1;
}

check_args(qw/vbitrate abitrate width height/) unless($have_settingsfile);
$settings->{'video'}->{'bitrate'}=$store->substitute_string($ENV{'vbitrate'}) if($ENV{'vbitrate'});
$settings->{'audio'}->{'bitrate'}=$store->substitute_string($ENV{'abitrate'}) if($ENV{'abitrate'});
$settings->{'audio'}->{'samplerate'}=$store->substitute_string($ENV{'asamplerate'}) if($ENV{'asamplerate'});
$settings->{'audio'}->{'channels'}=$store->substitute_string($ENV{'achannels'}) if($ENV{'achannels'});
$settings->{'video'}->{'framerate'}=$store->substitute_string($ENV{'vframerate'}) if($ENV{'vframerate'});	#consider dropping this & seeing how it copes
$settings->{'video'}->{'width'}=$store->substitute_string($ENV{'width'}) if($ENV{'width'});
$settings->{'video'}->{'height'}=$store->substitute_string($ENV{'height'}) if($ENV{'height'});
$settings->{'video'}->{'maxrate'}=$store->substitute_string($ENV{'vmaxrate'}) if($ENV{'vmaxrate'});
$settings->{'video'}->{'minrate'}=$store->substitute_string($ENV{'vminrate'}) if($ENV{'asamplerate'});
$settings->{'video'}->{'bframes'}=$store->substitute_string($ENV{'vbframes'}) if($ENV{'vbframes'});
$settings->{'video'}->{'profile'}=$store->substitute_string($ENV{'vprofile'}) if($ENV{'vprofile'});
if($ENV{'turbo'}){
	$settings->{'turbo'}='yes';
} else {
	$settings->{'turbo'}='no';
}
$settings->{'passive'}=$store->substitute_string($ENV{'passive'}) if($ENV{'passive'});

if($debug){
	print "\n\nDump of effective settings:\n";
	print Dumper($settings);
}

#my $userAgent=LWP::UserAgent->new('SSL_verify_mode'=>0);	
my $userAgent=LWP::UserAgent->new(
                         ssl_opts => {
                             verify_hostname => 0, 
                             SSL_verify_mode => 0x00 
                            });#FIXME: should implement SSL verify at some point! temporary fix to get rid of annoying error message.

my $starttime=time;

start_encoding:

print "INFO: Looking up $source in cache...\n";
our $mediaId=$urlcache->lookup($source,'Timeout'=>$cache_timeout,'Verbose'=>1);

if($mediaId){
	#we have found the existing media id referencing this source and it isn't locked. (well, it's now
	#locked by us).
	#send the settings on this id.
	eval {
		unless(useExistingMedia($userAgent,$mediaId,\@dests,$settings,$keydata)){
			print "-ERROR: Unable to submit new encoding request to existing id '$mediaId'. Releasing lock on URL cache record.\n";
			$urlcache->release($mediaId);
			exit 1;
		}
	};
	if($@){
		print "-WARNING: Unable to use existing media, falling back to re-uploading media\n";
		$urlcache->remove_by_id($mediaId);
		$urlcache->release($mediaId);
		$mediaId=addMedia($userAgent,$source,\@dests,$settings,$keydata);

		#FIXME: should delete old cache record
		$urlcache->remove_by_id($mediaId);
		
		unless($mediaId){
			print "-ERROR: Unable to submit request to encoding.com\n";
			exit 1;
		}
		if($urlcache->store($source,$mediaId)<0){
			print "-WARNING: Unable to store cache record for $source.\n";
		}
	}		
} else {
	$mediaId=addMedia($userAgent,$source,\@dests,$settings,$keydata);

	unless($mediaId){
		print "-ERROR: Unable to submit request to encoding.com\n";
		exit 1;
	}
	if($urlcache->store($source,$mediaId)<0){
		print "-WARNING: Unable to store cache record for $source.\n";
	}
	
}

print "INFO: Media ID on encoding.com is $mediaId.\n";

my $info;
while(1){
	$info=queryStatus($userAgent,$mediaId,$keydata,"quiet"=>1);
	#print Dumper($info);
	if($info->{'status'} eq 'Error'){
		print Dumper($info) if($debug);
		print "-ERROR: encoding.com returned an error '";
		print $info->{'description'}."' " if($info->{'description'});
		print $info->{'format'}->{'description'}."' " if($info->{'format'}->{'description'});
		print $info->{'format'}->{'destination_status'}."' " if($info->{'format'}->{'destination_status'});
		print $info->{'errors'}->{'error'}."' " if($info->{'errors'}->{'error'});
		if($info->{'format'}->{'description'}=~/HTTP error 404/){
			print "-WARNING: Encoding.com was unable to find the source file. Re-trying with new media\n";
			$urlcache->remove_by_id($mediaId);
			$urlcache->release($mediaId);
			goto start_encoding;
		}
		print "\n";
		print "INFO: Releasing lock on URL cache record...\n";
		$urlcache->release($mediaId);
		exit 1;
		last;
	} elsif($info->{'status'} eq 'Finished'){
		last;
	}
	my $t=localtime;
	print $t->strftime().": ".$info->{'status'}." (".$info->{'description'}."): ".$info->{'progress'}.". Current operation progress: ".$info->{'progress_current'}.".\n";
	sleep(10);
}
my $endtime=time;

print "\n\n".Dumper($info) if($debug);

$mi=queryMediaInfo($userAgent,$mediaId,$keydata,"quiet"=>0);

if($debug){
	print "Media info:\n";
	print Dumper($info);
}

print "INFO: Releasing lock on URL cache record...\n";
my $elapsed=$endtime-$starttime;
$urlcache->release($mediaId);

print "+SUCCESS: File has been encoded. By my estimation, elapsed time was $elapsed seconds.\n";

$store->set('meta','encoding time',$elapsed,'processed by',$info->{'processor'},'processing region',$info->{'region'},undef);

#ok now output required metadata.
if($ENV{'output_url_key'}){
	my $output_key=$store->substitute_string($ENV{'output_url_key'});
	#my $output_string;
	print "INFO: outputting final encoding URL ".$info->{'format'}->{'destination'}." to key $output_key.\n" if($debug);
	$store->set('meta',$output_key,$info->{'format'}->{'destination'});
}

#path	/Volumes/MediaTransfer/Episode Output/stitch_guardian_website_16x9	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#filename	130306STEELclip01-16x9.mp4	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#size	3928656	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#duration	28.93	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#format	.mp4	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#bitrate	1061.05	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013

my $bitrate;
#assume bitrate in k
$info->{'format'}->{'bitrate'}=~/^(\d+)/;
my $vb=$1;
$bitrate+=$1;
$info->{'format'}->{'audio_bitrate'}=~/^(\d+)/;
my $ab=$1;
$bitrate+=$1;
my @mediakeys;
my $outputurl;
if(ref $info->{'format'}->{'destination'} eq 'ARRAY'){
	print "-WARNING: Multiple destination fields returned.  Using the first one given wich is '";
	$outputurl=$info->{'format'}->{'destination'}[0];
	print $outputurl."'\n";
} else {
	$outputurl=$info->{'format'}->{'destination'};
}
$outputurl=~/^(.*)\/([^\/]*)$/;
push @mediakeys,'path',$1;
my $temp=$2;
$temp=~s/\?.*//;
push @mediakeys,'filename',$temp;

$store->set('media',@mediakeys,'size',$info->{'format'}->{'convertedsize'},
	'duration',$mi->{'duration'}, #0,	#queryStatus gives the duration you requested. queryMediaInfo gives actual duration of video
	'format','.'.$info->{'format'}->{'file_extension'},
	'bitrate',$bitrate,
	undef);

my $w=-1;
my $h=-1;
if($info->{'format'}->{'size'}=~/(\d+)x(\d+)/){
	$w=$1;
	$h=$2;
}

#1	bitrate	930.00	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#1	duration	28.96	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#1	format	h264	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#1	framerate	25.00	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#1	height	360	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#1	index	0	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#1	size	3450178	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013 <- doesn't supply this
#1	start	0.00	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#1	type	vide	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#1	type	vide	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#1	type	vide	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#1	width	640	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
my $starttime;
if(ref $info->{'format'}->{'start'} eq 'HASH'){
	$starttime=0;
} else {
	$starttime=$info->{'format'}->{'start'};
}
my $encprofile;
if(ref $info->{'format'}->{'profile'} eq 'HASH'){
	$encprofile='not applicable';
} else {
	$encprofile=$info->{'format'}->{'profile'};
}

#FIXME: should verify that there IS a video track before implying that there is...
my $dur;
if($mi->{'video_duration'}){
	$dur=$mi->{'video_duration'};
} else {
	$dur=$mi->{'duration'};
}

$store->set('track','type','vide',
	'bitrate',$vb,
	'duration',$dur, #0, #this is a blank hashref in test data. needs more info.
	'format',$info->{'format'}->{'video_codec'},
	'framerate',$info->{'format'}->{'framerate'},
	'height',$h,
	'index',0,
	'start',$starttime, #this is a blank hashref in test data. needs more info.
	'width',$w,
	'profile',$encprofile,
	'rotate',$info->{'format'}->{'rotate'},
	undef);

#2	bitrate	125.00	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#2	bitspersample	16	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013 <- doesn't supply this
#2	channels	2	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#2	duration	28.93	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#2	format	mp4a	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#2	index	1	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#2	samplerate	48000.00	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#2	size	463531	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013 <- doesn't supply this
#2	start	0.00	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#2	type	audi	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#2	type	audi	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013
#2	type	audi	130306STEELclip01-16x9.mp4.meta	Wed Mar 6 11:38:25 2013

if($mi->{'audio_duration'}){
	$dur=$mi->{'audio_duration'};
} else {
	$dur=$mi->{'duration'};
}

$store->set('track','type','audi',
	'bitrate',$ab,
	'channels',$info->{'format'}->{'audio_channels_number'},
	'duration',$dur,	#0, #this is a blank hashref in test data. needs more info.
	'format',$info->{'format'}->{'audio_codec'},
	'index',1,
	'samplerate',$info->{'format'}->{'audio_sample_rate'},
	'start',$starttime, #this is a blank hashref in test data. needs more info.
	undef);

print "+SUCCESS: Metadata has been output to datastore.\n";

exit 0;
