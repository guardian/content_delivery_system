package CDS::Cache::Episode;

#This module implements a cache functionality for transcoding.
#It is called Cache::Episode as it is written for the Episode Engine 5 transcoding software

use DBI;
use Digest::MD5;

sub new 
{
my($class,$dbfile)=@_;

my $self;
$self->dmsg("connecting to dbi:SQLite:dbname=$dbfile\n");
$self->{'dbh'}=DBI->connect("dbi:SQLite:dbname=$dbfile","","");

return $self;
}

=head2 lookup_from_cache($filename,[md5=>$md5],[size=>$size],[output=>"/path/to/out"])
This function performs the actual "caching" logic and should be the only one a client app needs to call.
It first checks to see if a record for the given filename exists in the cache db.  If not, it returns -1.
It next checks to see if the record in the db has a matching checksum and filesize.  These are either taken from the arguments provided or are calculated in-process.  If they do not match, any referenced cache file is removed from the disk; the record is removed from the db; and the function returns -2
Finally, if the other tests have passed it checks to see if the referenced file is actually on-disk. If this is the case, it will attempt to create a link to the cached file in this order:
1. hard-link
2. if that fails, try a symlink
3. if that fails, try a copy
If not, it returns -3.  If so, it returns the filepath of the output.  The caller is responsible for the file now. 
=cut
sub lookup_from_cache
