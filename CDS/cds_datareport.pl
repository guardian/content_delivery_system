#!/usr/bin/perl

use DBI;
use File::Basename;

#This program will create an HTML page which is a dump of all the important data in a CDS datastore file.

sub open_output {
my($filename)=@_;

open $output,'>:utf8',$filename or die "Unable to open $filename to write.\n";
return $output;
}

sub print_header {
my($fh,$dbname)=@_;

print $fh "<html><head><title>CDS report for $dbname</title></head>";
print $fh "<body>";
}

sub print_nav {
my($fh)=@_;

print $fh "<p><a href=\"#meta\">Metadata section</a> | <a href=\"#media\">Media section</a> | <a href=\"#tracks\">Tracks section</a></p>\n\n";

}

sub print_footer {
my($fh)=@_;

print $fh "<h2>End of report.</h2>\n</body>";
}

#START MAIN
my $db=$ARGV[0];
if(not -f $db){
	die "Unable to find database file '$db'.\n";
}

my $dbh=DBI->connect("dbi:SQLite:dbname=$db","","");# or die "Unable to open database at '".$ARGV[0]."'\n";

my $outputfilename=basename $db;
$outputfilename=$outputfilename.".html";
my $fh=open_output($outputfilename);

print "Outputting report to $outputfilename...";
print_header($fh,$db);

my $rq=$dbh->prepare("SELECT key,value,type,filename,provider_method,ctime FROM meta left join sources on source_id=sources.id order by ctime desc,meta.id desc,key");
$rq->execute;

print $fh "<a name=\"meta\"/><h1>Metadata section</h1>";
print_nav($fh);
print $fh "<table border=\"1\">";
print $fh "<tr><td>Key</td><td>Value</td><td>Source Filename</td><td>Source creation time</td></tr>";

while(my $data=$rq->fetchrow_hashref){
	my $filename;
	if($data->{'filename'}){
		$filename=$data->{'filename'};
	} else {
		$filename="[".$data->{'provider_method'}."] method";
	}
	print $fh "<tr><td>".$data->{'key'}."</td><td>".$data->{'value'}."</td><td>".$filename."</td><td>".scalar localtime($data->{'ctime'})."</td></tr>";
}

print $fh "</table>\n";

my $rq=$dbh->prepare("SELECT key,value,provider_method,filename,ctime FROM media left join sources on source_id=sources.id order by ctime desc,media.id desc,key");
$rq->execute;

print $fh "<a name=\"media\"/><h1>Media section</h1>\n";
print_nav($fh);
print $fh "<table border=\"1\">";
print $fh "<tr><td>Key</td><td>Value</td><td>Source Filename</td><td>Source creation time</td></tr>";

while(my $data=$rq->fetchrow_hashref){
	my $filename;
	if($data->{'filename'}){
		$filename=$data->{'filename'};
	} else {
		$filename="[".$data->{'provider_method'}."] method";
	}
	print $fh "<tr><td>".$data->{'key'}."</td><td>".$data->{'value'}."</td><td>".$filename."</td><td>".scalar localtime($data->{'ctime'})."</td></tr>";
}

print $fh "</table>";

my $rq=$dbh->prepare("SELECT key,value,track_index,filename,provider_method,ctime FROM tracks left join sources on source_id=sources.id order by track_index asc,ctime desc,key");
$rq->execute;

print $fh "<a name=\"tracks\"><h1>Tracks section</h1>\n";
print_nav($fh);
print $fh "<table border=\"1\">";
print $fh "<tr><td>Track index</td><td>Key</td><td>Value</td><td>Source Filename</td><td>Source creation time</td></tr>";

while(my $data=$rq->fetchrow_hashref){
	my $filename;
	if($data->{'filename'}){
		$filename=$data->{'filename'};
	} else {
		$filename="[".$data->{'provider_method'}."] method";
	}
	print $fh "<tr><td>".$data->{'track_index'}."</td><td>".$data->{'key'}."</td><td>".$data->{'value'}."</td><td>".$filename."</td><td>".scalar localtime($data->{'ctime'})."</td></tr>";
}

print $fh "</table>";
print_footer($fh);
close $fh;
print "done.\n";