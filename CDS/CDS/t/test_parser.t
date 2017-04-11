#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Data::Dumper;

use XML::SAX;
use CDS::Parser::saxmeta;

use File::Basename;
my $dirname = dirname(__FILE__);

my $metafile = "$dirname/data/sample_inmeta.xml";

my $handler=CDS::Parser::saxmeta->new;
$handler->{'config'}->{'keep-spaces'}=1;
$handler->{'config'}->{'keep-simple'}=1;	#FIXME - for initial testing

my $parser = XML::SAX::ParserFactory->parser(Handler => $handler);
$parser->parse_uri($metafile);

my $metadata = $handler->{'content'};

print Dumper($handler->{'content'});
ok($metadata->{'meta'}->{'__version'}==1);
ok($metadata->{'meta'}->{'originalWidth'}=='1920');
ok($metadata->{'meta'}->{'originalHeight'}=='1080');

done_testing();

