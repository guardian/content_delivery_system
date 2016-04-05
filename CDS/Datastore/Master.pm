package CDS::Datastore::Master;

use base qw /CDS::Datastore/;

sub doStatement {
my ($self,$statement)=@_;

my $rv;

my $rq=$self->{'dbh'}->prepare($statement);
$rv=$rq->execute();

if(not defined $rv){
	print STDERR "CDS::Datastore::doStatement - Database error - ".$dbh->errstr."\n";
}
}

sub init {
my $self=shift;

if(not $self->isValid){
	print STDERR "CDS::Datastore::init - ERROR - datastore not valid.\n";
	return 0;
}

#FIXME - we should check if the db has already been initialised
#here

#initialise the tables
my $rv;
my $dbh=$self->{'dbh'};

$self->doStatement("BEGIN");
$self->doStatement("CREATE TABLE sources (id integer primary key autoincrement,type,provider_method,ctime,filename,filepath)");
#key is not unique, as there could be multiple values from different sources.
#the default get() should return the most recent available.
$self->doStatement("CREATE TABLE meta (id integer primary key autoincrement,source_id,key,value)");
$self->doStatement("CREATE TABLE system (schema_version,cds_version)");
$self->doStatement("CREATE TABLE tracks (id integer primary key autoincrement,source_id,track_index,key,value)");
$self->doStatement("CREATE TABLE media (id integer primary key autoincrement,source_id,key,value)");
$self->doStatement("COMMIT");

$self->doStatement("INSERT INTO system (schema_version,cds_version) VALUES (1.0,2.0)");
return 1;
}

1;
