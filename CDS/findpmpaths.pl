#!/usr/bin/perl

#This script tries to find a 'sensible' place to install .pm files
#It's fairly simple; after searching Perl's @INC list it tries to find a location that:
# Conforms to /Library/(version-number), starts with /Library, contains Library, starts with /usr/lib, starts with /usr/local/lib, contains /lib/, or failing that uses the first entry in the list

my @wantedpaths=qw:^/Library/Perl/[\d\.]+$ ^/Library /Library ^/usr/lib ^/usr/local/lib /lib/:;

if(scalar @INC<1){
	print STDERR "Error finding perl install path - INC appears to be empty! Unable to continue.\n";
	exit 1;
}

foreach(@wantedpaths){
	my $trypath=$_;
		foreach(@INC){
		if($_=~/$trypath/){
			print "$_\n";
			exit 0;
		}
	}
}
print $INC[0]."\n";
exit 0;
