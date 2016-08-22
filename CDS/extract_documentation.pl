#!/usr/bin/perl5.16

#This script extracts the in-line documentation from all of the modules under scripts/.
use HTML::Stream;
use Data::Dumper;
use File::Basename;
use File::Temp;
use File::Slurp;

use Date::Format;

my $version='CDS documentation extractor. $Rev: 811 $ $LastChangedDate: 2014-03-22 15:29:08 +0000 (Sat, 22 Mar 2014) $';
#configurable parameters
my $output_path=".";
my $date_format="%A, %o %B %Y";	#see http://search.cpan.org/~gbarr/TimeDate-2.30/lib/Date/Format.pm for reference
my $time_format="%I:%M %p";	#as above
#end configurable parameters

#This stylesheet allows us to use nice and pretty formatting in the output.  This text is inserted
#verbatim into a "style" element in the HTML header.

my $stylesheetcontents='
	h1 { font-family:"DS7 Display Sans Black","Calibri","Verdana","Arial",sans-serif; font-style: bold; font-size:18pt; }
	h2 { font-family:"DS5 Display Sans Semibold","Arial",sans-serif; font-size:14pt; }
	body { font-family:"DS3 Display Sans","Verdana","Arial",sans-serif; font-size:12pt; }
	table { border-color:#000000; }
	td { padding-left: 12px; padding-right:12px; }
	tr.even { background-color:#e5e5e5; };
	tr.odd { background-color:#202020; };
	.footer { font-size: 12pt; }
	.regular { color:#000000; }
	.error	{  color:#F00000; }
	.success	{  color:#00F000; }
	.inprogress	{  color:#8300FF; }
	.undecided  {  color:#0000F0; }
	.literal	{ padding-left:5em; background-color:#CCCCFF; }
';

#simple callback function to prevent HTML::Stream autoescaping the CSS text when we output it
sub no_autoescape {
my $text=shift;

$text;
}

#function to actually extract documentation from a given script
sub extract_documentation {
my ($filename,$output)=@_;

my $fh;
open $fh,"<$filename" or return 0;

$output->A(NAME=>basename($filename))->_A;

$output->H1->t(basename($filename))->_H1;
$output->P;
my $in_args=0;
my $in_literal=0;
my $even=1;

my $first_line;

my %rtn;

while(<$fh>){
	$rtn{'version'}=$_ if(/\$Rev:/);
	next unless(/^#/);	#only interested in comment lines
	next if(/^#!/);		#ignore the execute line
	last if(/^#\s*END DOC/);	#this tells us we're done
	last if(/^#.* MAIN$/i);	#once we get to #START MAIN we know we've read everthing in.
	last if(/^#\s*configurable parameters/i);
	if(/^#LITERAL/){
		$in_literal=1;
		$output->PRE(CLASS=>'literal');
		next;
	}
	if(/^#END LITERAL/){
		$in_literal=0;
		$output->_PRE;
		next;
	}

	if($in_literal){
		s/^#//;
		$output->t($_);
		next;
	}

	if(/^#\s*</ and not $in_args){	#if we see a line starting with # <something then we know that <something> is an argument.
		$in_args=1;
		$output->_P->TABLE(CLASS=>'argument-list');
	}
	#last if($in_args and not /^#\s*</); # if we've been in the args and see something that's not, then they have probably finished.
	chomp;
	if($in_args){
		if($even){
			$output->TR(CLASS=>'even');
			$even=0;
		} else {
			$output->TR(CLASS=>'odd');
			$even=1;
		}
		if(/^#.*(<[^>]+>)\s{0}([^\-]+)[\s\-]*(.*)$/){
			$output->TD->t($1)->_TD->TD->t($2)->_TD->TD->t($3)->_TD;
			$output->TR;
		} elsif(/^#.*(<[^>]+>)[\s\-]*(.*)$/){
			$output->TD->t($1)->_TD->TD->t($2)->_TD;
			$output->_TR;
		} elsif(/^#\s*$/) {
			$in_args=0;
			$output->_TABLE;
			s/^#//;
			$output->P->t($_);
		} else {
			s/^#\s*//;
			if(/^\s*-\s*/){
				s/^\s*-\s*//;
				$output->TD->_TD->TD->_TD->TD->LI->t($_)->_LI->_TD->_TR;
			} else {
				$output->TD->_TD->TD->_TD->TD->t($_)->_TD->_TR;
			}
		}
	} else {
		if(/^#\s*$/){	#if we have a blank comment then create a new paragraph
			$output->_P->P;
		}
		s/^#/ /;
		$rtn{'first_line'}=$_ unless($rtn{'first_line'});
		$output->t($_)->BR;
	}
	#print "$_\n";
}
if($in_literal){
	$output->_PRE;
}

if($in_args){
	$output->_TABLE;
} else {
	$output->_P;
}

return \%rtn;
}

#START MAIN
open $fhout,">:utf8","extracted_documentation_bodytext.html";
my $output=HTML::Stream->new($fhout);

print "$version\n";

#Get a nicely formatted date and time
my @lt=localtime(time);
my $formatted_date=strftime($date_format,@lt);
my $formatted_time=strftime($time_format,@lt);

#$output->BODY
#$output->P(CLASS=>'link')->A(HREF=>'#index')->t('Jump to index')->_A->_P;

my $dirname="scripts";
opendir my($dh),$dirname or die "Unable to open directory ./scripts/\n";
my @contents=readdir $dh;
closedir $dh;

@contents=sort @contents;

my %descriptions;

foreach(@contents){
	next if(/^\./);
	next if(/\.bak$/);
	next if(/\.txt$/);
	next if(/\.xml$/);
	next if(/\.old\.*/);
	next if(/\.edited$/);

	next if(-d "$dirname/$_");
	print "$_\n";
	$output->HR;
	my $scriptname=$_;
	$description{$scriptname}=extract_documentation("$dirname/$_",$output);
	$output->P(CLASS=>'link')->A(HREF=>'#index')->t('Jump to index')->_A->_P;
}

$output->HR;
opendir my($dh),$dirname or die "Unable to open directory ./scripts/\n";
my @contents=sort readdir $dh;
closedir $dh;

close $fhout;

open $fhout,">:utf8","extracted_documentation.html";

$output=HTML::Stream->new($fhout);

$output->HTML
	->HEAD
	->TITLE->t("Auto-extracted CDS module documentation")
	->_TITLE;
#Output the inline stylesheet from above.  We install a custom autoescape handler, that does nothing, in order to pass this text
#through unmolested.  We then re-install the default handler below.
my $default_escape_handler=$output->auto_escape(\&no_autoescape);
$output->STYLE->t($stylesheetcontents)->_STYLE;
$output->_HEAD;

$output->BODY;

$output->auto_escape($default_escape_handler);

$output->P(CLASS=>'descriptor')
	->t("CDS module documentation auto-extracted at $formatted_time on $formatted_date")
	->_P;

#output a table of contents
#$output->UL;
$output->A(NAME=>'index')->_A;
$output->H1->t('Index')->_H1;

$output->TABLE;

#print Dumper(\%description);
#print Dumper(\@contents);

my $even=1;
foreach(@contents){
	next if(/^\./);
	next if(/\.bak$/);
	next if(/\.txt$/);
	next if(/\.old\.*/);
	next if(/\.edited$/);

	next if(-d "$dirname/$_");
	my $outputname=$_;
	$outputname=~s/\.[^\.]+$//;
	
	if($even){
		$output->TR(CLASS=>'even');
		$even=0;
	} else {
		$output->TR(CLASS=>'odd');
		$even=1;
	}

	#$output->LI->A(HREF=>'#'.$_)->t($_)->_A->_LI;
	$output->TD->A(HREF=>'#'.$_)->t($outputname)->_A->_TD;
	$output->TD->t($description{$_}->{'first_line'}."...")->_TD;
	$output->TD->t($description{$_}->{'version'})->_TD;
	$output->_TR;
}
$output->_TABLE;
#$output->_UL;

#the bodytext is preformatted by the previous run, so don't over-write that formatting here
$default_escape_handler=$output->auto_escape(\&no_autoescape);

$output->t(read_file('extracted_documentation_bodytext.html'))->_BODY;

$output->_HTML;

unlink('extracted_documentation_bodytext.html');
	
