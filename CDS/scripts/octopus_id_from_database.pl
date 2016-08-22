#!/usr/bin/perl

#  This is a CDS module to allocate an Octopus ID from the database used by the Pluto system, to make up for there being no current octopus libraries for the linux platform
#  It allocates an ID and then outputs it to the datastore key specified, in the meta: section
#
#  Arguments:
#  <dbhost>hostname - connect to Postgres DB on this host
#  <dbname>database [OPTIONAL] - connect to the database with this name. Default: 'octopusid'
#  <dbuser>username - connect to the database with this username
#  <dbpass>password - connect to the database with this password
#  <identifier>blah - a string to record in the database what this has been allocated to. Should somehow evaluate to {commission-id}; {project-id}; {master-id}. Care needs to be taken to avoid duplicates.
#  <output_key>keyname [OPTIONAL] - output the acquired ID to this keyname in the meta: section. Defaults to 'octopus_ID'
#END DOC

use DBI;
use CDS::Datastore;

sub assert_args {
    foreach(@_){
        if (not defined $ENV{$_}) {
            print "-ERROR: You need to specify <$_> in the route file.\n";
            exit(1);
        }
    }
}

#START MAIN
our $store=CDS::Datastore->new('octopus_id_from_database');

assert_args(qw/dbhost dbuser dbpass identifier/);

our $dbhost=$store->substitute_string($ENV{'dbhost'});
our $dbname="octopusid";
if ($ENV{'dbname'}) {
    $dbname=$store->substitute_string($ENV{'dbname'});
}
our $dbuser=$store->substitute_string($ENV{'dbuser'});
our $dbpass=$store->substitute_string($ENV{'dbpass'});

our $output_key="octopus_ID";
if ($ENV{'output_key'}) {
    $output_key=$store->substitute_string($ENV{'output_key'});
}

our $identifier=$store->substitute_string($ENV{'identifier'});

my $fail=0;

#This is the string that will be given to the database to describe the object that this ID has been assigned to
my $identifier="| ".$identifier." |";

#connect to the database
my $dbh=DBI->connect("DBI:Pg:dbname=$dbname;host=$dbhost",$dbuser,$dbpass);
unless($dbh){
	print "-ERROR: Unable to connect to database: ".$dbh->error;
	exit 2;
}

$dbh->do("BEGIN");
#obtaining this lock should prevent any other instance reading or writing to the database, and should delay us until it is free
#The lock is automatically released at COMMIT
$dbh->do("LOCK TABLE ids IN ACCESS EXCLUSIVE MODE");
my $sth=$dbh->prepare("UPDATE ids SET allocated_to=?, allocated_at=now()
where id=(
        SELECT id FROM ids WHERE
                allocated_to is null
                or allocated_to=?
                order by id asc limit 1)
returning id");
my $result=$sth->execute($identifier,$identifier);
$dbh->do("COMMIT");

my $result=$sth->fetchrow_arrayref;
print "INFO: Got ID '".$result->[0].".\n";

print "INFO: Setting value in datastore\n";
$store->set('meta',$output_key,$result->[0]);
print "+SUCCESS: Allocated ID ".$result->[0]." output to meta:$output_key\n";
exit 0;
