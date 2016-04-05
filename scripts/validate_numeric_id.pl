#!/usr/bin/perl
my $version = 'validate_numeric_id $Rev: 1195 $ $LastChangedDate$';
#This CDS method ensures that the given datastore fields are, in fact, numeric IDs without any leading/trailing
#characters
#
#Arguments:
#  <keys>key1{|key2|key3|...} - validate these keys
#  <fix/> - replace them with numeric only values as opposed to erroring if they do not conform
#  <error_immediate/> - immediately throw an error if a value is not a numeric id
#END DOC

use CDS::Datastore;

#START MAIN
my $store=CDS::Datastore->new('validate_numeric_id');

my @keys_to_check = split /\|/,$ENV{'keys'};
my @values_to_check;
my @set_args;

my $n=0;
foreach(@keys_to_check){
	$values_to_check[$n]=$store->get('meta',$_);
	print "Validating key '$_' with value '".$values_to_check[$n]."'\n";
	
	if($values_to_check[$n] =~ /^\s*(\d+)\s*/){
		if($1 eq $values_to_check[$n]){
			print "\tValue is correctly a numeric-only ID\n";
		} else {
			print "\tReducing value to only numeric id '$1'\n";
			push @set_args,$_,$1;
		}
	} else {
		print "Value does not contain any numeric id\n";
		if($ENV{'error_immediate'}){
			print "-ERROR: Non-numeric value found, and <error_immediate> was set\n";
			exit(1);
		}
	}
}

if(scalar @set_args>0){
	print "Values that need fixing: @set_args\n";
	if($ENV{'fix'}){
		sleep(2);	#ensure that the value set here has a later timestamp than the old one
		$store->set('meta',@set_args);
		print "+SUCCESS: Fixed numeric values in the datastore\n";
	} else {
		print "-WARNING: Not fixing invalid numeric values, because <fix/> was not specified\n";
	}
} else {
	print "+SUCCESS: All values are correctly numerics";
}
