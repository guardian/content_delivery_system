#!/usr/bin/perl

our $version='ffprobe CDS method, $Rev: 1410 $ $LastChangedDate: 2015-11-10 10:55:52 +0000 (Tue, 10 Nov 2015) $';

#This method runs ffmpeg's ffprobe command on the given media file, and outputs the
#results to the datastore.
#It aims to provide Episode Engine-compatible metadata into the datastore
#
#Arguments:
# <take-files>media - you need to supply a media file
# <debug/>	[OPTIONAL] - output lots of debugging information

#END DOC

#This mapping table is in the format ffmpeg_name=>output_name
our $track_mapping_table={
	'bit_rate'=>'bitrate',
	'duration'=>'duration',
	'codec_tag_string'=>'format',
	'r_frame_rate'=>'framerate',	#THIS NEEDS A DATA TRANSFORM
	'height'=>'height',
	'width'=>'width',
	'size'=>undef,
	'start_time'=>'start',	#This is the last one that EE provides for video
	'bits_per_sample'=>'bitspersample',
	'channels'=>'channels',
	'sample_rate'=>'samplerate', #This is the last extra one that EE provides for audio
	#extra keys that ffprobe provides
	'TAG:language'=>'language_tag',
	'codec_long_name'=>'format_description',
	'codec_short_name'=>'codec_name',
	'pix_fmt'=>'pixel_format',
	'has_b_frames'=>'has_b_frames',
	'profile'=>'profile_name',
	'level'=>'codec_level',
	'sample_aspect_ratio'=>'sample_aspect',
	'display_aspect_ratio'=>'aspect'
};

package FFProbe;
use File::Spec;

#This package is a module to get ffprobe metadata into a perl-compatible format
#Fairly obvioslyl, it requires ffmpeg/ffprobe to be installed!

sub new
{
my ($class,$filename,$debug)=@_;

my $self;
$self->{'version'}='$Rev: 1410 $ $LastChangedDate: 2015-11-10 10:55:52 +0000 (Tue, 10 Nov 2015) $';
$self->{'filename'}=$filename;
$self->{'debug'}=$debug;

bless($self,$class);
$self->{'cmd'}=$self->_find_ffprobe();

if(-f $filename){
	$self->{'exists'}=1;
	$self->probe($filename);
} else {
	$self->{'exists'}=0;
}

return $self;
}

sub _find_ffprobe()
{
my $found_cmd;

foreach(@_){
	my $test_cmd=File::Spec->catfile($_,"ffprobe");
	print "debug: _find_ffprobe: checking $test_cmd" if($self->{'debug'});
	return $test_cmd if(-x $test_cmd);
}

foreach(qw.ffprobe /usr/bin/ffprobe /usr/local/bin/ffprobe /usr/lib/ffprobe.){
	print "debug: _find_ffprobe: checking $_" if($self->{'debug'});
	return $_ if(-x $_);
}

die "-ERROR: Unable to locate an executable ffprobe binary";
}

sub probe
{
my ($self,$filename)=@_;

my $cmd=$self->{'cmd'};

my @output_lines=`"$cmd" \"$filename\" -show_format -show_streams -show_private_data 2>/dev/null`;

my $current_section;

foreach(@output_lines){
	chomp;
	if(/^\[\/([^\[\]]+)\]/){
		print "debug: end of section $current_section\n";
		$current_section=undef;
		next;
	}
	if(/^\[([^\[\]]+)\]/){
		$current_section=lc $1;
		my $is_stream=0;
		$is_stream=1 if($current_section=~/^stream/);
		my $orig=$current_section;
		my $n=1;
		while($self->{$current_section}){
			$current_section=sprintf("%s%d",$orig,$n);
			++$n;
		}
		$self->{'n_tracks'}=$n if($is_stream);
		print "debug: got section name $current_section\n";
		next;
	}
	if(/^([^=]+)=(.*)/){
		if($current_section){
			$self->{$current_section}->{$1}=$2;
		} else {
			$self->$1=$2;
		}
	}
}

}

sub tracks_count
{
my $self=shift;

return $self->{'n_tracks'};
}

sub file_exists
{
my $self=shift;
return $self->{'exists'};
}

sub map_track
{
my($self,$trackindex,$mappingtable)=@_;

my $keyname="stream";
$keyname="$keyname$trackindex" if($trackindex>0);

my %mapped_data;
foreach(keys %{$self->{$keyname}}){
	my $mapped_key=$mappingtable->{$_};
	if($mapped_key){
		$mapped_data{$mapped_key}=$self->{$keyname}->{$_};
	} else {
		#print STDERR "WARNING: No mapping was found for ffmpeg key $_\n";
	}
}
if($self->{$keyname}->{'codec_type'}=~/^video/){
	$mapped_data{'type'}='vide';
} elsif($self->{$keyname}->{'codec_type'}=~/^audio/){
	$mapped_data{'type'}='audi';
} else {
	$mapped_data{'type'}=$self->{$keyname}->{'codec_type'};
}

#get rid of any exceptions... some wrapper formats don't have codec tags, so we need to use another field...
if($self->{$keyname}->{'codec_tag'} eq "0x0000" or $self->{$keyname}->{'codec_tag'}==0){
	$mapped_data{'format'}=$self->{$keyname}->{'codec_long_name'};
}

return \%mapped_data;
}

package main;
use Data::Dumper;
use URL::Encode qw/url_encode_utf8/;
use CDS::Datastore;
use File::Basename;

my $store=CDS::Datastore->new('ffprobe');

#START MAIN
unless(-f $ENV{'cf_media_file'}){
	print STDERR "-ERROR: You should specify <take-files>media</take-files> when running this method\n";
	exit 1;
}

my $debug=$ENV{'debug'};

my $fileinfo=FFProbe->new($ENV{'cf_media_file'});
print Dumper($fileinfo) if($debug);

my $filename = basename($ENV{'cf_media_file'});
my $xtn = "";
if($filename =~ /\.([^\.]+)$/){
	$xtn=$1;
}

#Step 1.... output EE compliant Media metadata
push @mediainfos,('path',dirname($ENV{'cf_media_file'}));
push @mediainfos,('escaped_path',url_encode_utf8(dirname($ENV{'cf_media_file'})));
push @mediainfos,('filename',$filename);
push @mediainfos,('extension',$xtn);
push @mediainfos,('size',$fileinfo->{'format'}->{'size'});
push @mediainfos,('duration',$fileinfo->{'stream'}->{'duration'});
my @formats=split /,\s*/,$fileinfo->{'format'}->{'format_name'};
push @mediainfos,('format',".".$formats[0]);
push @mediainfos,('bitrate',$fileinfo->{'format'}->{'bit_rate'}/1024);
#Step 2.... output more keys that look handy
push @mediainfos,('format_description',$fileinfo->{'format'}->{'format_long_name'});
push @mediainfos,('start_time',$fileinfo->{'format'}->{'start_time'});
push @mediainfos,('streams_count',$fileinfo->{'format'}->{'nb_streams'});
push @mediainfos,('aspect',$fileinfo->{'stream'}->{'display_aspect_ratio'});	#ok so technically this is track metadata but it's handy here as well

local $Data::Dumper::Pad="\t";
if($debug){
	print "DEBUG: Movie metadata section derived from ffmpeg:\n";
	print Dumper(\@mediainfos);
}

#ok, now save that lot...
eval {
	$store->set('media',@mediainfos);
};
if($@){
	print "-ERROR: Unable to output values to datastore: $@\n";
	#exit 1;
}

#print "Got ".$fileinfo->tracks_count()." tracks reported\n";

#Step 3.... map and output each track in turn
my $n;
for($n=0;$n<$fileinfo->tracks_count();++$n){
	my $mapped_data=$fileinfo->map_track($n,$track_mapping_table);
	$mapped_data->{'bitrate'}=$mapped_data->{'bitrate'}/1024;
	local $Data::Dumper::Pad="\t";
	if($debug){
		print "DEBUG: Track #$n metadata section derived from ffmpeg:\n";
		print Dumper($mapped_data);
	}
	#Now flatten the data hash into an argument list....
	my @arglist;
	foreach(keys %{$mapped_data}){
		push @arglist,($_,$mapped_data->{$_});
	}
	eval {
		#the track ID/type is set automatically by Datastore
		$store->set('track',@arglist);
	};
	if($@){
		print "-ERROR: Unable to output values to datastore: $@\n";
		#exit 1;
	}
}

print "+SUCCESS: Output core media section and $n tracks metadata information\n";
