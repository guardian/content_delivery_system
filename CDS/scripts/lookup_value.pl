#!/usr/bin/perl

#Sets a datastore key based on a lookup table
#You need to specify a source_table and a dest_table, each as an array.
#when the input_string matches an entry in source_table, the meta key
#given by output_key is set to the corresponding entry in dest_table.
#Normally the matching is done by a straight string a=string b comparison,
#but if you specify the <regex/> option then the entries in source_table are
#compared as regexes.  This is the simplest way to do string a contains string b comparison; simply specifying <regex/> without putting any special characters in the source_table will match as string a contains string b.
#For more information on regexes, google 'perl regex introduction'.
#
#Arguments:
# <input_string> - the string to compare to the source table. Normally you would put in at least one substitution, e.g. {meta:title}.
# <output_key> - the key in the meta section of the datastore to output to
# <source_table>input_a|input_b|... - a list of values to compare to the input_string. Normally string matching is done by =, but these can be interpreted as regexes.
# <dest_table>output_a|output_b|... - a list of values to set output_key to if input_string matches the corresponding entry in source_table.
# <default>output_z [OPTIONAL] - output this value if no entries in source_table match input_string
# <case_insensitive/> [OPTIONAL] - compare input_string and source_table entries case-insensitively
# <regex/> [OPTIONAL] - interpret the entries in the source_table list as regexes. The corresponding dest_table entry will be selected if input_string matches a given source_table regex.
#END DOC

use CDS::Datastore;

sub check_args {
    my $failed=0;
    foreach(@_){
        unless($ENV{$_}){
            print "-ERROR: You need to specify <$_> in the routefile.\n";
            $failed=1;
        }
    }
    exit(1) if($failed);
}

#START MAIN
check_args(qw/input_string output_key source_table dest_table/);
my $store=CDS::Datastore->new("lookup_value");

my $input=$store->substitute_string($ENV{'input_string'});
$input=lc $input if($ENV{'case_insensitive'});

my $output_key=$store->substitute_string($ENV{'output_key'});

my $source_table=$store->substitute_string($ENV{'source_table'});
$source_table=lc $source_table if($ENV{'case_insensitive'});
my @source_values=split /\s*\|\s*/,$source_table;

my @dest_values=split /\s*\|\s*/,$store->substitute_string($ENV{'dest_table'});

if(scalar @source_values!=scalar @dest_values){
    print "-WARNING: The number of source_values does not equal the number of dest_values. You may get unexpected results."
}

my $rtn="";
$rtn=$store->substitute_string($ENV{'default'}) if($ENV{'default'});
my $n=0;
print "INFO: Matching $input against @source_values\n";
print "INFO: Destination values: @dest_values\n";

foreach(@source_values){
    if($ENV{'regex'}){
        if($input=~/$_/){
            $rtn=$dest_values[$n];
            last;
        }
    } else {
        if($input eq $_){
            $rtn=$dest_values[$n];
            last;
        }
    }
    
    ++$n;
}

print "INFO: Got $rtn\n";
$store->set('meta',$output_key,$rtn);
