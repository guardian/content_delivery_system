#!/usr/bin/perl

use Data::Dumper;
eval "use Encode";

my $have_encode;
if($@){
	$have_encode=0;
} else {
	$have_encode=1;
	eval {
		use Encode;
	};
}

my @internal_modules=qw/CDS::Parser::saxmeta CDS::Datastore CDS::Datastore::Episode5 CDS::Parser::saxfcs CDS::octopus_simple octopus_simple saxRoutes saxnewsml File::Temp Data::UUID/;

#This script searches all other perl scripts in the directory below and finds modules that they reference, then checks to see if they're installed

sub is_internal {
my ($tocheck)=@_;

return 1 if($tocheck=~/^CDS::/);

foreach(@internal_modules){
	return 1 if($tocheck eq $_);
}
return 0;
}

sub check_is_installed {
my ($modulename)=@_;

my $stringtotest;
if($have_encode){
	$stringtotest=decode("utf8",$modulename);
} else {
	$stringtotest=$modulename;
}

eval "use $stringtotest;";
if($@){
	print STDERR "INFO: '$modulename' is not installed ($@)\n";
	return 1 if(is_internal($modulename));
	#die;
	return 0;
}
print STDERR "INFO: $modulename is installed\n";
return 1;
}

sub have_item {
my($needle,$haystack)=@_;

foreach(@$haystack){
	 return 1 if($needle eq $_);
}
return 0;
}

sub scan_script {
my($scriptpath,$moduleslist)=@_;

my $n;
open (my $fh,"<$scriptpath") or return 0;
print STDERR "scanning $scriptpath...\n";
foreach(<$fh>){
	if(/^\s*use ([^; ]+);/){
		my $modulename=$1;
		print STDERR "\t$scriptpath uses $1\n";
		push @$moduleslist,$modulename unless($modulename eq 'strict' or $modulename eq 'warnings' or check_is_installed($modulename) or have_item($modulename,$moduleslist));
	}
}
close $fh;
}

sub recurse_directory {
my ($path,$scriptlist)=@_;

opendir (my $dh,$path) or return;
print STDERR "recursing $path...\n";
my @list=readdir $dh;
closedir $dh;

foreach(@list){
#	print "$path/$_\n";
	if( -d "$path/$_"){
#		print "\tIS a directory\n";
		recurse_directory("$path/$_",$scriptlist) unless($_ eq '.' or $_ eq '..');
	} elsif(/\.(pl|pm)$/){
		push @$scriptlist,"$path/$_";
#		print "Got perl script $_\n";
	}
}

}

#check_is_installed("XML::SAX");
#check_is_installed("nothing");
my @scriptlist;
my @moduleslist;
my $do_install=1;

my $make=`which make`;
my $gcc=`which gcc`;
chomp $make;
chomp $gcc;

our $yestoall=0;
if ($ARGV[0]=="-y") {
	$yestoall=1;
}

if(! -x $make or ! -x $gcc){
	print "ERROR - missing tools with which to build modules.  This means I can't auto-install.  If you're on a Mac, please install Developer Tools.  On Linux, install Make, gcc et. al.\n";
	print "I will proceed with testing, but you will need to install the modules manually.\nPress ENTER to continue...";
	$junk=<> unless($yestoall);
	$do_install=0;
	print "\n";
}

#extra modules that need to be checked, that don't appear in use ; statements
#YAML is used by CPAN to store statuses etc.
#SSL, Net etc. are for ensuring that HTTPS will work, for communicating with HTTPS APIs (e.g., Level3)
foreach(qw/Crypt::SSLeay Net::SSLeay Net::IDN::Encode LWP::Protocol::https DBD::SQLite YAML/){
	push @moduleslist,$_ unless(check_is_installed($_));
}

recurse_directory(".",\@scriptlist);
print STDERR Dumper(\@scriptlist);

foreach(@scriptlist){
	scan_script($_,\@moduleslist);
}

print "Modules that need to be installed: @moduleslist\n";

if(scalar @moduleslist<1){
	print "Good news - you appear to have all the modules you need.\nEnjoy CDS!\n\n";
	exit 0;
}

my $cpan=`which cpan`;
chomp $cpan;
if(! -x $cpan){
	print STDERR "\n\nERROR: unable to find a runnable copy of CPAN.  Please manually install the following modules: @moduleslist\n";
	exit 1;
}

if($do_install){
	print "Installing cpanminimus...\n";
	system("curl -L https://cpanmin.us | perl - --sudo App::cpanminus");

	print "\n\nI am about to attempt an automatic installation of the modules @moduleslist.  You may be asked for your password, to allow this installer to make changes to your system.\n";
	print "\nI STRONGLY RECOMMEND that you update your CPAN installation before proceeding, otherwise strange installation errors have been known to crop up.\n\n";

	print "When CPAN asks you questions, you are safe to just press ENTER to accept the default values.\nYou will need to specify a mirror server to download from, just choose one near your location\nIf there is a problem, then re-run this script.  If there is still a problem, enter sudo rm -rf ~/.cpan in a Terminal window to delete your CPAN configuration.  Then re-run this script.\n\n";
	while(lc $doupdate !~/^y/ and lc $doupdate !~/^n/ and not $yestoall){
		print "Do you want to update your CPAN installation now (this may take a while)? (y/n) ";
		$doupdate=<>;
		chomp $doupdate;
	}
	#if(lc $doupdate =~/^y/ or $yestoall){
	#	print "\nAttempting update.....\n";
	#	system("sudo cpan -i Bundle::CPAN");
	#	print "\n---------------------------------------------------------\n";
	#	print "Update completed.  Now attempting to install modules...\n";
	#	print "---------------------------------------------------------\n";
	#} else {
	#	print "`nSkipping update.  If any module installs fail, then try running sudo cpan -i Bundle::CPAN and then retrying module install\n";
	#}
#Press ENTER to continue...";
#	$junk=<>;
	print "\n\n";
	$ENV{'PERL_MM_USE_DEFAULT'}=1;
	system("sudo cpanm -i @moduleslist");
	print "\n\nInstallation complete, assuming that you saw no errors above.  Enjoy CDS!\n";
} else {
	print "\n\nI am not able to attempt an automatic installation, probably because you are missing the Developer Tools for your platform.  Please install them then re-run this script, or\n
alternately run this command in a Terminal window: cpan -i @moduleslist.\n\nPlease save this message for future reference.\n\n";
}

