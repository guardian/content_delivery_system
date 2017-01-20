#!/usr/bin/perl

# cds_run subversion revision $Rev: 1411 $ on $LastChangedDate: 2015-11-10 12:33:32 +0000 (Tue, 10 Nov 2015) $
my $version='3.0.0-SVN (revision $Rev: 1411 $)';

$ENV{'PATH'}="/usr/bin:/usr/local/bin:/bin:/usr/local/lib/cds_backend";


require 5.008008;
use strict;
use warnings;


use XML::SAX;
use Getopt::Long;
use File::Path;
use File::Basename;
use File::Spec;
use File::Touch;

# name of SAX parser module
use CDS::Parser::saxRoutes;	
#used to dump out objects, useful for debugging
use Data::Dumper;
use File::Temp qw/ tempfile /;	

use CDS::Datastore::Master;

sub uploaderHelp;
sub executMethod;
sub createTempFile;
sub parseTempFile;
sub deleteTempFile;
sub logOutput;
 
print "\ncds_run version $version\n";

#note that each of these is actually a regex expression, that will be evaluated as (start-of-string)expression(end-of-string).  Hence, .* means 'anything else' and all regex chars are valid.
my @invalidArguments=qw(PATH BASH.* DISPLAY UID EUID COLUMNS HISTCONTROL HISTFILE HISTFILESIZE HISTSIZE HOME HOSTTYPE IFS LANG LINES LOGNAME LS_COLOURS MACHTYPE OLDPWD OSTYPE PATH PIPESTATUS PPID PS.* PWD SHELL SHELLOPTS SHLVL SSH.* TERM UID XAUTHORITY XDG.*);

my $dataStoreLocation="/var/spool/cds_backend";
our $configFileLocation="/etc/cds_backend.conf";

my $routeFileName;

# the next 4 variables are the current file group being processed
my $inputMedia = "";
my $inputMeta = "";
my $inputXML = "";
my $inputInMeta = "";
 
my $runParser = 0;
my @processOutput;
my $routes_data;

my $numberOfInputMethods;
my @inputMethods;

my $numberOfProcessMethods;
my @processMethods;

my $numberOfOutputMethods;
my @outputMethods;

my $numberOfFailMethods;
my @failMethods;

my $numberOfSuccessMethods;
my @successMethods;

my $keepDatastore=0;
our $loggingID;

# location of method scripts

my $methodScriptsFolder = "/usr/local/lib/cds_backend/";
my $routeFilesPath = "/etc/cds_backend/routes";

my $loggingStarted;
my $logFileName;
my $pipeProcessOutput = 1;
#These are used if we're using an external logging module instead of normal logfiles (e.g., to mysql)
our $externalLogger;
my $logDB;
my $dbHost;
my $dbUser;
my $dbPass;
my $dbDriver;

my $runCount = 1;

my $debugLevel = 2;

# there is an issue with not being able to set environment variables in child processes.  The work around is store
# name value pairs in a temporary file

my $tempFileName;

# The script will in running in batch mode if multiple files are downloaded by the "ftp_pull.pl" script.
# The mode gets set by subroutine parseTempFile. 
my $batchRouteMode = 0;

my @filesToProcess;
my $outputString;

my $processReturnCode;

# For debugging purposes; we only want to see the file list dumped once
my $fileListDumped = 0;

my $configData=readConfigFile();

	# if there are no arugments specifed show the help text
	if($#ARGV + 1 == 0)
	{
		uploaderHelp;
		exit 0;
	}
	else 
	{
		# not all the arguments are required according to the documentation(?)
	GetOptions( "input-media=s"  => \$inputMedia,     
	            "input-meta=s"    => \$inputMeta,      
	            "input-inmeta=s"    => \$inputInMeta,      
	            "input-xml=s"    => \$inputXML,             
		    "keep-datastore" => \$keepDatastore,
		    "logging-id=s" => \$loggingID,
		    "logging-db=s" =>\$logDB,
		    "db-host=s" =>\$dbHost,
		    "db-login=s" =>\$dbUser,
		    "db-pass=s" =>\$dbPass,
		    "db-driver=s" =>\$dbDriver,
			"run-count=s" =>\$runCount,
	            "route=s" => \$routeFileName ); 

$dbHost=$configData->{'db-host'} unless($dbHost);
$logDB=$configData->{'logging-db'} unless($logDB);
$dbUser=$configData->{'db-login'} unless($dbUser);
$dbPass=$configData->{'db-pass'} unless($dbPass);
$dbDriver=$configData->{'db-driver'} unless($dbDriver);

# Do we need to use an external logging module?
if($logDB){
	print "Attempting to start up external logger...\n";
	eval {
		use CDS::DBLogger; #we don't USE this above, as it has a dependency on DBI and DBD::MySQL/DBD::Pg/etc. that I don't want to introduce to CDS itself.  This ensures that we only try to read this module if we actually need it.
            	use Data::UUID;
		$externalLogger=CDS::DBLogger->new;
		$externalLogger->connect('driver'=>$dbDriver,
					'database'=>$logDB,
					'host'=>$dbHost,
					'username'=>$dbUser,
					'password'=>$dbPass);
		unless($loggingID){
			my $ug=Data::UUID->new;
			$loggingID=$ug->to_string($ug->create());
			logOutput("WARNING: No logging id specified.  Using auto-generated ID $loggingID.\n",method=>'CDS');
		}
		my @tempFileList;
		push @tempFileList,$inputMedia if($inputMedia);
		push @tempFileList,$inputMeta if($inputMeta);
		push @tempFileList,$inputInMeta if($inputInMeta);
		push @tempFileList,$inputXML if($inputXML);
                push @tempFileList,basename($routeFileName);

		$externalLogger->newjob('id'=>$loggingID,'routename'=>$routeFileName,'files'=>\@tempFileList);
		$externalLogger->touchTimestamp('job_id'=>$loggingID);

		$externalLogger->make_status('id'=>$loggingID);
	};
	if($@){
		openLogfile() unless $loggingStarted;
        print "WARNING - Unable to initialise requested external logger.  Error was $@\n";
		print LOG "WARNING - Unable to initialise requested external logger.  Error was $@\n";
		$externalLogger=undef;
	}
}

if($externalLogger){
	$externalLogger->update_status('id'=>$loggingID,'status'=>'parsing');
}

#OK, now that's out of the way, do we have a route file?
if($routeFileName)
{
	$runParser = 1;
	print "MESSAGE: Use route file $routeFileName\n";
}
else
{
	print STDERR "ERROR: cds_run no route file was specifed\n";
	uploaderHelp;
	exit 1;		
}	
}

	# parse the routes file
	
	if( $runParser == 1 )
	{
		my $routes_parser = XML::SAX::ParserFactory->parser(Handler =>CDS::Parser::saxRoutes->new);
		print "DEBUG: pass URI to parser\n" if $debugLevel > 0;
		$routeFileName=$routeFilesPath . '/' . $routeFileName if(not $routeFileName=~/^\//);
		eval {
			$routes_parser->parse_uri($routeFileName);
		};
		if($@){
			openLogfile() unless($loggingStarted);
			my $error=$@;
			chomp $error;
			logOutput("-ERROR: CDS CORE: PARSING $routeFileName.\nError was: '$error'.\n",method=>'CDS');
			print STDERR "CDS ERROR PARSING $routeFileName.\nError was: '$error'.\n";
			exit 3;
		}
		print "DBEUG: get data from parser\n" if $debugLevel > 0;	
		
		if($debugLevel > 0)
		{
			print Dumper($routes_parser->{'Handler'});
		}
		
		# TO DO: there should be some validation done on the parser contents.
	
		@inputMethods = @{$routes_parser->{'Handler'}->{'methods'}->{'input'}} if(defined $routes_parser->{'Handler'}->{'methods'}->{'input'});	
		$numberOfInputMethods = @inputMethods;
		
		@processMethods =  @{$routes_parser->{'Handler'}->{'methods'}->{'process'}} if(defined $routes_parser->{'Handler'}->{'methods'}->{'process'});
		$numberOfProcessMethods = @processMethods;	
		
		@outputMethods = @{$routes_parser->{'Handler'}->{'methods'}->{'output'}} if(defined $routes_parser->{'Handler'}->{'methods'}->{'output'});	
		$numberOfOutputMethods = @outputMethods;
		
		@failMethods=@{$routes_parser->{'Handler'}->{'methods'}->{'fail'}} if(defined $routes_parser->{'Handler'}->{'methods'}->{'fail'});
		$_->{'nonfatal'}=1 foreach(@failMethods); #don't bomb if a fail method fails
		$numberOfFailMethods=@failMethods;
		
		@successMethods=@{$routes_parser->{'Handler'}->{'methods'}->{'success'}} if(defined $routes_parser->{'Handler'}->{'methods'}->{'success'});
		$_->{'nonfatal'}=1 foreach(@successMethods);	#don't bomb if a success method fails
		$numberOfSuccessMethods=@successMethods;
		
	}
	
	if($numberOfInputMethods == 0 && $numberOfProcessMethods == 0 && $numberOfOutputMethods == 0)
	{
		$outputString = "-ERROR: There are no methods to process.\ncds_run will now exit.\n"; 
		print STDERR $outputString;
		logOutput($outputString,method=>'CDS');
		exit 1;
	}

	# now the fun begins, based on the data defined in the routes do some processing and make calls to other modules & scripts
	if($externalLogger){
		$externalLogger->update_status('id'=>$loggingID,'status'=>'setup_datastore');
	}

	#initialise the data store, as per the master directory specified above.
	my $store=setupDataStore();

	if(not defined $store){
		logOutput("ERROR: Unable to initialise a datastore in $dataStoreLocation\n",method=>'Datastore');
		die "ERROR: Unable to initialise a datastore in $dataStoreLocation\n";
	}

	$store->set('meta','loggingid',$loggingID);
	my $method;
	my $i;
	
	createTempFile();


	print "-----------------------------------------------------------\n";
	print "MESSAGE: number of input methods $numberOfInputMethods\n";
	logOutput("MESSAGE: number of input methods $numberOfInputMethods\n",method=>'CDS');
	if($externalLogger){
		$externalLogger->update_status('id'=>$loggingID,'status'=>'input');
	}

    for ($i = 0; $i < $numberOfInputMethods; $i++) 
    {
    	$method = $inputMethods[$i];
		$processReturnCode = executeMethod($method);	
		
	    if($processReturnCode == 1)
	    {
	    	   if(defined $method->{'nonfatal'}){
	    			logOutput("MESSAGE: 'nonfatal' option set, so continuing on route.\n",method=>'CDS');
	    		} else {
	   				runFailMethods(\@failMethods,$method);
					deleteTempFile();	
					goto exitScript; # HACK to short ciruit and jump out of the loop
				}
	    }						
    }    
    
	# Now for some fun, is ths script running in batch mode?
	
	# Batch mode is set after doing a ftp-pull and multiple file groups have been downloaded.
	
	if( $batchRouteMode == 1)
	{
		print "MESSAGE: cds_run is running in batch mode\n";
		logOutput("MESSAGE: cds_run is running in batch mode\n",method=>'CDS');
		
		my $numberOfFileGroups = @filesToProcess;
		my $index;
		
		for ($index = 0; $index < $numberOfFileGroups; $index++)
		{
			print "MESSAGE: batch processing at index $index\n";
			logOutput("MESSAGE: batch processing at index $index\n",method=>'CDS');	
			
			
			my $record = $filesToProcess[$index];

			if($debugLevel > 0)
			{
				print STDOUT "DEBUG: current file group\n";
				logOutput("DEBUG: current file group\n",method=>'CDS');
				print Dumper(\$record);
				logOutput (Dumper(\$record),method=>'CDS');				
			}		
			
			# Not all the files may be in use at any given time.
			$inputMedia = $record->{'cf_media_file'};
			$inputInMeta = $record->{'cf_inmeta_file'};
			$inputXML = $record->{'cf_xml_file'};
			$inputMeta = $record->{'cf_meta_file'};	
		
			print "-----------------------------------------------------------\n";
			print "MESSAGE: number of process methods $numberOfProcessMethods\n";
			logOutput("MESSAGE: number of process methods $numberOfProcessMethods\n",method=>'CDS');
if($externalLogger){
	$externalLogger->update_status('id'=>$loggingID,'status'=>'process');
}

		    for($i = 0; $i < $numberOfProcessMethods; $i++)
		    {
		    	$method = $processMethods[$i];
		    	$processReturnCode = executeMethod($method);
		    	
	    		if($processReturnCode == 1)
	    		{
	    			if(defined $method->{'nonfatal'}){
	    				logOutput("MESSAGE: 'nonfatal' option set, so continuing on route.\n",method=>'CDS');
	    			} else {
	    				runFailMethods(\@failMethods,$method);
	    				goto nextInBatch;
	    			}
	    		}		    	
		    }
			
			print "-----------------------------------------------------------\n";
			if($externalLogger){
				$externalLogger->update_status('id'=>$loggingID,'status'=>'output');
			}

			$numberOfOutputMethods = @outputMethods;
			print "MESSAGE: number of output methods $numberOfOutputMethods\n";	
			logOutput("MESSAGE: number of output methods $numberOfOutputMethods\n",method=>'CDS');
		    for ($i = 0; $i < $numberOfOutputMethods; $i++) 
		    {
		    	$method = $outputMethods[$i];
		    	$processReturnCode = executeMethod($method);	
		    	
	    		if($processReturnCode == 1)
	    		{
	    			if(defined $method->{'nonfatal'}){
	    				logOutput("MESSAGE: 'nonfatal' option set, so continuing on route.\n",method=>'CDS');
	    			} else {
						runFailMethods(\@failMethods,$method);
	    				goto nextInBatch;
	    			}
	    		}				
		    }
		   	nextInBatch:
		}
		
	
	}	#batchmode==1
	else
	{
		print "-----------------------------------------------------------\n";
		print "MESSAGE number of process methods $numberOfProcessMethods\n";
		logOutput("MESSAGE number of process methods $numberOfProcessMethods\n",method=>'CDS');
		if($externalLogger){
			$externalLogger->update_status('id'=>$loggingID,'status'=>'process');
		}

	    for($i = 0; $i < $numberOfProcessMethods; $i++)
	    {
	    	$method = $processMethods[$i];
	    	$processReturnCode = executeMethod($method);
	    	
	    	if($processReturnCode != 0)
	    	{
	    		if(defined $method->{'nonfatal'}){
	    			logOutput("MESSAGE: 'nonfatal' option set, so continuing on route.\n",method=>'CDS');
	    		} else {
	    			runFailMethods(\@failMethods,$method);
	  	    		close LOG;
					deleteTempFile();	  		
	    			goto exitScript;
	    		}
	    	}
	    }
		
		print "-----------------------------------------------------------\n";
		print "MESSAGE number of output methods $numberOfOutputMethods\n";	
		logOutput("MESSAGE number of output methods $numberOfOutputMethods\n");

if($externalLogger){
	$externalLogger->update_status('id'=>$loggingID,'status'=>'output');
}

	    for ($i = 0; $i < $numberOfOutputMethods; $i++) 
	    {
	    	$method = $outputMethods[$i];
	    	$processReturnCode = executeMethod($method);	
	    	
	    	if($processReturnCode != 0)
	    	{
	    		if(defined $method->{'nonfatal'}){
	    			logOutput("MESSAGE: 'nonfatal' option set, so continuing on route.\n",method=>'CDS');
	    		} else {
	    			runFailMethods(\@failMethods,$method);
	   	    		close LOG;
					deleteTempFile();	 		
	    			goto exitScript;
			}
	    	}	    	
	    					
	    }		
	}
	
	logOutput("\n\n-----------------------------------------\nEnd of route.\n-----------------------------------------\n",method=>'CDS');
	
	runSuccessMethods(\@successMethods);
	
	exitScript:

	#should output our metadata here
	if($externalLogger){
		my $metadata=$store->get_meta_hashref;
		$externalLogger->setMeta(id=>$loggingID,metadata=>$metadata->{'meta'});
	}
	# Clean up
	deleteTempFile();
	unlink(untaint($ENV{'cf_datastore_location'})) unless($keepDatastore);
	
	print STDOUT "MESSAGE:cds_run.pl has exited.\n";
	logOutput("MESSAGE:cds_run.pl has exited.\n",method=>'CDS');
	close LOG;		
	
#------------------------------------------------------------------------------
# sub routines

sub uploaderHelp {
	print STDERR "\n";
	print STDERR "--route filename (required)\n";			
	print STDERR "--input-media filename (optional)\n";
	print STDERR "--input-meta filename (optional)\n";
	print STDERR "--input-inmeta filename (optional)\n";
	print STDERR "--input-xml filename (optional)\n";
	print STDERR "--keep-datastore (-k) (optional) - do not delete the datastore file when processing is completed.  Only useful for debugging.\n";
	print STDERR "--logging-id {uuid} (optional) - use this filename (under the usual /var/log tree) for logging\n";
	#print STDERR "--config (optional)\n";
}



sub commandLineInput {
	
	my $mediaType;
	
	if (defined($ENV{'media-filetype'}))
	{
		$mediaType = untaint($ENV{'media-filetype'});
		unless (  $mediaType =~ m/^\./ ) 
		{
			$mediaType = "." .  untaint($ENV{'media-filetype'});
		}
	}
	else
	{
		$mediaType = ".mov";	
	}	
		
	unless ($inputMedia || $inputMeta || $inputXML || $inputInMeta)
	{
		print STDERR "ERROR: command line input : required argument missing\nat least one of  \"input-media\",\"input-meta\",\"input-inmeta\" or \"input-xml\" needs to be specified\n";
		print "exiting script\n";
		deleteTempFile();
		exit 1;
	}	
	elsif ($inputMedia && $inputMeta)
	{
		#check if arguments needs expanding to full paths
	}
	elsif ($inputMedia)
	{ 	# swap the file exstension with ".meta"
		$inputMeta = $inputMedia;
		$inputMeta =~ s/\.[^.]*$/.meta/; # replace file exstension using an anchor
	}
	elsif ($inputMeta) 
	{ 	# this is prolematic, how do you know what the media extension is?
		# assume ".mov"
		#$inputMedia = $inputMeta;
		#$inputMedia =~ s/.meta/$mediaType/;
	}
	elsif ($inputXML) 
	{ 	# this is prolematic, how do you know what the media extension is?
		# assume ".mov"
		#$inputMedia = $inputXML;
		#$inputMedia =~ s/.xml/$mediaType/;
	}
	elsif ($inputInMeta) 
	{ 	# this is prolematic, how do you know what the media extension is?
		# assume ".mov"
		#$inputMedia = $inputInMeta;
		#$inputMedia =~ s/.inmeta/$mediaType/;
	}	
		
	# check if the path is relative and if so expand it to a fully qualified path
	if($inputMeta =~ /~/ )
	{
		my @list = glob($inputMeta);
		if(@list)
		{
			$inputMeta = $list[0];
		}
	}

	if($inputMedia =~ /~/ )
	{
		my @list = glob($inputMedia);
		if(@list)
		{
			$inputMedia = $list[0];
		}
	}

	if($inputXML =~ /~/ )
	{
		my @list = glob($inputXML);
		if(@list)
		{
			$inputXML = $list[0];
		}
	}

	if($inputInMeta =~ /~/ )
	{
		my @list = glob($inputInMeta);
		if(@list)
		{
			$inputInMeta = $list[0];
		}
	}
	
	print STDOUT "MESSAGE: cds_run argument meta $inputMeta\n";
	print STDOUT "MESSAGE: cds_run argument media $inputMedia\n";
	print STDOUT "MESSAGE: cds_run argument XML $inputXML\n";
	print STDOUT "MESSAGE: cds_run argument inmeta $inputInMeta\n";
}

sub runFailMethods {
my ($methodList,$failedMethod)=@_;

return if(not defined $methodList);

if($externalLogger){
	$externalLogger->update_status('id'=>$loggingID,'status'=>'error');
}

logOutput("\n\n------------------------------------------\nRoute failed.  Executing failure methods",method=>'CDS') if(scalar @$methodList>0);
$ENV{'cf_failed_method'}=$failedMethod->{'name'};
$ENV{'cf_last_error'}=$failedMethod->{'lastError'};
$ENV{'cf_last_line'}=$failedMethod->{'lastLine'};
	 
foreach(@$methodList){
	$method = $_;
	$processReturnCode = executeMethod($method,update_status=>0);
	   
#	print Dumper($failedMethod);
	if($processReturnCode != 0)
	 {
	 logOutput("WARNING: ".$method->{'name'}." failed.  Continuing.\n",method=>'CDS');
	 }
}

$ENV{'cf_failed_method'}=undef;
$ENV{'cf_last_error'}=undef;
$ENV{'cf_last_line'}=undef;
}

sub runSuccessMethods {
my($methodList)=@_;

return if(not defined $methodList);
if($externalLogger){
	$externalLogger->update_status('id'=>$loggingID,'status'=>'success');
}

logOutput("Route succeeded.  Executing success methods.\n",method=>'CDS');

foreach(@$methodList){
	$method = $_;
	$processReturnCode = executeMethod($method,update_status=>0);

	if($processReturnCode != 0)
	 {
	 logOutput("WARNING: ".$method->{'name'}." failed.  Continuing.\n",method=>'CDS');
	 }
}
}

sub find_filename {
	my $filename=shift(@_);

	foreach(("",".pl",".sh",".php",".rb")){
		return $filename.$_ if( -x $filename.$_ );
	}
	return undef;
}

#executeMethod returns:
# 0=>run successful
# 1=>run failed for some reason (script flagged an error or did not exist - logged)
# 2=>one of the file arguments requested in take-files did not exist, so the script didn't run.
# 3=>rerun the route.
sub executeMethod{
	my ($methodData,%args) = @_;
	my $systemArguments;
	my $methodName = $methodData->{'name'};
	
	my $returnCode = 0;

	my $update_status=1;
	$update_status=$args{'update_status'} if(defined $args{'update_status'});

	if($externalLogger and $update_status){
		$externalLogger->update_status(id=>$loggingID,'current_operation'=>$methodName);
	}
	if( $methodName eq "commandline")
	{	
		# get any specified arguments for the process method and set environment varaibles accordingly
		setUpProcessArguments($methodData);	
		commandLineInput();
	}
	else
	{
		my $filename = find_filename($methodScriptsFolder . $methodName);
		
		# get any specified arguments for the process method and set environment varaibles accordingly
		if(not setUpProcessArguments($methodData)){
			logOutput("-ERROR: Arguments to method not properly defined.  Not running method $methodName.\n",method=>$methodName);
			$returnCode = 2;
		}

		if($returnCode<1){
			if( -x $filename or -x $filename.".pl" or -x $filename.".sh" or -x $filename.".py" or -x $filename.".rb"){
				my $lastLine;
				my $lastError;
				$systemArguments=untaint($filename). " 2>&1";

				#we use this syntax, in order to dump lines to the logfile as they happen.
				$|=1;
				#$/="\r\n";
				open PIPE,"$systemArguments |" or die "Could not run command $systemArguments";

				unless($loggingStarted)
				{
					openLogfile();
				}	

				logOutput("\n------------------------------------------\n",'method'=>'CDS');
				logOutput("\nExecuting method $methodName\n",'method'=>'CDS');
				while(<PIPE>){
					$lastLine=$_;
					$lastError=$_ if(/^-/ or /^ERROR/);
					logOutput("$_",'method'=>$methodName);
					flush LOG;
				}
				$methodData->{'lastError'}=$lastError;
				$methodData->{'lastLine'}=$lastLine;
				close PIPE;
	
				logOutput("------------------------------------------\n\n",'method'=>'CDS');
				my $ret = $?;
				my $exitCode = ($ret >> 8);
				print "back quotes returned " . ($ret)        . "\n";
				print "child died on signal " . ($ret & 0xff) . "\n";
				print "child exit code was "  . $exitCode   . "\n";
				
				if($exitCode == 3)
				{
					print STDOUT "-ERROR: an error occurred with '$methodName' script.\n";
					logOutput("-ERROR: an error occurred with '$methodName' script.\n",'method'=>'CDS');	
					$returnCode = 3;
					my $reruncommand;
					$reruncommand = "cds_run.pl";
					$reruncommand = $reruncommand . " --route " . $routeFileName;
					if ($inputMedia ne "")
					{
						$reruncommand = $reruncommand . " --input-media " . $inputMedia;
					}
					if ($inputMeta ne "")
					{
						$reruncommand = $reruncommand . " --input-meta " . $inputMeta;
					}
					if ($inputInMeta ne "")
					{
						$reruncommand = $reruncommand . " --input-inmeta " . $inputInMeta;
					}
					if ($inputXML ne "")
					{
						$reruncommand = $reruncommand . " --input-xml " . $inputXML;
					}
					if ($keepDatastore ne "")
					{
						$reruncommand = $reruncommand . " --keep-datastore " . $keepDatastore;
					}
					if (defined $loggingID)
					{
						if ($loggingID ne "")
						{
							$reruncommand = $reruncommand . " --logging-id " . $loggingID;
						}
					}
					if ($logDB ne "")
					{
						$reruncommand = $reruncommand . " --logging-db " . $logDB;
					}
					if ($dbHost ne "")
					{
						$reruncommand = $reruncommand . " --db-host " . $dbHost;
					}
					if ($dbUser ne "")
					{
						$reruncommand = $reruncommand . " --db-login " . $dbUser;
					}
					if ($dbPass ne "")
					{
						$reruncommand = $reruncommand . " --db-pass " . $dbPass;
					}
					if ($dbDriver ne "")
					{
						$reruncommand = $reruncommand . " --db-driver " . $dbDriver;
					}
					$runCount = $runCount + 1;
					$reruncommand = $reruncommand . " --run-count " . $runCount;
					if ($runCount < 65)
					{
						my $pid;
						$pid = fork();
						if( $pid == 0 ){
							sleep(8);
							exec($reruncommand);
							exit 0;
						}
					}
					else
					{
						$returnCode = 1;
					}
				}
				elsif($exitCode > 0)
				{
					print STDOUT "-ERROR: an error occurred with '$methodName' script.\n";
					logOutput("-ERROR: an error occurred with '$methodName' script.\n",'method'=>'CDS');	
					$returnCode = 1;
				}
				else
				{
					parseTempFile();
				}
				chomp $methodData->{'lastError'};
				chomp $methodData->{'lastLine'};
			}
			else
			{
				print STDERR "-ERROR: script for method $methodName does not exist, or is not executable. ($filename)\n\n";
				logOutput("-ERROR: script for method $methodName does not exist, or is not executable. ($filename)\n\n",'method'=>'CDS');
				$returnCode = 1;
			}
		}
	}	#if methodname=='commandline'
	if($externalLogger and $update_status){
		my $status;
		if($returnCode==0){
			$status="success";
		} elsif($returnCode==1){
			$status="error";
		} elsif($returnCode==2){
			$status="nonfatal";
		} elsif($returnCode==3){
			$status="reruning";
		}
		$externalLogger->update_status(id=>$loggingID,current_operation=>'',last_operation=>$methodName,last_error=>$methodData->{'lastError'},last_operation_status=>$status);
	}
	#EXPERIMENTAL. See if this works to get better knowledge in the dashboard, without hurting performance too much

        if($externalLogger){
                my $metadata=$store->get_meta_hashref;
                $externalLogger->setMeta(id=>$loggingID,metadata=>$metadata->{'meta'});
        }
	#flush out the old arguments from the environment space
	purgeProcessArguments($methodData);
	return $returnCode;
}
	
		
	sub clearScriptArugments{
		$ENV{"cf_media_file"} = "";
		$ENV{"cf_meta_file"} = "";
		$ENV{"cf_inmeta_file"} = "";
		$ENV{"cf_xml_file"} = "";						
	}
	
sub purgeProcessArguments{
	my $processAttributesRef = shift @_;
	
	while ( my ($key,$value) = each(%$processAttributesRef) ) { 
		if($key ne "take-files"){
			delete $ENV{$key};
		}
	}
}

sub is_argument_valid {
	my $argument=shift(@_);

	foreach(@invalidArguments){
		if($argument=~/^$_$/i){
			logOutput("-WARNING: An invalid argument '$argument' was specified and will not be passed to the method.  This is probably because it is a system environment variable.\n");
			return 0;
		}
	}
	return 1;
}

# take the name value pairs in the construct and create environment variables
# this routine may need to be re-worked to be more data driven later
# MSB, May 2009
sub setUpProcessArguments{
	my $processAttributesRef = shift(@_);
		
	my $value;
	my $name;
	my $key;
	
	clearScriptArugments();	

	if($debugLevel > 0)
	{
		print "DEBUG: dump of process attributes to be passed via environment variables on next line\n:";
  		print Dumper(\%$processAttributesRef);
	}
  		

    #first, set vars for the relevant files.
    $value=$processAttributesRef->{'take-files'};
        
        
    #set the route name
	#this regex matches: forward-slash, anything except forward slash (extracting this as $1), dot, anything except dot, end-of-string.
 	#i.e., it extracts the name of the file from the sequence path-name-extension.
 	if($routeFileName=~/\/([^\/]*)\.[^\.]*$/){
		$ENV{'cf_routename'}=$1;
	} else {
		$routeFileName=~/\/([^\/]*)$/;
		$ENV{'cf_routename'}=$1;
	}
	
    my $i; my $size; my $contentType;
	#Note: the character is escaped using a backslash otherwise, it is handled as an operator!
	my @array = split( /\|/, $value);
	
	$size = @array;
	for ( $i = 0; $i < $size; $i++)
	{
		$contentType = $array[$i];
		
		if ($contentType eq "media")
		{
		if(defined($inputMedia))
			{	
				$ENV{"cf_media_file"} = $inputMedia;
			}
			else
			{
				$ENV{"cf_media_file"} = "";
				print STDERR "WARNING: a required value is undefined 'cf_media_file'\n";
				#return 0;
			}		
		}
		elsif ($contentType eq "meta")
		{
			if(defined($inputMeta))
			{	
				$ENV{"cf_meta_file"} = $inputMeta;				
			}
			else
			{
				$ENV{"cf_meta_file"} = "";
				print STDERR "WARNING: a required value is undefined 'cf_meta_file'\n";
				#return 0;
			}		
			
		}
		elsif ($contentType eq "inmeta")
		{
			if(defined($inputInMeta))
			{	
				$ENV{"cf_inmeta_file"} = $inputInMeta;		
			}
			else
			{
				$ENV{"cf_inmeta_file"} = "";
				print STDERR "WARNING: a required value is undefined 'cf_inmeta_file'\n";
				#return 0;
			}						
		}
		elsif ($contentType eq "xml")
		{
			if(defined($inputXML))
			{	
				$ENV{"cf_xml_file"} = $inputXML;
			}
			else
			{
				$ENV{"cf_xml_file"} = "";
				print STDERR "WARNING: a required value is undefined 'cf_xml_file'\n";
				#return 0;
			}		
		}  	
    }
    while ( my ($key, $value) = each(%$processAttributesRef) ) {
       	print "$key => $value\n";
       	$ENV{$key} = $value if(is_argument_valid($key) and $key ne "take-files");
   	} 		
return 1;
}

sub getSafeFilename
{
my $currentTime = `date "+%Y-%m-%d_%H_%M_%S"`;
chomp $currentTime;
my $safeRouteFileName=basename($routeFileName);
chomp $safeRouteFileName;
$safeRouteFileName=~s/\.[^\.]$//;
$safeRouteFileName=~s/[^\w\d]/_/g;
	
my $outputfilename="cds_". $safeRouteFileName .'_' . $currentTime;
return ($safeRouteFileName,$outputfilename);
}

sub openLogfile()
{
	# call process to get current date & time
	my $currentTime = `date "+%Y-%m-%d_%H_%M_%S"`;
	chomp($currentTime);
	$currentTime =~ s/ |://g;
	
	$loggingStarted = 1;
	
	# Does the log file directory exist?
	# NOTE: this script needs to be run with super user rights to write to the directory.
	unless ( -d "/var/log/cds_backend/")
	{
		print "MESSAGE: created log file directory at '/var/log/cds_backend'\n";
		mkdir "/var/log/cds_backend/", 0755;
	}
	
	my $safeRouteFileName;

	if($loggingID){
		$safeRouteFileName=$loggingID;
	} else {
		$safeRouteFileName=basename($routeFileName);
	}
	chomp $safeRouteFileName;
	$safeRouteFileName=~s/\.[^\.]$//;
	$safeRouteFileName=~s/[^\w\d\-]/_/g;

	unless ( -d "/var/log/cds_backend/$safeRouteFileName"){
		print "MESSAGE: created log file directory at '/var/log/cds_backend/$safeRouteFileName'\n";
		mkdir "/var/log/cds_backend/$safeRouteFileName", 0755;
	}
	
	my $fileName = "/var/log/cds_backend/$safeRouteFileName/cds_". $safeRouteFileName  . $currentTime . ".log";
	while(-f $fileName) {
		sleep 1;
		$currentTime = `date "+%Y-%m-%d_%H_%M_%S"`;
		chomp($currentTime);
		$fileName = "/var/log/cds_backend/$safeRouteFileName/cds_". $safeRouteFileName  . $currentTime . ".log";
	}
	
	my $fileOpenStatus = open LOG, ">", untaint($fileName);
	
	unless ($fileOpenStatus)
	{
		print STDERR "-WARNING: File open failed for log file $fileName\n";
	}
}	
	
sub logOutput
{
	my ($processOutput,%args) = @_;
	
	unless($loggingStarted)
	{
		openLogfile();
	}		
	
	if($args{'method'}){
		print LOG "\t".$args{'method'}.": $processOutput\n";
	} else {
		print LOG $processOutput;
	}
	
	if($externalLogger){
		if($processOutput=~/^-ERROR/){
			$externalLogger->logerror(id=>$loggingID,message=>$processOutput,%args);
		} elsif($processOutput=~/^.{0-1}WARNING/){
			$externalLogger->logwarning(id=>$loggingID,message=>$processOutput,%args);
		} elsif($processOutput=~/^\+SUCCESS/){
			$externalLogger->logsuccess(id=>$loggingID,message=>$processOutput,%args);
		} elsif($processOutput=~/^.{0-20}DEBUG/i){
			$externalLogger->logdebug(id=>$loggingID,message=>$processOutput,%args);
		} else {
			$externalLogger->logmsg(id=>$loggingID,message=>$processOutput,%args);
		}
	}
}	

#
# A need arose to use temporary files in the CDS system.  Process scripts that called by cds_run will
# sometimes need to pass back information.  The process scripts cannot pass back data via environment variables.
#
# The work around is to use a temporary file.  A temporary file name is created once per session.
#
#
sub createTempFile()
{
	my $fh;
	my $suffix = ".txt";
	my $template = "cds_XXXXXXXXXX";
	my $dir = "/var/tmp/";
	
	# NOTE: the file handle is not actually is being used.
	($fh, $tempFileName) = tempfile($template, SUFFIX => $suffix, DIR => $dir);
	
	print "MESSAGE: temporary file created with name '$tempFileName'\n";
	$ENV{'cf_temp_file'} = $tempFileName;
}


sub chain_route
{
    my @params=@_;
    
    my $cds_exec=File::Spec->rel2abs( __FILE__ );
    my $routeName=$params[0];
    my $cmdline="$cds_exec --route $routeName";
    
    my $n=1;
    foreach(qw/media inmeta meta xml/){
        if($params[$n] and length $params[$n]>0){
            $cmdline=$cmdline . " --input-$_ '".$params[$n]."'";
        }
        ++$n;
    }
    #$cmdline = untaint($cmdline);
    print "DEBUG: Commandline to run for chain: $cmdline\n" if $debugLevel>1;
    #fire n forget. this is ugly, but won't get run often.
    sleep(1);	#ensure that we don't get name clashes on logs or datastore repos
    system("$cmdline </dev/null >/dev/null 2>&1 &");
    
}

sub parseTempFile()
{
	my $batchMode = 0;
	my $fileOpenStatus = open CDS_TMP, "<", $tempFileName;
	
	my @records = <CDS_TMP>;

	foreach(@records){
		chomp;
		print "temp file contents: record: '$_'\n" if $debugLevel > 0;

		if($batchMode == 0)
		{	
			my $name;
			my $value;
			($name, $value) = split /=/;	
			if($name eq "batch" )
			{
				$batchMode = 1;
			}
			if ($name eq "cf_media_file")
			{
				$inputMedia = $value;
				print "DEBUG: \$inputMedia set to '$value'\n" if $debugLevel > 0;
			}
			if ($name eq "cf_meta_file")
			{
				$inputMeta = $value;
				print "DEBUG: \$inputMeta set to '$value'\n" if $debugLevel > 0;
			}
			if ($name eq "cf_xml_file")
			{
				$inputXML = $value;
				print "DEBUG: \$inputXML set to '$value'\n"  if $debugLevel > 0;
			}
			if ($name eq "cf_inmeta_file")
			{
				$inputInMeta = $value;
				print "DEBUG: \$inputInMeta set to '$value'\n" if $debugLevel > 0;
			}
            if ($name eq "chain")
            {
                my @params = split /,/,$value;
                print "DEBUG: chain route requested: @params\n" if $debugLevel >0;
                chain_route(@params); 
            }
		}
		else
		{ # the record contains comma seperated data
					
			my $currentFileName;
			my $keyName;
			my $arraySize;
			my $rec;
		 	 # get the file names 
		  	my @fileNames = split /,/;
		  
		 	foreach(@fileNames){
		 		/\.([^\.]*)$/;
		 		my $fileNameExtension = $1;
		 		
				if(lc $fileNameExtension eq "meta")
				{
					$keyName = "cf_meta_file";
				}
				elsif(lc $fileNameExtension eq "inmeta")
				{
					$keyName = "cf_inmeta_file";
				}
				elsif(lc $fileNameExtension eq "xml" or lc $fileNameExtension eq "txt")
				{
					$keyName = "cf_xml_file";
				}
				else
				{
					$keyName = "cf_media_file";
				}

				$rec->{$keyName} = $_;
			}
			push @filesToProcess, $rec;
			$batchRouteMode = 1;
		}
	}
	
	if ($batchRouteMode == 1  && $debugLevel > 0 && $fileListDumped == 0)
	{
		$fileListDumped = 1;
		#print Dumper(\@filesToProcess);
	}
	
	close CDS_TMP;
	
	#truncate file by opening to write then closing again.
	open CDS_TMP,">", $tempFileName;
	close CDS_TMP;
}

sub deleteTempFile()
{
	unlink $tempFileName;
}

#new functionality for v2.0.
sub setupDataStore
{
my $dataStoreFilename;
my $safeRouteFilename;
my $dsLocation;

openLogfile() unless($loggingStarted);

do {
	($safeRouteFilename,$dataStoreFilename)=getSafeFilename;

	$dsLocation=untaint("$dataStoreLocation/$safeRouteFilename/$dataStoreFilename");
	$ENV{'cf_datastore_location'}=$dsLocation;
	sleep 1 if(-f $dsLocation);
} while(-f $dsLocation);
mkpath dirname($dsLocation) if(not -d dirname($ENV{'cf_datastore_location'}));
touch($dsLocation); #ensure that the file exists so no other routes try to create while we're logging

my $string="INFO: Setting up datastore in ".$ENV{'cf_datastore_location'}."\n";
#print LOG $string;
logOutput($string,'method'=>'Datastore');

if(not -d dirname($ENV{'cf_datastore_location'})){
	if($loggingStarted){
		logOutput("-ERROR: CDS CORE: Unable to set up data store in $dataStoreLocation.\n",method=>'CDS');
		return undef;
	} else {
		print STDERR  "CDS ERROR: Unable to set up data store in $dataStoreLocation.\n";
		return undef;
	}
}

print STDERR "INFO: Data store is in ".$ENV{'cf_datastore_location'}.".\n";

my $store=CDS::Datastore::Master->new('cds_run');
return undef if(not $store->init);

return $store;
}

sub readConfigFile
{
my $fh;
my %data;

unless(open $fh,"<$configFileLocation"){
	print STDERR "INFO: Cannot read a configuration file at $configFileLocation. This is not likely to cause a problem\n";
	return \%data;	#return an empty hash
}

while(<$fh>){
	next if(/^#/);
	if(/^\s*([^=]+)\s*=\s*(.*)\s*$/){
		#print "DEBUG: Got value $2 for key $1\n";
		my $key=$1;
		my $val=$2;
		$key=~s/\s//g;
		$val=~s/\s//g;
		$data{$key}=$val;
	}
}
close $fh;

print Dumper(\%data);
#die "Testing";
return \%data;
}

sub untaint
{
	my $data=shift;
	if ($data =~ /^([-\@\w.\/]+)$/) {
		return $1;
	} else {
		die "Potentially tainted data: $data\n";
	}
	
}
