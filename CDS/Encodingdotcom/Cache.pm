package CDS::Encodingdotcom::Cache;

use warnings;
use strict;
use DBI;
use File::Path qw/make_path/;
use File::Basename;

my $version='CDS::Encodingdotcom::Cache $Rev: 594 $ $LastChangedDate: 2013-11-27 14:55:56 +0000 (Wed, 27 Nov 2013) $';

#This module uses SQLite to cache the Media IDs assigned by Encoding.com along with their original source URLs.
#The main script uses this to look up if there is a cached ID, and if so tries to re-use this after
#having ascertained that it's not in use.

#Usage:
#  my $cache=CDS::Encodingdotcom::Cache->new('db'=>'/path/to/database','client'=>'module_name','debug'=>n);
#								#client identifies the caller for logging of stale locks and must be given.
#  my $id=$cache->lookup($sourceurl);
#  my $id=$cache->lookup_no_wait($sourceurl,n);	#n is the maximum age of the record, in seconds. If the record is locked then return immediately.
#
#  my $id=$cache->lookup($sourceurl,Timeout=>n); #Lookup sourceurl, and make a note in the database not to give this to anybody else.
#										if it's already locked, block until it isn't or until the timeout expires
#	FIXME: how to tell if timeout has expired or id doesn't exist?
# SHOULD IMPLEMENT:
#  my $id=$cache->lookup($sourceurl,Timeout=>n,Callback=>\&func);	#Lookup sourceurl and timeout as above.
#										# Call the specified callback function periodically while timeout is ongoing.
#  $cache->release($id);			#release a lock on the given ID
#
#  $cache->remove_all_by_name($name);
#
#  $cache->store($sourceurl,$id);	#store the id against the source URL.
#  my $info=$cache->get_lock_info($sourceurl);	#get info on the locks for this url.
#						will either return a hashref or an arrayref of hashrefs.
#  $cache->blow_locks;		#WARNING - this will remove ALL locks from the db, hence potentially break the entire system.

sub new {
my($proto,%args)=@_;
my $class=ref($proto) || $proto;	# allow us to be derived

my $self={};

$self->{'debug'}=$args{'debug'};
$self->{'version'}=$version;

$self->{'valid'}=1;

$self->{'max_retries'}=10;
$self->{'retry_delay'}=5;

$self->{'max_retries'}=$args{'max_retries'} if($args{'max_retries'});
$self->{'retry_delay'}=$args{'retry_delay'} if($args{'retry_delay'});

$self->{'client'}=$args{'client'};

print STDERR "CDS::Encodingdotcom::Cache->new - DEBUG - using database '".$args{'db'}."'\n";

  	my $db=$args{'db'};
  	if(not defined $db or $db eq ""){
  		print STDERR "CDS::Encodingdotcom::Cache->new  - ERROR - cache location is not set. Expect problems.\n";
  	}
  	
  	die "You must specify a client name to use the cache, by supplying ...'client'=>'name' in the code.\n" unless($self->{'client'});
  	my $needs_init=1 unless(-f $db);
  	
  	my $dbpathname=dirname($db);
  	make_path($dbpathname) if($dbpathname);
    $self->{'dbh'}=DBI->connect("dbi:SQLite:dbname=$db","","");
    #$self->{'valid'}=0    if(not defined $self->{'dbh'});
    die "-ERROR: Unable to connect to database" if(not defined $self->{'dbh'});
    bless ($self,$class);
    
    $self->init if($needs_init);
    
return $self;
}

sub version {
my $self=shift;

return $self->{'version'};
}

sub doStatement {
my ($self,$statement)=@_;

my $rv;

my $rq=$self->{'dbh'}->prepare($statement);
$rv=$rq->execute();

if(not defined $rv){
	print STDERR "CDS::Encodingdotcom::Cache::doStatement - Database error - ".$self->{'dbh'}->errstr."\n";
	return undef;
}
return 1;
}

sub init {
my $self=shift;

print "CDS::Encodingdotcom::Cache::init\n";

#initialise the tables
my $rv;
my $dbh=$self->{'dbh'};

$self->doStatement("BEGIN");
$self->doStatement("CREATE TABLE cache (id integer primary key autoincrement,mediaid unique,sourceurl unique,ctime)");
$self->doStatement("CREATE TABLE locks (id integer primary key autoincrement,locktype,lockedby,cacheid,ctime)");
$self->doStatement("COMMIT");
return 1;
}

sub get_lock_info {
my ($self,$sourceurl)=@_;

my $id=$self->lookup_internal($sourceurl);
return undef unless($id);

my $rq=$self->{'dbh'}->prepare("select * from locks where cacheid=$id");

my $rv;
my $attempt=0;
for(my $attempt=0;$attempt<$self->{'max_retries'};++$attempt){
	$rv=$rq->execute();
	last if($rv);
	print "Unable to execute command, attempt $attempt: ".$self->{'dbh'}->errstr.".\n";
	sleep($self->{'retry_delay'});
}
return undef unless($rv);

my @rtn;
while(my $data=$rq->fetchrow_hashref){
	push @rtn,$data;
}

return $rtn[0] if(scalar @rtn==1);
return \@rtn;
}

sub blow_locks {
my $self=shift;

return $self->doStatement("delete from locks");
}

sub make_lock {
my($self,$mediaid,%args)=@_;

my $starttime=time;
my $client=$self->{'client'};
$client=~s/'/''/;

return undef unless($mediaid=~/^\d+/);

return $self->doStatement("insert into locks (locktype,lockedby,cacheid,ctime) values (1,'$client',$mediaid,$starttime)");
}

sub release {
my($self,$mediaid,%args)=@_;
return undef unless($mediaid=~/^\d+/);

return $self->doStatement("delete from locks where cacheid=$mediaid");
}


sub remove_all_by_name {
my($self,$name)=@_;

return undef if(length $name<1);

return $self->doStatement('delete from cache where sourceurl like \'%'.$name.'%\'');
}

sub store {
my ($self,$sourceurl,$mediaid)=@_;

return -1 unless($mediaid=~/^\d+$/);

$sourceurl=~s/'/''/;

my $timestamp=time;

return $self->doStatement("insert into cache (mediaid,sourceurl,ctime) values ($mediaid,'$sourceurl',$timestamp)");
}

sub remove_by_id {
my ($self,$mediaid)=@_;

return -1 unless($mediaid=~/^\d+$/);

return $self->doStatement("delete from cache where mediaid=$mediaid");
}

#look up a cached record WITHOUT waiting
sub lookup_no_wait {
my($self,$sourceurl,$age)=@_;

my $id=$self->internal_lookup($sourceurl,$age);

return undef unless($id);

return undef if($self->is_locked($id));
return $id;
}

sub lookup {
my($self,$sourceurl,%args)=@_;

my $age=$args{'age'};
my $id=$self->internal_lookup($sourceurl,$age);

my $timeout=$args{'timeout'};
$timeout=$args{'Timeout'} if($args{'Timeout'});

return undef unless($id);

my $start_time=time;

while($self->is_locked($id)){
	sleep($self->{'retry_delay'});
	if($args{'verbose'}){
		my $lockinfo=$self->get_lock_info($id);
		print STDERR "WARNING: - record $id is locked by ".$lockinfo->{'lockedby'}." since ".$lockinfo->{'ctime'}."\n";
	}
	if($timeout){
		if(time>$start_time+$timeout){
			print STDERR "WARNING: - record $id is still locked after $timeout seconds. exiting.\n";
			return undef;
		}
	}
}
$self->make_lock($id);

return $id;
}

sub internal_lookup {
my($self,$sourceurl,$age)=@_;

$sourceurl=~s/'/''/;

my $rq;

if($age and $age=~/^\d+$/){
	my $mintime=time-$age;
	$rq=$self->{'dbh'}->prepare("select * from cache where sourceurl='$sourceurl' and ctime>$mintime");
} else {
	#print "select * from cache where sourceurl='$sourceurl'\n";
	$rq=$self->{'dbh'}->prepare("select * from cache where sourceurl='$sourceurl'");
}

my $rv;
my $attempt=0;
for(my $attempt=0;$attempt<$self->{'max_retries'};++$attempt){
	$rv=$rq->execute();
	last if($rv);
	print "Unable to execute command, attempt $attempt: ".$self->{'dbh'}->errstr.".\n";
	sleep($self->{'retry_delay'});
}
print "sqlite returned $rv.\n";
return undef unless($rv);

#didn't get a result.
#return undef if($rq->rows<1) ;

my $data=$rq->fetchrow_hashref;
return $data->{'mediaid'};
}

sub is_locked {
my($self,$id)=@_;

my $rq;
my $rv;

$rq=$self->{'dbh'}->prepare("select * from locks where cacheid=$id");
for(my $attempt=0;$attempt<$self->{'max_retries'};++$attempt){
	$rv=$rq->execute();
	last if($rv);
	print "Unable to execute command, attempt $attempt: ".$self->{'dbh'}->errstr.".\n";
	sleep($self->{'retry_delay'});
}
print "sqlite returned $rv.\n";
return undef unless($rv);

my $data=$rq->fetchrow_hashref;
 return 1 if($data->{'locktype'});	#this is locked if there's a record here

return 0;

}

1;
