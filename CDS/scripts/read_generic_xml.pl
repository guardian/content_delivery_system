#!/usr/bin/perl

my $version='$Rev: 1095 $ $LastChangedDate: 2014-11-11 19:25:14 +0000 (Tue, 11 Nov 2014) $';


#This module reads an XML file using XML::Simple, folds the tree structure into
#paths and puts them into the datastore.

#<root_key>blah - prefix this to any keys generated
#<delimiter>; [OPTIONAL] - use this character to seperate out lists of items.  Defaults to ,
#<extra_files> - process these files as well as cf_xml_file.  Substitutions allowed.

# So, if you've got <xml><headline>sdjsd</headline><crew><camera>fhdf</camera><sound>fdhdfs</sound> etc.,
# you would get root_key:headline=sdjsd, root_key:crew:camera=fhdf, root_key:crew:sound, etc.
#END DOC

use XML::Simple;
use CDS::Datastore;
use Data::Dumper;

my $delimiter;

sub fold_key {
my($hashdata,$currentpath,$outputs)=@_;

#print Dumper($hashdata);
print "-----------\n";

foreach(keys %$hashdata){
	my $outputpath=$currentpath.'_'.$_;
	$outputpath=~s/^_//;
	print "\tgot $_ at $outputpath with content ".$hashdata->{$_}." and ref ".ref($hashdata->{$_})."\n";
	if(ref $hashdata->{$_} eq 'ARRAY'){
		#push @{$outputs->{$outputpath}},@{$hashdata->{$_}};
		fold_key($_,$outputpath,$outputs) foreach(@{$hashdata->{$_}});
	} elsif(ref $hashdata->{$_} eq 'HASH'){
		fold_key($hashdata->{$_},$outputpath,$outputs);
	} elsif(ref $hashdata->{$_} eq 'SCALAR' or ref $hashdata->{$_} eq ''){ #it's an absolute, not a reference....

		if(defined $outputs->{$outputpath}){
			#if(ref($outputs->{$outputpath}) eq 'SCALAR' or ref($outputs->{$outputpath}) eq ''){
			#	my @temparray=($outputs->{$outputpath},$hashdata->{$_});
			#	delete $outputs->{$outputpath};
			#	$outputs->{$outputpath}=\@temparray;
			#} else {
			#	push @{$outputs->{$outputpath}},$hashdata->{$_};
			#}
			$outputs->{$outputpath}=$outputs->{$outputpath}.$delimiter.$hashdata->{$_};
		} else {
			$outputs->{$outputpath}=$hashdata->{$_};
		}
	} else {
		print "WARNING: fold_key - unrecognised type '".ref($hashdata->{$_})."' for key $_\n";
	}
}
}

sub process_file {
my $filename=shift;

if(not -f $filename){
	print STDERR "-ERROR: XML file '".$filename."' does not exist.\n";
	exit 1;
}

if($debug){
	print "INFO: Loading file ".$filename."...\n";
}

my $xmldata=XMLin($filename);

if($debug){
	print "INFO: Raw data read in:\n";
	print Dumper($xmldata);
	print "--------------------\n";
}

if(not $xmldata){
	print STDERR "-ERROR: Unable to read XML file  '".$filename."'.\n";
	exit 1;
}

my %output;

fold_key($xmldata,$ENV{'root_key'},\%output);

if($debug){
	print "INFO: Keys to output:\n";
	print Dumper(\%output);
	print "------------------\n";
}

return \%output;
}

#START MAIN
my $store=CDS::Datastore->new("read_generic_xml");

$debug=$ENV{'debug'};

$delimiter=',';
$delimiter=$ENV{'delimiter'} if($ENV{'delimiter'});

my @files;
push @files,$ENV{'cf_xml_file'} if($ENV{'cf_xml_file'});
push @files,$ENV{'cf_inmeta_file'} if($ENV{'cf_inmeta_file'});
push @files,$ENV{'cf_meta_file'} if($ENV{'cf_meta_file'});

if($ENV{'extra_files'}){
	my @extras=split /\|/,$store->substitute_string($ENV{'extra_files'});
	print "\tIncluding extra file $_\n" if($debug);
	push @files,@extras;
}

print "INFO: Files to read: @files\n" if($debug);

my @setargs=('meta');

foreach(@files){
	my $output=process_file($_);
	#print Dumper($output);
	foreach(keys %{$output}){
		push @setargs,$_;
		push @setargs,$output->{$_};
	}
}

if($debug){
	print Dumper(\@setargs);
}

$store->set(@setargs);

print "Read in successfully\n";
exit 0;
