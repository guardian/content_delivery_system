#!/usr/bin/perl

my $version='$Rev: 1295 $ $LastChangedDate: 2015-08-07 22:02:33 +0100 (Fri, 07 Aug 2015) $';

#Simple module to set a value to a key in the data store.
#Expects:
#<take-files>media - to get media file name/path if needed for substitution
#<key>blah 	   - the name of the key to set (no substitutions)
#<value>blah [OPTIONAL]	   - value to set for the key - can be blank.  All standard substitutions accepted.
#<filecontents>/path/to/file [OPTIONAL] - set the key to the contents of this text file, as opposed to setting a value directly
#<file_apply_substitutions/> [OPTIONAL] - if using filecontents, apply substitutions to the value that comes from the file
#<regex> [OPTIONAL] - perform a search and replace on the value using this regex. If value is not provided, then this will be performed on the current value of the field.  Substitutions are NOT accepted for the regex parameter, because the substitution code uses a regex as it is so might break things
#<replace> [OPTIONAL] - string to replace stuff that matches <regex> with
#<no_overwrite/> [optional] - do not set the key if one already exists
#<nooverwrite/>
#<dontoverwrite/>
#<no_error/>	[optional] - supress [value not present] if the value does not exist
#END DOC

use CDS::Datastore;
use File::Slurp qw/read_file/;

#START MAIN
my $store=CDS::Datastore->new('set_key');

$store->{'debug'}=$ENV{'debug'};

foreach(qw/key/){
	if(not defined $ENV{$_}){
		print "-ERROR - you need to specify <$_> to use this module.\n";
		exit 1;
	}
}

my $key=$ENV{'key'};
if($key eq ''){
	print "-ERROR - you need to specify a value in <key> to set a metadata key.\n";
	exit 1;
}

my @keyparts=split /:/,$ENV{'key'};
#if no section is specified, default to "meta"
if(scalar @keyparts==1){
	$keyparts[1]=$ENV{'key'};
	$keyparts[0]="meta";
	$key="meta:$key";
}

if($keyparts[0] eq "track"){
	splice @keyparts,1,0,'type';
}

my $existing_value=$store->get(@keyparts,undef);
if($ENV{'no_overwrite'} or $ENV{'nooverwrite'} or $ENV{'dontoverwrite'}){
	if($existing_value){
		print "-WARNING - Value $val already set for $key. Not over-writing as per user request. To change this, remove <no_overwrite/> from the routefile.\n";
		exit 0;
	}
}

my $value=$existing_value;
my $finalstring=$existing_value;

if($ENV{'value'}){
    $value=$ENV{'value'};
    $value=~tr/(/\(/;
    $value=~tr/)/\)/;

    #print "INFO: Got initial value '$value' for '$key'\n";

    $finalstring=$store->substitute_string($value);
    $finalstring="" if($finalstring eq 'true');	#exception - if 'value' is set to a blank string, then cds_run maps this to a "true" value,
                                    #since in xml there is no difference between <value/> (=> value is a true/false choice) and <value><value/> (=>value is an empty string)

    if($ENV{'no_error'}){
        $finalstring="" if($finalstring eq '[value not present]');
    }
}

if($ENV{'filecontents'}){
	my $filename=$store->substitute_string($ENV{'filecontents'});
	print "INFO: reading value from $filename\n";
	$value=read_file($filename, binmode=>':utf8');
	print "INFO: got value $value\n";
	if(not defined $value){
		print "-ERROR: Unable to read value from $filename\n";
		exit(1);
	}
    $value=~tr/(/\(/;
    $value=~tr/)/\)/;
    
    if($ENV{'file_apply_substitutions'}){
    	$finalstring=$store->substitute_string($value);
    } else {
    	$finalstring=$value;
	}
	    	
    $finalstring="" if($finalstring eq 'true');	#exception - if 'value' is set to a blank string, then cds_run maps this to a "true" value,
                                    #since in xml there is no difference between <value/> (=> value is a true/false choice) and <value><value/> (=>value is an empty string)

    if($ENV{'no_error'}){
        $finalstring="" if($finalstring eq '[value not present]');
    };   
}

if($ENV{'regex'} and $ENV{'replace'}){
    $regex=$ENV{'regex'};
    $replace=$store->substitute_string($ENV{'replace'});
    $finalstring=~s/$regex/$replace/;
}

print "INFO: Setting '$key' to '$finalstring' in the metadata stream...\n"; 
$store->set(@keyparts,$finalstring,undef);
print "+SUCCESS: Value set.\n";

