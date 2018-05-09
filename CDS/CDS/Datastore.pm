package CDS::Datastore;

use DBI;
use File::Spec;

my $configDefinitionsDir = "/etc/cds_backend/conf.d/";

sub new {
    my ($proto,$modulename,$debug)=@_;
    my $class=ref($proto) || $proto;    #this allows other classes to derive from us, the arg passed is the child class
  
    my $self={};

    $self->{'debug'}=1 if($debug);  
  	print STDERR "CDS::Datastore->new ($proto)- DEBUG - using database '".$ENV{'cf_datastore_location'}."'\n";
  	
  	if(not defined $modulename or $modulename eq ""){
  		die "CDS::Datastore->new - FATAL - You must supply a module name to initialise a datastore.\n";
  	}
  	
  	my $db=$ENV{'cf_datastore_location'};
  	if(not defined $ENV{'cf_datastore_location'} or $ENV{'cf_datastore_location'} eq ""){
  		print STDERR "CDS::Datastore->new - ERROR - cf_datastore_location is not set. Expect problems.\n";
  	}
    $self->{'dbh'}=DBI->connect("dbi:SQLite:dbname=$db","","");
    $self->{'valid'}=0    if(not defined $self->{'dbh'});
    $self->{'module'}=$modulename;
    $self->{'version'}="v1.0";
    bless($self,$class);

	$self->loadDefs($configDefinitionsDir);
    return $self;
}

sub msg {
my ($self,$msg)=@_;

print STDERR "CDS::Datastore - $msg\n";
if(fileno(LOGFILE)){
	print LOGFILE "CDS::Datastore - $msg\n";
}
}

sub warn {
my ($self,$msg)=@_;

$self->msg("WARNING - $msg");
}

sub error {
my ($self,$msg)=@_;

$self->msg("ERROR - $msg");
}

sub readDefsFile {
my ($self,$filename) = @_;
$self->msg("Reading static site config defintions from $filename...\n") if($self->{'debug'});

my $totalDefs = 0;

open(my $fh,"<:utf8",$filename);
if(not $fh){
	$self->error("Unable to open $filename: $!\n");
	return 0;
}
while( <$fh>){
	#print "$_\n";
	next if(/^#/);
	chomp;
	if(/^\s*([^=]+)\s*=\s*(.*)$/){
		my $key=$1;
		my $val=$2;
		$key =~ s/^\s+|\s+$//g;	#strip leading and trailing whitespace
		$val =~ s/^\s+|\s+$//g;
		$self->msg("Loaded config definition $key=$val\n") if($self->{'debug'});
		$self->{'defs'}->{$key} = $val;
		++ $totalDefs;
	}
}
close($fh);
return $totalDefs;
}

sub loadDefs {
my ($self,$dir)=@_;

if(not -d $dir){
	$self->error("Directory $dir for static definitions does not exist\n");
	return -1;
}

opendir(my $dh,$dir);
if(not $dh){
	$self->error("Unable to open directory $dir for static definitions: $!\n");
	return -1;
}

$self->{'defs'}={};

my $totalDefs = 0;
while(my $filename = readdir($dh)){
	my $filepath = File::Spec->catfile($dir,$filename);
	#print "debug: got filepath $filepath\n";
	next if(not -f $filepath);
	next if($filename=~/^\./);
	$totalDefs += $self->readDefsFile($filepath);
}
closedir($dh);
return $totalDefs;
}

sub isValid {
my $self=shift;

return 0 if(not defined $self->{'dbh'});
return 1;
}

sub getSource {
my($self,$type,$filename,$filepath)=@_;

#modulename is held in $self.
my $modulename=$self->{'module'};

my $rq=$self->{'dbh'}->prepare("SELECT id FROM sources WHERE type='$type' and provider_method='$modulename' and filename='$filename'");
$rq->execute();

$data=$rq->fetchrow_hashref;
return $data->{'id'} if(defined $data);

$filepath=File::Spec->rel2abs($filepath);

#source didn't exist in the table, so add it in.
my $ctime;
if(-f "$filepath/$filename"){
	my @statinfo=stat("$filepath/$filename");
	$ctime=$statinfo[10];
} else {
	$filepath="";
	$filename="";
	$ctime=time;
}

$rq=$self->{'dbh'}->prepare("INSERT INTO sources (type,provider_method,ctime,filename,filepath) values ('$type','$modulename','$ctime','$filename','$filepath')");
$rq->execute;

#now retry getting the data
$rq=$self->{'dbh'}->prepare("SELECT id FROM sources WHERE type='$type' and provider_method='$modulename' and filename='$filename'");
$rq->execute();

$data=$rq->fetchrow_hashref;
return $data->{'id'} if(defined $data);

$self->error("Unable to create source record: ".$self->{'dbh'}->errstr."\n");
return -1;
}

sub find_value{
my($self,$key,$reference)=@_;

my $n;

while(defined $$reference[$n]){
	return $$reference[$n+1] if($key eq $$reference[$n]);
	$n+=1;
}
return undef;
}

sub getTrackId{
my($self,$sourceid,$trackType,$noCreate)=@_;

my $rq=$self->{'dbh'}->prepare("SELECT track_index,value from tracks where key='type'");
$rq->execute;
while(my $data=$rq->fetchrow_hashref){
	#print STDERR Dumper($data);
	return $data->{'track_index'} if($data->{'value'} eq $trackType);
}

return undef if($noCreate);

#if we get here we don't have a track of this type yet.
#first get the maximum track_index
my $trackindex;
$rq=$self->{'dbh'}->prepare("SELECT track_index FROM tracks ORDER BY track_index desc");
$rq->execute;
if(my $data=$rq->fetchrow_hashref){
	$trackindex=$data->{'track_index'}+1;
} else {
	$trackindex=0;
}

my $querystr="INSERT INTO tracks (source_id,track_index,key,value) VALUES ('$sourceid',$trackindex,'type','$trackType')";
$rq=$self->{'dbh'}->prepare($querystr);
$rq->execute;
return $trackindex;
}

#this implements the actual SET functionality
#it requires a valid source id, that is NOT CHECKED.
#hence for internal use only.
#usage: $store->internalSet($sourceid,$type,$key,$val,$key,$val,...)
sub internalSet {
$self=shift;
$sourceid=shift;
$type=shift;


my $key,$val;

 return -1 if(not defined $sourceid);

if($type eq 'meta'){
	my $rq=$self->{'dbh'}->prepare("BEGIN");
	$rq->execute;
	do{
		$key=shift;
		$val=shift;
		if(defined $key and defined $val){
			#make suitable for SQL statements by escaping any ' characters
			$key=~s/'/''/g;
			$val=~s/'/''/g;
			#$self->msg("debug - key=$key val=$val");
			my $querystr="INSERT INTO meta (source_id,key,value) VALUES ('$sourceid','$key','$val')";
			$rq=$self->{'dbh'}->prepare($querystr);
			$rq->execute();
		}
	} while(defined $key and $key ne "");
	$rq=$self->{'dbh'}->prepare("COMMIT");
	$rq->execute;
	$self->msg("INFO - set ".$rq->rows." rows of data.\n");
} elsif($type eq 'track') {
	my $trackType=$self->find_value('type',\@_);
	my $trackId=$self->getTrackId($sourceid,$trackType);
	
	my $rq=$self->{'dbh'}->prepare("BEGIN");
	$rq->execute;
	do{
		$key=shift;
		$val=shift;
		if(defined $key and defined $val){
			#make suitable for SQL statements by escaping any ' characters
			$key=~s/'/''/g;
			$val=~s/'/''/g;
			#$self->msg("debug - key=$key val=$val");
			my $querystr="INSERT INTO tracks (source_id,track_index,key,value) VALUES ('$sourceid',$trackId,'$key','$val')";
			$rq=$self->{'dbh'}->prepare($querystr);
			$rq->execute();
		}
	} while(defined $key and $key ne "");
	$rq=$self->{'dbh'}->prepare("COMMIT");
	$rq->execute;
	$self->msg("INFO - set ".$rq->rows." rows of data.\n");
} elsif($type eq 'media') {
	my $rq=$self->{'dbh'}->prepare("BEGIN");
	$rq->execute;
	do{
		$key=shift;
		$val=shift;
		if(defined $key and defined $val){
			#make suitable for SQL statements by escaping any ' characters
			$key=~s/'/''/g;
			$val=~s/'/''/g;
			#$self->msg("debug - key=$key val=$val");
			my $querystr="INSERT INTO media (source_id,key,value) VALUES ('$sourceid','$key','$val')";
			#$self->msg("debug: $querystr");
			$rq=$self->{'dbh'}->prepare($querystr);
			$rq->execute();
		}
	} while(defined $key and $key ne "");
	$rq=$self->{'dbh'}->prepare("COMMIT");
	$rq->execute;
	$self->msg("INFO - set ".$rq->rows." rows of data.\n");
} else {
	$self->warn("Unrecognised metadata type '$type'");
}
}

#public-facing version of the SET functionality
#usage: $store->set($type,$key,$val,$key,$val,...)
sub set {
my $self=shift;
my($type)=@_;

my $sourceid=$self->getSource($type,undef,undef);
if($sourceid<1){
	$self->error("Unable to get a source record, bailing.");
	return -1;
}

my @args;
push @args,$sourceid;
push @args,@_;

$self->internalSet(@args);
}

#usage: $value=$store->get($type,$key) or @values=$store->get($type,$key,$key,...)
#if you're getting track metadata, use $value=$store->get($type,'vide',$key,...) etc.
#if there are multiple values, it returns the one from the most recent source.
sub get {
my $self=shift;
my $type=shift;

my @rtn;
if($type eq 'meta'){
	foreach(@_){
		my $key=$_;
		$key=~s/'/''/;
		my $querystr="SELECT value,type,ctime FROM meta left join sources on source_id=sources.id WHERE key='$key' order by ctime desc, sources.id desc";
		my $query=$self->{'dbh'}->prepare($querystr);
		$query->execute;
		if(my $data=$query->fetchrow_hashref){
			push @rtn,$data->{'value'};
		}
	}
	return $rtn[0] if(scalar @rtn<2);
	return @rtn;
} elsif($type eq 'track') {
	my $tracktype=shift;
	my $trackindex=$self->getTrackId(undef,$tracktype,1);	#should not try to create
	if(not defined $trackindex){
		$self->warn("Unable to find a track index for type '$tracktype'");
		return undef;
	}
	
	foreach(@_){
		my $key=$_;
		$key=~s/'/''/;
		my $querystr="SELECT value,type,ctime FROM tracks left join sources on source_id=sources.id WHERE track_index=$trackindex and key='$key' order by ctime desc";
		my $query=$self->{'dbh'}->prepare($querystr);
		$query->execute;
		if(my $data=$query->fetchrow_hashref){
			push @rtn,$data->{'value'};
		}
	}
	return $rtn[0] if(scalar @rtn<2);
	return @rtn;	
} elsif($type eq 'media' or $type eq 'media') {
	foreach(@_){
		my $key=$_;
		$key=~s/'/''/;
		my $querystr="SELECT value,type,ctime FROM media left join sources on source_id=sources.id WHERE key='$key' order by ctime desc";
		my $query=$self->{'dbh'}->prepare($querystr);
		$query->execute;
		if(my $data=$query->fetchrow_hashref){
			push @rtn,$data->{'value'};
		}
	}
	return $rtn[0] if(scalar @rtn<2);
	return @rtn;
} else {
	$self->warn("Unrecognised metadata type '$type'");
}

return undef;
}

#by default, this returns a hash of ALL metadata keys.
#when there are duplicates from different sources, the newest one (as determined by the ctime field) is used
sub get_meta_hashref {
my $self=shift;

my %rtn;

my $querystr="SELECT key,value,type,ctime FROM meta left join sources on source_id=sources.id order by ctime desc,meta.id desc,key";

my $query=$self->{'dbh'}->prepare($querystr);
$query->execute;

while(my $data=$query->fetchrow_hashref){
	$rtn{'meta'}->{$data->{'key'}}=$data->{'value'} if(not defined $rtn{'meta'}->{$data->{'key'}});
}
return \%rtn;
}

#this returns all values for a specific metadata key
#returned as an array of hash refs
#usage: @values=$store->getMultiple('meta','key');

sub getMultiple {
my ($self,$type,$key)=@_;

my @rtn;

$key=~s/'/''/g;
my $querystr="SELECT key,value,type,filename,ctime FROM meta left join sources on source_id=sources.id WHERE key='$key' order by ctime desc";
my $query=$self->{'dbh'}->prepare($querystr);
$query->execute;
while(my $data=$query->fetchrow_hashref){
	push @rtn,$data;
}
return @rtn;
}

sub get_tracks_hashref {
my $self=shift;
my $ntrack=0;
my %rtn;

my $query;
do{
	my $querystr="SELECT key,value,type,ctime FROM tracks left join sources on source_id=sources.id where track_index=$ntrack order by ctime desc,key";
	#$self->warn($querystr);
	$query=$self->{'dbh'}->prepare($querystr);
	$query->execute;

	my %record;
	while(defined $query and my $data=$query->fetchrow_hashref){
		$record{$data->{'key'}}=$data->{'value'} if(not defined $record{$data->{'key'}});
	}
#the 'type' key identifies the track - vide, audi etc.	
	if(defined $record{'type'} and $record{'type'} ne ''){
		$rtn{$record{'type'}}=\%record;
	} else {
		$self->warn("get_tracks_hashref - track $ntrack had no type field.") if(scalar @{keys %record}>0 and $record{'type'} ne '');
	}
	++$ntrack;
} while($query->rows>0);

return \%rtn;
}

#this returns all values (metadata and tracks etc.) in a compatible format for running through a template
#you can set 'inhibit_translate' by passing (1) as the first arg.  This prevents us interpreting out
#space or - characters which is necessary if we're specifically referring to keys in a template.
#additionally, you can translate specific keys into arrays by splitting them on a delimiter consisting of any of the following:
# , | / or :
#by passing a REFERENCE to an array which contains the list of keys to split as the second arg - i.e., $store->get_template_data(0,\@key_list);
sub get_template_data {
my $self=shift;
my $inhibit_translate=shift;
my $array_keys=shift;

my %rtn,%temphash;

my $metasection=$self->get_meta_hashref;
my $tracksection=$self->get_tracks_hashref;

foreach(@$array_keys){
    if(defined $metasection->{'meta'}->{$_}){
        my $newkey=$_."_list";
        @{$metasection->{'meta'}->{$newkey}}=split(/[,\|]/,$metasection->{'meta'}->{$_});
    } else {
        print STDERR "Warning - key $_ does not exist so I can't convert it into an array.\n" ;
    }
}

#template toolkit don't like spaces or hyphens.
unless($inhibit_translate){
	foreach(keys %{$metasection->{'meta'}}){
		my $newkey=$_;
		$newkey=~tr/ /_/;
		$newkey=~tr/-/_/;
		print STDERR "DEBUG: got $newkey from $_\n" if($self->{'debug'});
		unless($_ eq $newkey){
			print STDERR "Replacing..." if($self->{'debug'});
			$metasection->{'meta'}->{$newkey}=$metasection->{'meta'}->{$_};
			delete $metasection->{'meta'}->{$_};
		}
	}
}

$rtn{'meta'}=$metasection->{'meta'};
$rtn{'tracks'}=$tracksection;

my $querystr="select key,value,type,ctime from media left join sources on source_id=sources.id order by ctime desc";
my $query=$self->{'dbh'}->prepare($querystr);
$query->execute;

while(my $data=$query->fetchrow_hashref){
	#print Dumper($data);
	$temphash{$data->{'key'}}=$data->{'value'} if(not defined $temphash{$data->{'key'}});
}

$rtn{'movie'}=\%temphash;

#now for 'special exceptions' e.g. filenames etc. that are in the media table
foreach(qw/filename path escaped_path/){
	$rtn{$_}=$temphash{$_};
}

$self->escape_for_xml(\%rtn);
return \%rtn;

}

#Sundry Extra Functions
sub do_escape_for_xml {
	my($val)=@_;

	return $val if(not defined $val);
#	print "Got $val\n";
#NOTE: the first entry here is an extended regex that says, match an & that is NOT followed by between 2 and 4 word characters and a semicolon.
#This should prevent it from double-encoding entites that already exist and hence corrupting the XML.
	$val=~s/&(?!\w{2,4};)/&amp;/g;
	$val=~s/'/&apos;/g;
	$val=~s/"/&quot;/g;
	$val=~s/>/&gt;/g;
	$val=~s/</&lt;/g;
	return $val;
}

sub level_escape_for_xml {
	my($level)=@_;

	foreach(keys %{$level}){
	if(ref($level->{$_}) eq 'HASH'){
		level_escape_for_xml($level->{$_});
	} elsif(ref($level->{$_}) eq 'ARRAY'){
		$_=do_escape_for_xml($_) foreach(@{$level->{$_}});
	} else {
		$level->{$_}=do_escape_for_xml($level->{$_});
	}
	}
}

sub escape_for_xml {
	my($self,$data)=@_;

	level_escape_for_xml $data;
}

sub substitute_string {
my($self,$string)=@_;

my $rtn;
#{media-file} {*-file} {filename} {filepath} {filebase} {fileextn} {year} {month} {day} {hour} {min} {sec} 
#{meta:*} {track:type:*} {media:*} {failed-method} {last-error}	# NOTE - {last-line} is deprecated - if $ENV{'cf_last_error'} is not set then {last-error} is set to $ENV{'cf_last_line'}

my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year+=1900;
$mon+=1;
my @days=qw/Sunday Monday Tuesday Wednesday Thursday Friday Saturday/;
my @months=qw/January February March April May June July August September October November December/;

$mon=sprintf("%02d",$mon);
$mday=sprintf("%02d",$mday);
$hour=sprintf("%02d",$hour);
$min=sprintf("%02d",$min);
$sec=sprintf("%02d",$sec);

$_=$string;
s/{year}/$year/g;
s/{month}/$mon/g;
s/{day}/$mday/g;
s/{hour}/$hour/g;
s/{min}/$min/g;
s/{sec}/$sec/g;
s/{is-dst}/$isdst/g;
s/{weekday}/$days[$wday]/g;
s/{monthword}/$months[$mon-1]/g;

use DateTime;
my $dt;
$dt = DateTime->now;
my $wt;
$wk = $dt->add( days => 7 );
my $nw;
$nw = substr($wk, 0, 10); 
s/{nextweek}/$nw/g;

my $filepath,$filebase,$fileextn;
if($ENV{'cf_media_file'}=~/^(.*)\/([^\/]+)\.([^\/\.]*)$/){
	$filepath=$1;
	$filebase=$2;
	$fileextn=$3;
} elsif($ENV{'cf_media_file'}=~/^(.*)\/([^\/]+)$/){
	$filepath=$1;
	$filebase=$2;
	$fileextn="";
} elsif($ENV{'cf_media_file'}=~/^([^\/]+)\.([^\/\.]*)$/){
	$filepath=$ENV{'PWD'};
	$filebase=$1;
	$fileextn=$2;
}

my $filename="$filebase.$fileextn";

s/{filepath}/$filepath/g;
s/{filebase}/$filebase/g;
s/{fileextn}/$fileextn/g;
s/{filename}/$filename/g;

while(/{([^-}]+)-file}/){
	my $key=$1;
	my $val=$ENV{"cf_$1_file"};
	print STDERR "$key=".$val."\n" if($self->{'debug'});
	if(defined $val){
		s/{$key-file}/$val/g;
	} else {
		s/{$key-file}/[value not present]/g;
		$self->warn("substitute_string - no value present for {$key-file}");
	}
	print STDERR "\ndebug: subsituting {$key-file} got $_\n" if($self->{'debug'});
}

while(/{meta:([^}]+)}/){
	my $key=$1;
	my $val=$self->get('meta',$key,undef);
	#$val=~s:/:\\\\/:g;
	#Support brackets in meta keys.  We need to escape them out for the regex below.
	$key=~s/\(/\\\(/;
	$key=~s/\)/\\\)/;
	if(defined $val){
		s/{meta:$key}/$val/g;
	} else {
		s/{meta:$key}/[value not present]/g;
	}
	print STDERR "\ndebug: subsituting {meta:$key} got $_\n" if($self->{'debug'});
}

while(/{media:([^}]+)}/){
	my $key=$1;
	my $val=$self->get('media',$key,undef);
	#$val=~s:/:\\\\/:g;
	if(defined $val){
		s/{media:$key}/$val/g;
	} else {
		s/{media:$key}/[value not present]/g;
	}
	print STDERR "\ndebug: subsituting {media:$key} got $_\n" if($self->{'debug'});
}

while(/{track:([^:]+):([^}]+)}/){
	my $key=$2;
	my $type=$1;
	my $val=$self->get('track',$type,$key,undef);
	#$val=~s:/:\\\\/:g;
	if(defined $val){
		s/{track:$type:$key}/$val/g;
	} else {
		s/{track:$type:$key}/[value not present]/g;
	}
	print STDERR "\ndebug: subsituting {track:$type:$key} got $_\n" if($self->{'debug'});
}

while(/{config:([^}]+)/){
	my $key=$1;
	my $val=$self->{'defs'}->{$key};
	if(defined $val){
		s/{config:$key}/$val/g;
	} else {
		s/{config:$key}/[value not present]/g;
	}
	print STDERR "\ndebug: subsituting {config:$key} got $_\n" if($self->{'debug'});
}

s/{route-name}/$ENV{'cf_routename'}/;

s/{failed-method}/$ENV{'cf_failed_method'}/;
if($ENV{'cf_last_error'}){
	s/{last-error}/$ENV{'cf_last_error'}/;
} elsif($ENV{'cf_last_line'}) {
	s/{last-error}/$ENV{'cf_last_line'}/;
} else {
	s/{last-error}/[no error set]/;
}

return $_;
}
1;
