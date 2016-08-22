package CDS::Parser::saxfcs;
use base qw(XML::SAX::Base);

use Data::Dumper;
use strict;
use warnings;

sub start_document {
	my($self,$doc)=@_;
#	print "in start_document: \$doc=\n";
	print Dumper($doc);
#	undef $self->{'output-hash'};
};

sub end_document {
	my($self,$doc)=@_;
#	print "in end_document: \$doc=\n";
#	print Dumper($doc);
};

sub start_element {
	my($self,$el)=@_;
#	print Dumper($el);
#'entity' is for Write XML xmls.  Request is for Read XML xmls.
	if($el->{'LocalName'} eq 'entity'){
		my $group_name=$el->{'Attributes'}->{'{}entityType'}->{'Value'};
		my $group_id=$el->{'Attributes'}->{'{}entityId'}->{'Value'};
		$self->{'current_group'}=$group_name;
		$self->{'current_id'}=$group_id;
	}
	if($el->{'LocalName'} eq 'request'){
		my $group_name=$el->{'Attributes'}->{'{}reqId'}->{'Value'};
		my $group_id=$el->{'Attributes'}->{'{}entityId'}->{'Value'};
		$self->{'current_group'}=$group_name;
		$self->{'current_id'}=$group_id;
	}
	if($el->{'LocalName'} eq 'mdValue'){
		my $key=$el->{'Attributes'}->{'{}fieldName'}->{'Value'};
		my $group=$self->{'current_group'};
		my $id=$self->{'current_id'};
		$self->{'current_key'}=$key;
		$self->{'content'}->{$group}->{$id}->{$key}->{'type'}=$el->{'Attributes'}->{'{}dataType'}->{'Value'};
	}

#	print "in end_document: \$doc=\n";
#	print Dumper($doc);
};

sub end_element {
	my($self,$el)=@_;
	delete $self->{'current_key'};
};

sub characters {
my($self,$text)=@_;

#print "in characters(), \$text=$text\n";
#Dumper($text);
if(defined $self->{'current_group'} and defined $self->{'current_id'} and defined $self->{'current_key'}){
	my $group=$self->{'current_group'};
	my $id=$self->{'current_id'};
	my $key=$self->{'current_key'};
#	print "$key: " . Dumper($text);
	$self->{'content'}->{$group}->{$id}->{$key}->{'value'}=$self->{'content'}->{$group}->{$id}->{$key}->{'value'}.$text->{'Data'};
	$self->{'content'}->{$group}->{$id}->{$key}->{'name'}=$key;
}
};

1;
