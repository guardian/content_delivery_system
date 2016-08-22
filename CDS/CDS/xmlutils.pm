package CDS::xmlutils;

#use Data::Dumper;

require(Exporter);
@ISA = qw(Exporter);
@EXPORT = qw(encode_entities fix_broken_xml_entities);

#NOTE: the first entry here is an extended regex that says, match an & that is NOT followed by between 2 and 4 word characters and a semicolon.
#This should prevent it from double-encoding entites that already exist and hence corrupting the XML.

my @entities_bare=qw/&(?!\w{2,4};) " ' < >/;
my @entities_encoded=qw/&amp; &quot; &apos; &lt; &gt;/;

sub encode_entities {
	my $string=shift;
	
#print "trace: in encode_entities\n";
	for(my $n=0;$n<scalar @entities_bare;++$n){
#		print "encode_entities: searching for ".$entities_bare[$n]." to replace with ".$entities_encoded[$n]."...\n";
	
		if(not $string=~s/$entities_bare[$n]/$entities_encoded[$n]/g){
#			print "encode_entities: WARNING: found no entites for ".$entities_bare[$n].".\n";
		}
	}
	return $string;
}

#This function goes through an XML file (passed in as a string) line by line,
#replacing entities within quoted strings

sub fix_broken_xml_entities {
	my $xml=shift;
	my $out;
	
	my @lines=split(/\n/,$xml);
	
	#print Dumper(\@lines);
	foreach(@lines){
		my $outline=$_;
		#print $_;
		while(/="([^"]+)"/g){
			my $text=$1;
			my $prepend=$`;
			my $append=$';
			
			print "Got text=$text prepend=$prepend append=$append\n";
			$text=~tr/(/\\(/;
			$text=~tr//\\)/;
			if($text=~/[&"'<>]/){
				#print $text;
				my $corrected=encode_entities($1);
				$outline=$prepend.'"'.$corrected.'"'.$append;
				print "$_ -> $outline\n";
			}
		}
		$out=$out.$outline."\n";
	}
	return $out;
}
		
1;













#		my $line=$_;
#		my $n=0;
#		while(/(.)/g){
#			my $in_quotes,$in_point,$out_point;
#			if($1 eq '"' and not $in_quotes){
#				$in_quotes=1;
#				$in_point=$n;
#			} elsif($1 eq '"' and $in_quotes){
#				$out_point=$n;
#				my $temp_string=
#			}
#			
#			++$n;
#		}
