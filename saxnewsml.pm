package saxnewsml;
use base qw(XML::SAX::Base);

use Data::Dumper;
use strict;
use warnings;

#FIXME's:
#Components which do not have a ContentItem are deleted, as a temp workaround.

my @excluded_headers=('ItemId','Lines','Service','ItemType');
my @array_headers=('KeywordLine');
my @dont_expand=('Property','Provider');
#my @dont_expand;

sub start_document {
	my($self,$doc)=@_;
#	print "in start_document: \$doc=\n";
#	print Dumper($doc);
#	undef $self->{'output-hash'};
#	$self->{'output-hash'}->{'dummy'};#
#	$self->{'current-level'}=\$self->{'output-hash'};
};

sub end_document {
	my($self,$doc)=@_;
#	print "in end_document: \$doc=\n";
#	print Dumper($doc);
#	print Dumper(@excluded_headers);

	my %temp_hash;
	my $key;
	#print Dumper($self);
	#"Component1" is always the main package metadata
	$temp_hash{'Package'}=$self->{'content'}->{"Component1"};
	delete $self->{'content'}->{"Component1"};

	for(my $n=2;$n<=$self->{'n_components'};++$n){
		#push @temp_array,$self->{'content'}->{"Component$n"};
	#	if(not defined $self->{'content'}->{"Component$n"}->{'ContentItem'}){
	#		delete $self->{'content'}->{"Component$n"};
	#	} else {
			if(defined $self->{'content'}->{"Component$n"}->{'Role'}){
				$key=$self->{'content'}->{"Component$n"}->{'Role'};
			} else {
				$key="Component$n";
			}
			if(defined $temp_hash{$key}){
				if(ref($temp_hash{$key}) eq 'ARRAY'){
					push @{$temp_hash{$key}},$self->{'content'}->{"Component$n"};
				} else {
					my @temp_array;
					@temp_array=($temp_hash{$key},$self->{'content'}->{"Component$n"});
					$temp_hash{$key}=\@temp_array;
				}
			} else {
				$temp_hash{$key}=$self->{'content'}->{"Component$n"};
			}
		#	print Dumper($);
			delete $self->{'content'}->{"Component$n"};
#		}
	}
	$self->{'content'}->{'Components'}=\%temp_hash;
	#my %temp2=$self->{'content'};
	#$self->{'content'}=(%temp2,\%temp_hash);
};

sub excluded_header {
	my($test)=@_;

	foreach(@excluded_headers){
		return 1 if($test eq $_);
	}

	return 0;
}

sub is_array {
	my($test)=@_;

	foreach(@array_headers){
		return 1 if($test eq $_);
	}
	return 0;
}

sub dont_expand {
	my($test)=@_;

	foreach(@dont_expand){
		return 1 if($test eq $_);
	}
	return 0;
}

sub start_element {
	my($self,$el)=@_;
	my $name=$el->{'LocalName'};

#	print "in start_element: \$el=\n";
#	print Dumper($el);

	++$self->{'level'};
	$self->{'tags'}[$self->{'level'}]=$el->{'LocalName'};

	undef $self->{'current'};

	$_=$el->{'LocalName'};
	if(/^News([\w]+)/){
		$self->{'parent'}=$1 if(not excluded_header($1));
	}
	if($_ eq 'NewsComponent'){
		++$self->{'n_components'};
		$self->{'parent'}="Component".$self->{'n_components'};
	}

	if($_ eq 'ContentItem'){
		my $name=$_;
		my $val=$el->{'Attributes'}->{'{}Href'}->{'Value'};
		$self->{'content'}->{$self->{'parent'}}->{$name}=$val;
	}
	if($_ eq 'Property'){
		my $name=$el->{'Attributes'}->{'{}FormalName'}->{'Value'};
		my $val=$el->{'Attributes'}->{'{}Value'}->{'Value'};
		$self->{'content'}->{$self->{'parent'}}->{$name}=$val;
	}

	if(defined $el->{'Attributes'}->{'{}FormalName'}){
		my $val=$el->{'Attributes'}->{'{}FormalName'}->{'Value'};
		my $name=$el->{'LocalName'};
		#my $val=$el->{'Attributes'}->{'{}Value'}->{'Value'};
		$self->{'role'}=$val if($name eq 'Role');
		if(defined $self->{'content'}->{$self->{'parent'}}->{$name} and not dont_expand($el->{'LocalName'})){
			if(ref($self->{'content'}->{$self->{'parent'}}->{$name}) eq 'ARRAY'){
				push @{$self->{'content'}->{$self->{'parent'}}->{$name}},$val;
			} else {
				my @temp_array=($self->{'content'}->{$self->{'parent'}}->{$name},$val);
				$self->{'content'}->{$self->{'parent'}}->{$name}=\@temp_array;
			}
		} else {
			$self->{'content'}->{$self->{'parent'}}->{$name}=$val;# if undef $self->{'current'};
#		$self->{'content'}->{$self->{'parent'}}->{$self->{'current'}}->{$name}=$val if defined $self->{'current'};
		}
	} else {
		$self->{'current'}=$el->{'LocalName'} if((not defined $self->{'current'}));
		$self->{'current'}='ContentItem' if($self->{'tags'}[$self->{'level'}-1] eq 'ContentItem');
	}
};

sub characters {
my($self,$text)=@_;

#print "in characters: \$text=\n";
#print Dumper($text);
#if(is_array($self->{'current'}) and undef $self->{'content'}->{$self->{'parent'}}->{$self->{'current'}}){#
#	$self->{'content'}->{$self->{'parent'}}->{$self->{'current'}}=($text->{'Data'});
#}
#push $self->{'content'}->{$self->{'parent'}}->{$self->{'current'}},$text->{'Data'} if(is_array($self->{'current'}));
if($text->{'Data'}=~/[\w\d]/ and defined $self->{'parent'} and defined $self->{'current'}){
	if(defined $self->{'content'}->{$self->{'parent'}}->{$self->{'current'}}){
		if(ref($self->{'content'}->{$self->{'parent'}}->{$self->{'current'}}) eq 'ARRAY'){
			push @{$self->{'content'}->{$self->{'parent'}}->{$self->{'current'}}},$text->{'Data'};
		} else {
			my @temp_array;
			@temp_array=($self->{'content'}->{$self->{'parent'}}->{$self->{'current'}},$text->{'Data'});
			$self->{'content'}->{$self->{'parent'}}->{$self->{'current'}}=\@temp_array;
		}
	} else {
		$self->{'content'}->{$self->{'parent'}}->{$self->{'current'}}=$text->{'Data'};
	}
}

};

sub end_element {
	my($self,$el)=@_;

	#if a NewsComponent has no role, then it's defined at the previous level... so go get it....
	#Commented out until we have a way of dealing with multiple elements of the same role.
	if($self->{'tags'}[$self->{'level'}] eq 'NewsComponent' and $self->{'tags'}[$self->{'level'}-1] eq 'NewsComponent'){#
		$self->{'content'}->{$self->{'parent'}}->{'Role'}=$self->{'role'};
	}
	delete $self->{'tags'}[$self->{'level'}];
	--$self->{'level'};

#	print "in end_element: \$el=\n";
#	print Dumper($el);
};

1;
