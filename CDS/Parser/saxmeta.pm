#This is a Perl-based SAX parser for Episode Engine .meta files
#It is written by Andy Gallagher (andy@magiclantern.co.uk) as part of the Guardian's Universal Upload system
#
#It can also break down the metadata supplied into more useful formats (e.g. dates into month/day/year hashes).  Setting the 'keep-simple' key in the 'config' hash inhibits this behaviour
#It can also ensure that characters are converted into XML entities.  This is a secondary function achieved by calling the escape_for_xml procedure once parsing is complete.
#
#Usage:
#use saxmeta;
#
#my $handler=saxmeta->new;
#$handler->{'config'}->{'keep-simple'}=1 if defined $keepsimple;
#$handler->{'config'}->{'keep-spaces'}=1;	#this stops the parser translating - and space in key
#names to underscores.
#my $parser = XML::SAX::ParserFactory->parser(
#        Handler => $handler
#  ); 
#  $parser->parse_uri($ARGV[0]);
#$parser->{'Handler'}->escape_for_xml if not defined $dont_entity;
#
#The broken-down data can be found in $parser->{'Handler'}->{'content'}
#
#The data format is controlled by @parent_keys and @date_keys.
#@parent_keys is a list which, when encountered, cause the parser to make a new parent level in the output hash.
#@date_keys is a list of keys whose data is a date in the format YYYYMMDD that should be broken down into a hash.

package CDS::Parser::saxmeta;
use base qw(XML::SAX::Base);

use Data::Dumper;
#use strict;
use warnings;

my @parent_keys=('movie','meta_source','meta_group','track');
my @date_keys=('Valid_From','Valid_To','creation_date');

sub is_parent_key {
	my ($test)=@_;

	foreach(@parent_keys){
		return 1 if($test eq $_);
	}
	return 0;
}

sub start_document {
	my($self,$doc)=@_;
#	print "in start_document: \$doc=\n";
#	print Dumper($doc);
};

sub end_document {
	my($self,$doc)=@_;

	my %temp_hash;
	#FIXME: make generic
	for(my $n=0;$n<=$self->{'temp'}->{'n_tracks'};++$n){
		if($n==0){
			$trackname="track";
		} else {
			$trackname="track$n";
		}
		$temp_hash{$self->{'content'}->{$trackname}->{'type'}}=$self->{'content'}->{$trackname} if(defined $self->{'content'}->{$trackname}->{'type'});
		$temp_hash{$self->{'content'}->{$trackname}->{'type'}}->{'index'}=$n;
		delete $self->{'content'}->{$trackname};
	}
	$self->{'content'}->{'tracks'}=\%temp_hash;

	if(not defined $self->{'config'}->{'keep-simple'}){
		#split keywords into array
		my @keywords;
		if(defined $self->{'content'}->{'meta_source'}){
			$_=$self->{'content'}->{'meta_source'}->{'keyword'};
			if(/,/){
				@keywords=split /,/;
			} else {
				@keywords=split / /;
			}
			$self->{'content'}->{'meta_source'}->{'keywords'}=\@keywords;
		} elsif(defined $self->{'content'}->{'meta'}){
			$_=$self->{'content'}->{'meta'}->{'keyword'};
			if(/,/){
				@keywords=split /,/;
			} else {
				@keywords=split / /;
			}
			$self->{'content'}->{'meta'}->{'keywords'}=\@keywords;
		}
		
		foreach(@date_keys){
			$self->{'content'}->{'meta_source'}->{$_}=~/(\d{4})(\d{2})(\d{2})/;
			delete $self->{'content'}->{'meta_source'}->{$_};
			$self->{'content'}->{'meta_source'}->{$_}->{'year'}=$1;
			$self->{'content'}->{'meta_source'}->{$_}->{'month'}=$2;
			$self->{'content'}->{'meta_source'}->{$_}->{'day'}=$3;
		}
		$_=$self->{'content'}->{'movie'}->{'duration'};
		my $hrs=int $_/3600;
		my $mins=int (($_-($hrs*3600))/60);
		my $sec=($_-($hrs*3600)-($mins*60));
		my $sec_whole=int $sec;
		my $framerate=$self->{'content'}->{'tracks'}->{'vide'}->{'framerate'};
		my $frames=($_*$framerate-($hrs*3600*$framerate)-($mins*60*$framerate)-($sec_whole*$framerate));
		delete $self->{'content'}->{'movie'}->{'duration'};
		$self->{'content'}->{'movie'}->{'duration'}->{'hms'}=sprintf("%02d:%02d:%02.2f",$hrs,$mins,$sec);
		$self->{'content'}->{'movie'}->{'duration'}->{'timecode'}=sprintf("%02d:%02d:%02d:%02d",$hrs,$mins,$sec_whole,$frames);
		$self->{'content'}->{'movie'}->{'duration'}->{'seconds'}=$_;
	}
	delete $self->{'temp'};
	delete $self->{'parent'};
#	print "in end_document: \$doc=\n";
#	print Dumper($doc);
};

sub start_element {
	my($self,$el)=@_;
#	print "in start_element: \$el=\n";
#	print Dumper($el->{'Attributes'}->{'{}value'});
	if(is_parent_key($el->{'LocalName'})){
		$self->{'parent'}=$el->{'LocalName'};
	}
	if($el->{'LocalName'} eq 'meta'){
		my $key=$el->{'Attributes'}->{'{}name'}->{'Value'};
		my $val=$el->{'Attributes'}->{'{}value'}->{'Value'};
		#un-escape hex entities
		$self->{'temp'}->{'untouched'}=$val;
		while($val=~/%([\dA-Fa-f]{2})/){
			my $char=chr hex $1;
			$val=~s/%$1/$char/g;
		}
		#Template mis-translates dashes as subtraction.  So replace w/ _ for keys.
		$key=~tr/[\- ]/_/ if(not defined $self->{'config'}->{'keep-spaces'});
		#$val=~tr/-/_/;
		if($key eq 'movie'){
			$self->{'content'}->{'escaped_path'}=$self->{'temp'}->{'untouched'};
			#$val=~/^(.*)\/([\w\d\_\-\.%]+)$/;
			$val=~/^(.*)\/([^\/]+)$/;
			$self->{'content'}->{'filename'}=$2;
			$self->{'content'}->{'path'}=$1;
#			print "Path=\"$1\"\nFilename=\"$2\"\n";
		}
		if(is_parent_key($key)){
			my $n=0;
			my $newkey=$key;
			while(defined $self->{'content'}->{$newkey}){
				++$n;
				$newkey=$key . $n;
			}
			$self->{'temp'}->{"n_".$key."s"}=$n;
			$key=$newkey;
			$self->{'parent'}=$key;
		} else {
			$self->{'parent'}="meta" if(not defined $self->{'parent'});
			$self->{'content'}->{$self->{'parent'}}->{$key}=$val;
		}
		if($val=~/[A-Za-z]/){
#			print "$key=\"$val\"\n";
		} else {
#			print "$key=$val\n";
		}
	}
};

sub end_element {
	my($self,$el)=@_;
#	print "in end_element: \$el=\n";
#	print Dumper($el);
};

#Sundry Extra Functions
sub do_escape_for_xml {
	my($val)=@_;

	return $val if(not defined $val);
#	print "Got $val\n";
	$val=~s/&(?!\w{2,4};)/&amp;/g;
	$val=~s/'/&apos;/g;
	$val=~s/"/&quot;/g;
	$val=~s/>/&gt;/g;
	$val=~s/</&lt;/g;
	return $val;
}

sub level_escape_for_xml {
	my($level)=@_;

	foreach(keys %{$level}){
	if(ref($level->{$_}) eq 'HASH'){
		level_escape_for_xml($level->{$_});
	} elsif(ref($level->{$_}) eq 'ARRAY'){
		$_=do_escape_for_xml($_) foreach(@{$level->{$_}});
	} else {
		$level->{$_}=do_escape_for_xml($level->{$_});
	}
	}
}

sub escape_for_xml {
	my($self)=@_;

	level_escape_for_xml $self->{'content'};
}
#if this file doesn't 'return true' then the program doesn't run...
1;

