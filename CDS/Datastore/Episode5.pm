package CDS::Datastore::Episode5;

use base qw /CDS::Datastore/;
use XML::SAX;
use Data::Dumper;
use File::Basename;
use Template;

#use lib "/usr/local/bin";
use CDS::Parser::saxmeta;

#these internal templates reduce the external dependencies.

my $internal_meta_template='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE meta-data SYSTEM "meta.dtd">
<meta-data version="1.0">
	<meta name="meta-source" value="inmeta">
[% FOREACH key = meta.keys val=meta_source -%]
		<meta name="[% key %]" value="[% meta.$key %]"/>
[% END -%]
	</meta>
	<meta name="movie" value="[% escaped_path %]">
[% FOREACH key = movie.keys -%]
		<meta name="[% key %]" value="[% movie.$key %]"/>
[% END -%]
[% FOREACH trackname = tracks.keys -%]
		<meta name="track" value="[% tracks.$trackname.index %]">
[% FOREACH key = tracks.$trackname.keys -%]
			<meta name="[% key %]" value="[% tracks.$trackname.$key %]"/>
[% END -%]
		</meta>
[% END -%]
	</meta>
</meta-data>
';	#the last newline is important, as certain XML engines (e.g. Saxon in Java) require it

my $internal_inmeta_template='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE meta-data SYSTEM "inmeta.dtd">

<meta-data>
	<meta-group type="movie meta">
[% FOREACH key = meta.keys val=meta_source -%]
		<meta name="[% key %]" value="[% meta.$key %]"/>
[% END -%]
	</meta-group>

	<meta-movie-info>
		<meta-movie tokens="format duration bitrate size tracks" />
		<meta-track tokens="type format start duration bitrate size" />
		<meta-video-track tokens="width height framerate" />
		<meta-audio-track tokens="channels bitspersample samplerate" />
		<meta-hint-track tokens="payload fmtp" />
	</meta-movie-info>
</meta-data>
';

#this function strips out the user-generated part of the .meta file, leaving only the bit that Episode returns.
#this is because Episode sometimes does not handle entities correctly, decoding them and then not re-encoding them in the output .meta
#in this case, run import_episode with truncate=1, this routine is called and only the episode return portion is parsed.
sub truncate_meta {
	my ($filename,$inmeta_info)=@_;
	
	my $chopped_xml;
	
	open FHREAD,"<$filename";
	my @invalid_xml_lines=<FHREAD>;
	close FHREAD;
	
	my $is_dumping=1;
		
	foreach(@invalid_xml_lines){
		if(/<meta name="meta-source"/){
			$is_dumping=0;
		} elsif ($is_dumping==0 and /<\/meta>/){
			$is_dumping=1;
		} else {
			$chopped_xml=$chopped_xml.$_ if($is_dumping);
		}
	}

	return $chopped_xml;
#	#die;
}

sub import_episode {
my($self,$metafile,$truncate)=@_;

if(not -f $metafile){
	$self->error("Episode5 - unable to find metadata file '$metafile'");
	return 0;
}

my $handler=CDS::Parser::saxmeta->new;
$handler->{'config'}->{'keep-spaces'}=1;
$handler->{'config'}->{'keep-simple'}=1;	#FIXME - for initial testing

#FIXME - need to implement an eval {} block to prevent a dodgy file from crashing us with no error trace.
eval {
	my $parser = XML::SAX::ParserFactory->parser(Handler => $handler); 
	if(not $truncate){
		$parser->parse_uri($metafile);
	} else {
		$parser->parse_string(truncate_meta($metafile));
	}
};
if($@){
	$self->error($@);
	return 0;
}

my $metadata=$handler->{'content'};
print STDERR Dumper($metadata);

#get the final file extension
my $type;
if($metafile=~/\.([^\.]+)$/){
	$type=$1;
} else {
	$type='meta';
}

#print Dumper($metadata);

my $sourceid=$self->getSource($type,basename($metafile),dirname($metafile));

if($sourceid<1){
	$self->error("Unable to get a valid source ID, bailing.\n");
	return 0;
}

foreach(qw/meta meta_source meta_source1/){
	my $parent=$_;
	my @args;
	push @args,$sourceid;
	push @args,'meta';	#'type' field for set
	foreach(keys %{$metadata->{$parent}}){
		push @args,($_,$metadata->{$parent}->{$_});
	}
	$self->internalSet(@args);
}

foreach(keys %{$metadata->{'tracks'}}){
	my $parent=$_;
	my @args;
	push @args,$sourceid;
	push @args,'track';	#'type' field for set
	push @args,('type',$_);	#'type' field for track
	foreach(keys %{$metadata->{'tracks'}->{$parent}}){
		push @args,($_,$metadata->{'tracks'}->{$parent}->{$_});
	}
	$self->internalSet(@args);
}

my @args;
push @args,$sourceid;
push @args,'media';	#'type' field for set
	
foreach(keys %{$metadata->{'movie'}}){
	push @args,($_,$metadata->{'movie'}->{$_});
}

foreach(qw/filename escaped_path path/){
	push @args,($_,$metadata->{$_});
}
$self->internalSet(@args);
return 1;
}

sub export_episode {
my($self,$template,$output)=@_;

}

sub export_meta {
my($self,$output)=@_;

my $tt=Template->new(ABSOLUTE=>1);
if(not defined $internal_meta_template){
	$self->error("Episode5::export_meta - Internal template not defined, unable to continue.\n");
	return 0;
}

$tt->process(\$internal_meta_template,$self->get_template_data(1),$output);
}

sub export_inmeta {
my($self,$output)=@_;

my $tt=Template->new(ABSOLUTE=>1);
if(not defined $internal_inmeta_template){
	$self->error("Episode5::export_inmeta - Internal template not defined, unable to continue.\n");
	return 0;
}

$tt->process(\$internal_inmeta_template,$self->get_template_data(1),$output);

}

sub import_meta {
my($self,$output)=@_;

}

1;
