#!/usr/bin/perl

my $version='make_symlink.pl $Rev: 950 $ $LastChangedDate: 2014-07-27 10:35:04 +0100 (Sun, 27 Jul 2014) $';

#This method creates a symbolic link (alias) from the given file(s) to a specified target
#Arguments:
# <take-files>{media|inmeta|meta|xml} - symlink from these files
# <target>/path/to/file|{meta:filepath} - create the symlink here.  Substitutions accepted. If multiple values are given, separate them with | characters; they are applied in the same order as the given take-files.
# <destination> - same as target
#END DOC

use CDS::Datastore;
use File::Basename;
use File::Spec::Functions;

#START MAIN
my $store=CDS::Datastore->new('make_symlink');
my $debug=$ENV{'debug'};

my @source_files,@targets;
foreach(qw/media inmeta meta xml/){
	my $spec="cf_".$_."_file";
	if($ENV{$spec}){
		if(-f $ENV{$spec}){
			push @source_files,$ENV{$spec};
			print "Source $_ file added: ".$ENV{$spec}."\n" if($debug);
		} else {
			print "-WARNING: $_ file ".$ENV{$spec}." does not exist.\n";
		}
	}
}

if(scalar @source_files<1){
	print "-ERROR: No files available to link.\n";
	exit 1;
}

my $targetspec=$ENV{'destination'};
if($ENV{'target'}){
	$targetspec=$ENV{'target'};
}

foreach(split /\|/,$targetspec){
	push @targets,$store->substitute_string($_);
	print "Target file added: $_\n" if($debug);
}

my $n=0;
foreach(@source_files){
	my $r=0;
	my $target;
	if($n>scalar @targets){
		$target=$targets[0];
	} else {
		$target=$targets[$n];
	}
	
	if(-d $target){
		print "$target is a directory. Linking from $_ to ".catfile($target,basename($_)),"\n";
		$r=symlink $_,catfile($target,basename($_));
	} else {
		print "Linking from $_ to $target\n";
		$r=symlink $_,$target;
	}
	if($r!=1){
		print "-ERROR: Unable to create symlink from '$_' to '$target': $!\n";
		exit 1;
	}
	++$n;
}

print "+SUCCESS: $n files have been symlinked\n";
