package CDS::DBLogger;

use strict;
use warnings;
use Carp;
use Sys::Hostname;
use IO::Socket::INET;

use DBI;

sub new
{
my $class=shift;

my $self={};
bless($self,$class);
return $self;
}

sub connect
{
my ($self,%args)=@_;

my $dsnstart="DBI:mysql:database=";
if($args{'driver'}){
	$self->{'driver'}=$args{'driver'};
	my $dbspec="database=";
	$dbspec="dbname=" if($args{'driver'} eq "Pg");
	$dsnstart="DBI:".$args{'driver'}.":$dbspec";
}

my $dsn=$dsnstart.$args{'database'}.";host=".$args{'host'};
if($args{'port'}){
	$dsn=$dsn.";port=".$args{'port'};
}

$self->{'dbh'}=DBI->connect($dsn,$args{'username'},$args{'password'}) or
	confess "Unable to connect to DSN ".$dsn.": ".$DBI::errstr."\n";

$self->get_internal_statusid;
}

#note - this depends on the bin_from_uuid and uuid_from_bin functions being manually defined in the database.

sub get_internal_jobid
{
my($self,$externalid)=@_;

confess "Database not defined in get_internal_jobid" unless($self->{'dbh'});
my $sth=$self->{'dbh'}->prepare("select internalid from jobs where externalid=bin_from_uuid('$externalid')");
$sth->execute;

confess "Unable to find record for external ID '$externalid'" unless($sth->rows>0);
return $sth->fetchrow_arrayref()->[0];
}

use Data::Dumper;

sub get_local_ip_address {
my $local_ip_address;
eval {
    my $socket = IO::Socket::INET->new(
        Proto       => 'udp',
        PeerAddr    => '198.41.0.4', # a.root-servers.net
        PeerPort    => '53', # DNS
    );

    # A side-effect of making a socket connection is that our IP address
    # is available from the 'sockhost' method
    $local_ip_address = $socket->sockhost;
};
if($@){
	print STDERR "-WARNING: Could not determine internet-facing IP address. Maybe not connected?";
	return "unknown";
}
    return $local_ip_address;
}

sub touchTimestamp
{
my($self,%args)=@_;

unless($args{'job_id'}){
	confess "You need to specify a job_id to touch";
}
$self->{'dbh'}->do("update jobs set created=now() where externalid=uuid_from_bin('".$args{'job_id'}."')");

}

#note - this depends on the bin_from_uuid and uuid_from_bin functions being manually defined in the database.
sub newjob
{
my($self,%args)=@_;

my %meta;
#we recognise certain arguments. Anything else is generic metadata.
foreach(keys %args){
	next if($_ eq 'id');
	next if($_ eq 'files');
	$meta{$_}=$args{$_};
}

my $jobid=$args{'id'};

my $dbh=$self->{'dbh'};
#print "insert into jobs (externalid,routename,hostname,hostip) values (bin_from_uuid('".$args{'id'}."'),'".$args{'routename'}.",'".hostname."','".get_local_ip_address()."')";

$dbh->do("insert into jobs (externalid,routename,hostname,hostip) values (bin_from_uuid('".$args{'id'}."'),'".$args{'routename'}."','".hostname."','".get_local_ip_address()."')");

#this will throw an exception if it fails, the caller should catch it.
my $internalid=$self->get_internal_jobid($args{'id'});

print Dumper(\%args);
foreach(@{$args{'files'}}){
	$dbh->do("insert into jobfiles (jobid,filename) values ($internalid,'$_')");
}

foreach(keys %meta){
	#print "insert into jobmeta (jobid,identifier,value) values ($internalid,'$_','".$meta{$_}."')";
	my $sth=$dbh->prepare("insert into jobmeta (jobid,identifier,value) values (?,?,?)");
	$sth->execute($internalid,$_,$meta{$_});
}

return $internalid;
}

sub setMeta
{
my ($self,%args)=@_;

my $dbh=$self->{'dbh'};
my %meta;
#we recognise certain arguments. Anything else is generic metadata.
foreach(keys %args){
        next if($_ eq 'id');
        next if($_ eq 'metadata');
        $meta{$_}=$args{$_};
}

my $jobid=$args{'id'};

if($args{'metadata'} and ref $args{'metadata'} eq 'HASH'){	#hashref form of what we want...
	foreach(keys %{$args{'metadata'}}){
		$meta{$_}=$args{'metadata'}->{$_};
	}
}

#this will throw an exception if it fails, the caller should catch it.
my $internalid=$self->get_internal_jobid($args{'id'});

$dbh->do("BEGIN");
foreach(keys %meta){
	my $sth;
	if($self->{'driver'} eq 'Pg'){
	#See http://stackoverflow.com/questions/1109061/insert-on-duplicate-update-in-postgresql
		$sth=$dbh->prepare("update jobmeta set value=? where jobid=? and identifier=?");
		$sth->execute($meta{$_},$internalid,$_);
		$sth=$dbh->prepare("insert into jobmeta (jobid,identifier,value) select ?,?,? where not exists (select 1 from jobmeta where jobid=? and identifier=?)");
		$sth->execute($internalid,$_,$meta{$_},$internalid,$_);
	} else {
		$sth=$dbh->prepare("insert into jobmeta (jobid,identifier,value) values(?,?,?) on duplicate key update value=?");
		$sth->execute($internalid,$_,$meta{$_},$meta{$_});
	}
}
$dbh->do("COMMIT");
return $internalid;
}

sub get_internal_statusid
{
my($self,$name)=@_;

my $sth=$self->{'dbh'}->prepare("select * from status order by statusid");
$sth->execute;

my %statuses;
while(my $data=$sth->fetchrow_hashref){
	$self->{'statuses'}->{$data->{'desc'}}=$data;
}

return $statuses{$name} if($name);
return 1;
}

sub internal_log
{
my($self,%args)=@_;

$args{'priority'}=$self->{'statuses'}->{'log'} unless($args{'priority'});

foreach(qw/priority id message/){
	confess "You must define $_ when calling internal_log" unless($args{$_});
}

$args{'message'}=~s/\'/\\\'/g;

my $sth=$self->{'dbh'}->prepare("insert into log(externalid,log,status,methodname) values(bin_from_uuid('".$args{'id'}."'),?,'".$args{'priority'}->{'statusid'}."',?)");
$sth->execute($args{'message'},$args{'method'});
}

sub make_status
{
my($self,%args)=@_;

foreach(qw/id/){
	confess "You must define $_ when calling make_status" unless($args{$_});
}

my $sth=$self->{'dbh'}->prepare("insert into jobstatus(job_externalid,last_operation,route_status) values(bin_from_uuid('".$args{'id'}."'),?,?)");
$sth->execute("startup",'startup');
}

sub update_status
{
my($self,%args)=@_;

foreach(qw/id/){
	confess "You must define $_ when calling update_status" unless($args{$_});
}

#my $fieldlist="job_externalid"
#my @arglist;

print "debug: in update_status";
local $Data::Dumper::Pad="\t";
print Dumper(\%args);

$self->{'dbh'}->do('BEGIN');
if(defined $args{'status'}){
#	$fieldlist=$fieldlist.",route_status";
#	push @arglist,$args{'status'};
	my $sth=$self->{'dbh'}->prepare("update jobstatus set route_status=? where job_externalid=bin_from_uuid('".$args{'id'}."')");
	$sth->execute($args{'status'});
}
if(defined $args{'last_operation'}){
#	$fieldlist=$fieldlist.",last_operation";
#	push @arglist,$args{'last_operation'};
	my $sth=$self->{'dbh'}->prepare("update jobstatus set last_operation=? where job_externalid=bin_from_uuid('".$args{'id'}."')");
	$sth->execute($args{'last_operation'});
}
if(defined $args{'current_operation'}){
#	$fieldlist=$fieldlist.",last_operation";
#	push @arglist,$args{'last_operation'};
	my $sth=$self->{'dbh'}->prepare("update jobstatus set current_operation=? where job_externalid=bin_from_uuid('".$args{'id'}."')");
	$sth->execute($args{'current_operation'});
}

if(defined $args{'last_operation_status'}){
#	$fieldlist=$fieldlist.",last_operation_status";
#	push @arglist,$args{'last_operation_status'};
	my $sth=$self->{'dbh'}->prepare("update jobstatus set last_operation_status=? where job_externalid=bin_from_uuid('".$args{'id'}."')");
	$sth->execute($args{'last_operation_status'});
}

if(defined $args{'last_error'}){
#	$fieldlist=$fieldlist.",last_operation_status";
#	push @arglist,$args{'last_operation_status'};
	my $sth=$self->{'dbh'}->prepare("update jobstatus set last_error=? where job_externalid=bin_from_uuid('".$args{'id'}."')");
	$sth->execute($args{'last_error'});
}

$self->{'dbh'}->do('COMMIT');
}

sub logsuccess
{
my($self,%args)=@_;

$self->internal_log(priority=>$self->{'statuses'}->{'success'},%args);
$self->update_status(id=>$args{'id'},last_operation_status=>'success');
}

sub logfatal
{
my($self,%args)=@_;

$self->internal_log(priority=>$self->{'statuses'}->{'fatal'},%args);
$self->update_status(id=>$args{'id'},last_operation_status=>'error');
}

sub logerror
{
my($self,%args)=@_;

$self->internal_log(priority=>$self->{'statuses'}->{'error'},%args);
$self->update_status(id=>$args{'id'},last_operation_status=>'error');
}

sub logwarning
{
my($self,%args)=@_;

$self->internal_log(priority=>$self->{'statuses'}->{'warning'},%args);
$self->update_status(id=>$args{'id'},status=>'logwarning');
}

sub logmsg
{
my($self,%args)=@_;

$self->internal_log(priority=>$self->{'statuses'}->{'log'},%args);
}

sub logdebug
{
my($self,%args)=@_;

$self->internal_log(priority=>$self->{'statuses'}->{'debug'},%args);
}

1;

