#!/usr/bin/perl

use XML::SAX;
#use lib "/usr/local/bin";
use Data::Dumper;
use CDS::Parser::saxmeta;
use Getopt::Long;
#use saxgeneric;

my $uppercase='';
my $lowercase='';
my $minimal='';
my $dump='';

GetOptions('minimal'=>\$minimal,'key-upper'=>\$uppercase,'key-lower'=>\$lowercase,'dump'=>\$dump);

if(scalar @ARGV<2){
	print STDERR "\nThis script will extract keys from the given Episode Engine meta file and print them to stdout in the order requested.\n";
	print STDERR "You can specify a key using dot notation, e.g. Identifier.NameLabel\n";
	print STDERR "If your key has spaces then enclose it in quotes, e.g. \"Components.Main.aspect ratio\"\n\n";
	print STDERR "Recognised options:\n\t--minimal\tOutput just the requested value, instead of key=value\n";
	print STDERR "\t--key-upper\tOutput the key portion as all upper case\n";
	print STDERR "\t--key-lower\tOutput the key portion as all lower case\n\n";
	print STDERR "Usage: ./ee_get.pl [options...] {newsml-file} {key1} {key2}....\n";
	exit 2;
}

die "Couldn't open file '".$ARGV[0]."'\n" if(not stat($ARGV[0]));

my $parser = XML::SAX::ParserFactory->parser(
        Handler => CDS::Parser::saxmeta->new
  );
  
  $parser->parse_uri($ARGV[0]);
my $content=$parser->{'Handler'}->{'content'};

print Dumper($content) if($dump);

for(my $n=1;$n<(scalar @ARGV);++$n){
	my $reference=$content;
	$_=$ARGV[$n];
#	print $_;
	@identifiers=split /\./;
	foreach(@identifiers){
#		print $_;
		if(ref($reference) eq 'HASH'){
			$reference=$reference->{$_};
		} elsif(ref($reference) eq 'ARRAY'){
			$reference=$reference->[$_];
		}
	}
	print "$reference\n" if $minimal;
	$key=$_;
	$key=uc($_) if $uppercase;
	$key=lc($_) if $lowercase;
	print "$key=$reference\n" if not $minimal;
}
