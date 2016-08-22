#!/usr/bin/perl

my $version='$Rev: 1069 $ $LastChangedDate: 2014-10-02 18:34:28 +0100 (Thu, 02 Oct 2014) $';

#This script will delete logs from the logging database that are older than a specified
#amount of time.

use Getopt::Long;
use CDS::DBLogger;
use DBI;

our $configFileLocation="/etc/cds_backend.conf";
our $dbh;

#taken from cds_run
sub readConfigFile
{
my $fh;
my %data;

unless(open $fh,"<$configFileLocation"){
	print STDERR "INFO: Cannot read a configuration file at $configFileLocation. This is not likely to cause a problem\n";
	return \%data;	#return an empty hash
}

while(<$fh>){
	next if(/^#/);
	if(/^\s*([^=]+)\s*=\s*(.*)\s*$/){
		#print "DEBUG: Got value $2 for key $1\n";
		my $key=$1;
		my $val=$2;
		$key=~s/\s//g;
		$val=~s/\s//g;
		$data{$key}=$val;
	}
}
close $fh;

#print Dumper(\%data);
#die "Testing";
return \%data;
}

sub getJobsOverThreshold
{
my $expiryThreshold=shift;

my @results;
#Note - will only work with postgres i think.
my $sth=$dbh->prepare("select * from jobs where created < now() - interval \'$expiryThreshold days\' order by created asc");
$sth->execute();

while($data = $sth->fetchrow_hashref){
	push @results,$data;
}

return @results;
}

sub purgeJob
{
my $job=shift;

print "Attempting to purge job with internal id ".$job->{'internalid'}." and external id ".$job->{'externalid'}."\n";

#return;

$dbh->do("begin");

my $sth=$dbh->prepare("delete from jobfiles where jobid=?");
$sth->execute($job->{'internalid'});

$sth=$dbh->prepare("delete from jobmeta where jobid=?");
$sth->execute($job->{'internalid'});

$sth=$dbh->prepare("delete from jobstatus where job_externalid=?");
$sth->execute($job->{'externalid'});

$sth=$dbh->prepare("delete from log where externalid=?");
$sth->execute($job->{'externalid'});

$sth=$dbh->prepare("delete from jobs where internalid=?");
$sth->execute($job->{'internalid'});

$dbh->do("commit");
print "Done\n";
}

#START MAIN
our $logDB,$dbHost,$dbUser,$dbPass,$dbDriver,$expiryThreshold;

my $configData=readConfigFile();

GetOptions( "logging-db=s" =>\$logDB,
		    "db-host=s" =>\$dbHost,
		    "db-login=s" =>\$dbUser,
		    "db-pass=s" =>\$dbPass,
		    "db-driver=s" =>\$dbDriver,
		    "expire-older=i" => \$expiryThreshold );

$dbHost=$configData->{'db-host'} unless($dbHost);
$logDB=$configData->{'logging-db'} unless($logDB);
$dbUser=$configData->{'db-login'} unless($dbUser);
$dbPass=$configData->{'db-pass'} unless($dbPass);
$dbDriver=$configData->{'db-driver'} unless($dbDriver);

print "Attempting to connect to $logDB on $dbHost...\n";
$externalLogger=CDS::DBLogger->new;
$externalLogger->connect('driver'=>$dbDriver,
			'database'=>$logDB,
			'host'=>$dbHost,
			'username'=>$dbUser,
			'password'=>$dbPass);

$dbh=$externalLogger->{'dbh'};

my @jobsToPurge=getJobsOverThreshold($expiryThreshold);

print "Found ".scalar @jobsToPurge." jobs over $expiryThreshold days\n\n";

foreach(@jobsToPurge){
	purgeJob($_);
}
