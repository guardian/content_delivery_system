package CDS::octopus_simple;

my $octopusutil="/usr/local/bin/octopusutil";

sub is_working {

return 0 if(not -x $octopusutil);
1;
}

#get_info is like get_header but breaks out the packed fields.
sub get_info {
my($octopus_id)=@_;

my $data=get_header($octopus_id);

my @results=split /#/,$data->{'info4'};
$data->{'restrictions'}=$results[0];
$data->{'explicit'}=$results[2];
$data->{'aspect'}='4x3' if($results[3]==1);
$data->{'aspect'}='16x9' if($results[3]==0);
$data->{'wholly_owned'}=$results[6];

@results=split /#/,$data->{'info5'};
$data->{'fcsid'}=$results[0];
$data->{'r2_still_id'}=$results[1];
$data->{'brightcove_id'}=$results[2];

$data->{'duration'}=$data->{'info6'};
$data->{'source'}=$data->{'info7'};
$data->{'parent_id'}=$data->{'info8'};

return $data;
}

sub get_header {
my($octopus_id)=@_;

my %return;

#octopus id should be a pure number
return undef if(not $octopus_id=~/^\d+$/);

my $result=`$octopusutil GetGenericHeaderByID $octopus_id`;
if($result=~/^ERROR/){
	print STDERR "octopusutil error getting header: $result\n";
	return undef;
}

my @lines=split(/\n/,$result);
foreach(@lines){
	chomp;
	my($key,$val)=split /=/;
	if(defined $return{$key}){
		print STDERR "WARNING: octopus_simple: key collision on $key.  Losing value ".$return{$key}.".\n";
	}
	$return{$key}=$val;
}
return \%return;
}

sub add_brightcove_id {
my($octopus_id,$bcid)=@_;

if(not $octopus_id=~/^\d+$/){
	print STDERR "octopus_simple - ERROR - you need to pass a valid, numeric Octopus ID to add_brightcove_id\n";
	return 0;
}

if(not $bcid=~/^\d+$/){
	print STDERR "octopus_simple - ERROR - you need to pass a valid, numeric Brightcove ID to add_brightcove_id\n";
	return 0;
}

my $result=`$octopusutil AddBrightcoveIdToMovie $octopus_id $bcid`;
chomp $result;
if($result=~/^ERROR/){
	print STDERR "octopus_simple - Octopus said $result\n";
	return 0;
}
return 1;
}

sub add_r2path {
my($octopus_id,$r2id,$r2prodpath,$r2lastop,$r2pagestatus,$r2vidstatus)=@_;

if(not $octopus_id=~/^\d+$/){
	print STDERR "octopus_simple - ERROR - you need to pass a valid, numeric Octopus ID to add_r2path\n";
	return 0;
}

if(not $r2id=~/^\d+$/){
	print STDERR "octopus_simple - ERROR - you need to pass a valid, numeric R2 ID to add_r2path\n";
	return 0;
}

if($r2prodpath=~/[;#]/ or length $r2prodpath<7){	#http:// is 7 chars.
	print STDERR "octopus_simple - ERROR - R2 cms path $r2prodpath does not appear valid\n";
	return 0;
}

if(not $r2lastop=~/^[A-Za-z]+$/){
	print STDERR "octopus_simple - ERROR - R2 last operation $r2lastop does not appear valid\n";
	return 0;
}

if(not $r2pagestatus=~/^[A-Za-z]+$/){
	print STDERR "octopus_simple - ERROR - R2 page status $r2pagestatus does not appear valid\n";
	return 0;
}

if(not $r2vidstatus=~/^[A-Za-z]+$/){
	print STDERR "octopus_simple - ERROR - R2 video status $r2vidstatus does not appear valid\n";
	return 0;
}

my $pathline="$r2id#$r2prodpath#$r2lastop#$r2pagestatus#$r2vidstatus";
print STDERR "octopus_simple - DEBUG - going to run octopusutil AddPathToGeneric $octopus_id $pathline\n";

my $result=`$octopusutil AddPathToGeneric $octopus_id $pathline`;
chomp $result;
if($result=~/^ERROR/){
	print STDERR "-ERROR: Octopus said $result\n";
	return 0;
}
return 1;
}

#this is a more-or-less straight lift from ffxfer
## SAK++
sub create_event
{
	my( $id,$msg,$event,$destination,$debug )=@_;
	if($debug){
		print "\tcreate_event: $octopusutil CreateGenericEvent $id \"N\" $event \"$msg#$destination\"\n";
	}
	my( $result ) = `$octopusutil CreateGenericEvent $id "N" $event "$msg#$destination"`; 
	my $rv=$?>>8;
	print "\tcreate_event: got code $rv and result '$result'\n" if($debug);
	return $rv;
}
## SAK--

1;
