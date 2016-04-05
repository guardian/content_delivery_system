#!/usr/bin/perl

my $version='$Rev: 651 $ $LastChangedDate: 2014-01-01 16:57:45 +0000 (Wed, 01 Jan 2014) $';

#This CDS method imports a Final Cut Server "write metadata" format XML file into the data store, for use in templates and substitutions
#You need to specify <take-files>xml</take-files> and supply the XML file to read as the route's XML file when this method is run.
#You can also import extra files via string substitutions
#
#Arguments:
#  <extra_files>/path/to/{substitution}/file [optional] - also try to read in the given files, specified as a list delimited by the | character.  Substitutions are accepted.
#  <field_prepend>blah [optional] - pre-pend the given text to the key names output into the data store.  So if you have a Final Cut Server field called name, and specified fcs_ as <field-prepend>, you can access the data by looking at {meta:fcs_name}.
#  <must_import_all/> [optional] - if importing more than one file using <extra_files>, tell the route to throw an error if any of them fail to load.  The default behaviour is NOT to throw an error unless EVERYTHING fails to import.
#END DOC

use CDS::Datastore;
use XML::SAX;
use CDS::Parser::saxfcs;
use Data::Dumper;

#START MAIN

my $store=CDS::Datastore->new('read_fcs');

my $debug=$ENV{'debug'};

push @files,$ENV{'cf_xml_file'} if($ENV{'cf_xml_file'});

if($ENV{'extra_files'}){
	my @extrafiles=split /\|/,$ENV{'extra_files'};
	push @files,$store->substitute_string($_) foreach(@extrafiles);
}

print Dumper(\@files) if($debug);
my $successful_reads=0;

foreach(@files){
	unless(-f $_){
		print "-ERROR: Unable to find file $_.\n";
		next;
	}
	
	my $handler=CDS::Parser::saxfcs->new;
	my $parser=XML::SAX::ParserFactory->parser(Handler => $handler); 

	$parser->parse_uri($_);
	
	my $data=$handler->{'content'};
	
	print Dumper($data) if($debug);
	
	#now we've read in the data, collate it into arguments we can push to the datastore
	my @pushdata=('meta');
	
	foreach(keys %{$data->{'asset'}}){
		my $subdata=$data->{'asset'}->{$_};
		print Dumper($subdata);
		foreach(keys %{$subdata}){
			#$_ should now point to a key name in subdata, keyed by the field name, each of which is another hash
			#containing value, name, and type for the field.
			next unless($subdata->{$_}->{'name'});	#undef values will cause the datastore to stop importing data at that point
			$subdata->{$_}->{'value'}="" unless($subdata->{$_}->{'value'});
			my $fieldname;
			if($ENV{'field_prepend'}){
				$fieldname=$ENV{'field_prepend'}.$subdata->{$_}->{'name'};
			} else {
				$fieldname=$subdata->{$_}->{'name'};
			}
			push @pushdata,($fieldname,$subdata->{$_}->{'value'});
		}
	}
	print Dumper(\@pushdata) if($debug);
	
	if($store->isValid){
		eval {
			$store->set(@pushdata);
		};
		if($@){	#datastore threw an exception
			print "-ERROR - datastore error: $@\n";
		} else {
			++$successful_reads;
		}
	} else {
		print "-ERROR: Datastore is not valid.\n";
	}
}

if($successful_reads==0){
	print "-ERROR: Unable to import @files\n";
	exit 1;
}

my $total_number=scalar @files;
if($successful_reads<$total_number){
	print "-WARNING: Only imported $successful_reads from $total_number requested.\n";
	exit 1 if($ENV{'must_import_all'});
	exit 0;
}

print "+SUCCESS: Imported @files to datastore.\n";
exit 0;

