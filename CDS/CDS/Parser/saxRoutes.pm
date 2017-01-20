package CDS::Parser::saxRoutes;
use base qw(XML::SAX::Base);

use Data::Dumper;
use strict;
use warnings;

my $record;
my $currentAttribute;
my $debugLevel = 0;
	
# callback specific to handling route files

sub start_document {
	my ( $self, $doc ) = @_;
	#  print "Document Dumper($doc)";

}

sub end_document {
	my ( $self, $doc ) = @_;
}

sub start_element {
	my ( $self, $el ) = @_;

	if($el->{'LocalName'}=~/([\w\d]*)-route/){
		$self->{'route'}->{'max-retries'}=$el->{'Attributes'}->{'{}max-retries'}->{'Value'};
	}

#	print "in start_element: \$el=\n";
#	print Dumper($el);
	if($el->{'LocalName'}=~/([\w\d]*)-method/){
		print "Got $1 method\n" if $debugLevel > 0;
		$self->{'current_method_type'}=$1;
		$self->{'current_method'}->{'name'}=$el->{'Attributes'}->{'{}name'}->{'Value'};
	} elsif(defined $self->{'current_method_type'}){
		$self->{'current_attribute'}=$el->{'LocalName'};
	}
	
}

sub end_element {
	my ( $self, $el ) = @_;
	
	if($el->{'LocalName'}=~/([\w\d]*)-method/){
		if($1 ne $self->{'current_method_type'}){
			print "-WARNING: 'saxRoutes.pm' syntax error in route file\n";
		}
	
		push @{$self->{'methods'}->{$self->{'current_method_type'}}},$self->{'current_method'};
		delete $self->{'current_method_type'};
		delete $self->{'current_method'};
	} 
	else 
	{
		#print "Local name $el->{'LocalName'}\n";
		
		#if (defined $self->{'current_attribute'})
		#{
		#	print "Current attribute $self->{'current_attribute'}\n";		
		#}

		# check if the elements exists in the attributes, if not add it.
		unless ($self->{'current_attribute'} and defined $self->{'current_method'}->{$self->{'current_attribute'}})
		{
			if ($self->{'current_attribute'})
			{
				$self->{'current_method'}->{$self->{'current_attribute'}} = "true";	
			}
		}
		#else
		#{
		#	print "key '$self->{'current_attribute'}' value '$self->{'current_method'}->{$self->{'current_attribute'}}'\n";	
		#}
		
		delete $self->{'current_attribute'};
	}
}

sub characters {
	my ( $self, $text ) = @_;

	if(defined $self->{'current_attribute'} and defined $self->{'current_method'}){
		$self->{'current_method'}->{$self->{'current_attribute'}}=$self->{'current_method'}->{$self->{'current_attribute'}}.$text->{'Data'};
		
		print "store value '$text->{'Data'}' for key '$self->{'current_attribute'}'\n" if $debugLevel > 0;		
	}
}

1;
