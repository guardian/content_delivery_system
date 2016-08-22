#!/usr/bin/env ruby

$version = '$Rev: 1252 $ $LastChangedDate: 2015-07-16 16:35:56 +0100 (Thu, 16 Jul 2015) $'

#This CDS method waits for a file to exist in S3.  Extra delays shouldn't be necessary, since S3 hides the file until it has finished writing
#  <take-files>media|{meta|inmeta}		- you need to 'take' media in order to be able to match {filebase},{filename} etc.
#  <check-file-path>/path/to/lockfile	- wait for this file to exist.  Usual substitutions are allowed.
#  <bucket>bucketname                   - look in this bucket
#  <poll_time>n						- look for the file every n seconds
#  <timeout>n 		[OPTIONAL]			- give up and abort the route after n seconds
#  <invert/>			[OPTIONAL]		- wait until the file does NOT exist
#  <aws_key>key [OPTIONAL]              - use this AWS key to connect. Otherwise, the default environment variables are checked, or a Role is used if running in EC2 and one is available.
#  <aws_secret>secret [OPTIONAL]        - use this as the secret part of the AWS key above
#END DOC

require 'aws-sdk-v1'
require 'CDS/Datastore'

def assert_argument(arglist)
    arglist.each do |arg|
        raise ArgumentError,"You need to specify <#{arg}> in the routefile to use this method." unless(ENV[arg])
    end
end

#START MAIN
#print output synchronously, so progress appears in the log
$stdout.sync = true
$stderr.sync = true
assert_argument(['check_file_path','bucket'])
$store=Datastore.new('wait_for_s3')

if(ENV['aws_key'] and ENV['aws_secret'])
	puts "INFO: Connecting to AWS using the access key '#{ENV['aws_key']}'"
	$s3=AWS::S3.new(:access_key_id=>$store.substitute_string(ENV['aws_key']),
                    :secret_access_key=>$store.substitute_string(ENV['aws_secret']))
else
    puts "INFO: Trying to connect to AWS using default role"
    $s3=AWS::S3.new
end


path = $store.substitute_string(ENV['check_file_path'])
bucketname = $store.substitute_string(ENV['bucket'])
poll_time = 5
timeout = 600

begin
    poll_time = $store.substitute_string(ENV['poll_time']).to_i
rescue Exception
end

begin
    timeout = $store.substitute_string(ENV['timeout']).to_i
rescue Exception
end

begin
    bucket = $s3.buckets[bucketname]
rescue Exception=>e
    puts "-ERROR: Unable to get bucket #{bucketname}: #{e.message}"
    puts e.backtrace if(ENV['debug'])
    exit(1)
end

start_time = Time.new.to_i
found = false
retries = 0
begin
    sleep(poll_time)
    puts "Searching for #{path} in #{bucketname}"

    found = bucket.objects[path].exists?
    if(ENV['invert'])
        found=!found
    end

#    if(ENV['invert'])
#        found=true unless(bucket.objects[path].exists?)
#    else
#        found=true if(bucket.objects[path].exists?)
#    end

    elapsed = Time.new.to_i - start_time
    puts "Elapsed time: #{elapsed}"
    if(elapsed>timeout)
        desc = "is not found"
        desc = "still exists" if(ENV['invert'])
        puts "ERROR: #{path} #{desc} in #{bucketname} after #{timeout} seconds: giving up."
        exit(1)
    end
    
	rescue AWS::Errors::ServerError=>e
    retries+=1
    puts "\tWARNING: AWS returned a server error '#{e.message}' (attempt #{retries})"
    retry
    
	rescue AWS::Errors::ClientError=>e
    retries+=1
    puts "\tWARNING: AWS returned a client error '#{e.message}' (attempt #{retries})"
    retry
    
	rescue IOError=>e
    retries+=1
    puts "\tWARNING: A local IO error '#{e.message}' occurred (attempt #{retries})"
    retry
    
	rescue SystemCallError=>e
    retries+=1
    puts "\tWARNING: A local system error '#{e.message}' occurred (attempt #{retries})"
    retry	
 
end while(not found)

desc = "is found"
desc = "has gone from" if(ENV['invert'])
puts "+SUCCESS: #{path} #{desc} in #{bucketname}"
exit(0)
