#!/usr/bin/perl

#This script collects the files from a CDS installation and copies them into a source tree for re-insertion into subversion
use Data::Dumper;

#Config
my @paths=( {'source'=>'/usr/local/lib/cds_backend', 'dest'=>'scripts' },
			{'source'=>'/etc/cds_backend/templates','dest'=>'scripts/templates'},
			{'source'=>'/Library/Perl/5.8.8/CDS','dest'=>'CDS'});

my @specific_files=qw/cds_run.pl cds_datareport.pl resolve_name.pl newsml_get.pl ee_get.pl cds_datastore.pl saxRoutes.pm saxnewsml.pm/;
my $specific_file_path='/usr/local/bin';

my $output_path="cds_backend_".`date +%y%m%d_%H%M%S`;
chomp $output_path;
#End config

#START MAIN
mkdir $output_path || die "Unable to create output path $output_path\n";

#chdir $output_path
foreach(@paths){
	my $src=$_->{'source'};
	my $dest=$output_path.'/'.$_->{'dest'};
	print STDERR "Copying $src to $dest...\n";
	my $output=`cp -R "$src" "$dest"`;
	if($? ne 0){
		print "Error during copy: $output\n";
	}
}

foreach(@specific_files){
	my $src=$specific_file_path.'/'.$_;
	my $dest=$output_path;
	print STDERR "Copying $src to $dest...\n";
	my $output=`cp -R "$src" "$dest"`;
	if($? ne 0){
		print "Error during copy: $output\n";
	}
}