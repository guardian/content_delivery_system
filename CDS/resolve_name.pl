#!/usr/bin/perl

use Getopt::Long;

#Use nslookup to find the address for a given server.  This may function as a work-around to the problems we've been having
#with lookups failing when run through octopus_run.

GetOptions("multiple"=>\$multiple);

if((scalar @ARGV)<1){
	print "Usage: resolve_name.pl [--multiple] {hostname}\n\n";
	print "Uses nslookup to find the host address for a given server, as a possible work-around when a \"normal\" name resolution fails\n";
	print "If multiple addresses are found, then one will be chosen at random unless the --multiple argument is set, in which case\n";
	print "they will all be returned, one per line\n";
	print "\nIf no addresses are found, then no output is given and the exit code \$? is set to 1.  Otherwise the exit code is 0.\n";
	exit 2;
}

my $to_resolve=$ARGV[0];
#print "running nslookup $to_resolve";

my @lines=`nslookup $to_resolve`;
my @addresses;

foreach(@lines){
	#this slightly unpleasant regex matches any line that:
	#  - starts with the string Address:
	#  - followed by any amount of whitespace (\s*)
	#  - followed by any amount of either digits or dots, capturing this portion as $1 ([\d\.]*)
	#  - followed by the end of the string
	#this should NOT match the first Address: {nameserver-ip}#53 line, as that contains a # in the numbers.
	if(/^Address:\s*([\d\.]*)$/){
		#print "debug: got address $1\n";
		push @addresses,$1;
	}
}

if(scalar @addresses < 1){
	print STDERR "Error - unable to find hostname $to_resolve\n";
	exit 1;
}

if(not defined $multiple){
	my $index=int(rand(scalar @addresses));
	print $addresses[$index] . "\n";
} else {
	print $_ . "\n" foreach(@addresses);
}
exit 0;