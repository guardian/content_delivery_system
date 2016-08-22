#!/usr/bin/env ruby

#This is a CDS method to update metadata on the given S3 object
#
#Arguments:
# <s3_path>/path/to/object - affect this object
# <s3_bucket>blah - work in this bucket
# <cache_max_age>nnn [OPTIONAL] - set the Cache-Control: max-age= parameter to this value (in seconds)
# <mime_type>mime/type [OPTIONAL] - set the Content-Type: parameter to this value (string)
# <acl_public/> [OPTIONAL] - set object to be publically accessible
# <acl_private/> [OPTIONAL] - set object to not be publically accessible
#END DOC

require 'aws-sdk-v1'
require 'CDS/Datastore'
require 'awesome_print'

#Step one - get the connection
store=Datastore.new('s3_put')

if(ENV['access_key'])
	unless(ENV['secret_key'])
		puts "-ERROR: If you specify <access_key> you should also specify <secret_key>"
		exit 1
	end
	access_key=store.substitute_string(ENV['access_key'])
	puts "INFO: Connecting to AWS using the access key '#{access_key}'"
	$s3=AWS::S3.new(:access_key_id=>access_key,
		:secret_access_key=>store.substitute_string(ENV['secret_key']))
else
	puts "INFO: Trying to connect to AWS using default role"
	$s3=AWS::S3.new
end


#Step two - process commandline arguments
opts={}
if(ENV['acl_public'])
    opts[:acl]="public_read"
end
if(ENV['acl_private'])
    opts[:acl]="private"
end
if(ENV['mime_type'])
    opts[:content_type]=store.substitute_string(ENV['mime_type'])
end

if(ENV['cache_max_age'])
    begin
        opts[:cache_control]="max-age=" + store.substitute_string(ENV['cache_max_age'])
    rescue Exception=>e
        puts "WARNING: #{e.message} when trying to set cache_control parameter"
        puts e.backtrace
    end
end #if(ENV['cache_max_age'])

#Step three - get current metadata
bucketname = store.substitute_string(ENV['s3_bucket'])
bucketpath = store.substitute_string(ENV['s3_path'])

bucket = $s3.buckets[bucketname]
obj = bucket.objects[bucketpath]

if not obj.exists?
  puts "-ERROR: File s3://#{bucketname}/#{bucketpath} does not exist"
  exit 1;
end

extra_data = obj.head()
if not opts.has_key?(:content_type)
  opts[:content_type] = extra_data.content_type
end

md = obj.metadata().to_h

puts "Existing metadata:"
ap md

#Step four - merge metadata
opts.each do |k,v|
  puts "INFO: Will set #{k} to #{v}"
  #md[k] = v
end
opts[:metadata]=md

puts "Options to set:"
ap opts

obj.copy_from(bucketpath,opts)

puts "+SUCCESS: Update succeeded"