#!/usr/bin/env ruby

#This method uploads the given file(s) to Amazon S3.
#Uploads are carried out over HTTPS by default.

#Arguments:
# <take-files>{media|meta|inmeta|xml} - upload these files
# <bucket> bucketname				- upload to this S3 bucket
# <upload_path>/upload/path/in/bucket [optional] - upload to this path within the bucket
# <recurse_m3u8/> - if the media file is an m3u8, then parse it and also upload all of the referenced index and media
# <m3u8_base_path>/path/to/components [optional] - use this as the base path when working out where the m3u8 components are on disk. Defaults to the same directory as the media file.
# <m3u8_no_rebase/> - by default, the m3u8 index files are re-written to point to the provided upload_path. This switch disables this behaviour.
# <dry_run/>	[optional]			- does not perform the actual upload
# <recursive/>	[optional]			- recursively search the local path [NOT IMPLEMENTED YET]
# <acl_public/>	[optional]			- Ensure that the file is set to public-readable
# <acl_private/> [optional]			- Ensure that only the uploading user has access to the file
# <custom_headers>key=value|{meta:keyname}={meta:value}|... [OPTIONAL] - set these custom header values on S3.  Substitutions accepted for key and value.  Note that key names must be all lower case, and will have x-amz-meta- prepended to them if they don't have it already.
# <mime_type>type [optional]		- Manually set the MIME type of the file (not usually necessary)
# <cache_max_age>age (seconds) [optional] - Set the cache-control max-age header for clients reading this object from the bucket. Does not affect S3 itself, but affects clients and CDNs reading from s3
# <debug/>	[optional]				- output loads of debug information
# <extra_files>file1|file2|{media:url}|... - add the following files to the upload list.  Substitutions are accepted
# <recurse_m3u/> [optional]			- interrogate any m3u8 HLS manifests found and add their contents to the processing list.  Expects <basepath> to be set
# <basepath>/path/to/m3u8/contents	- use this path to find the contents that the HLS manifests are pointing to.  In order to upload an HLS rendition, it's assumed that all of the bits must be held locally.... So we remove the http://server.name.com/ part of the URL and replace with the contents of this parameter (substitutions accepted) in order to find them to upload.
# <access_key>{key} [optional]		- use this AWS access key to authenticate. If not specified, tries to authenticate using AWS Roles.
# <secret_key>{secret} [optional]	- use with <access_key> to specify the secret part of the key
# <allow_overwrite/> [optional]		- allow the method to over-write files already in the bucket (by default, will refuse to upload)
# <version_old/>	[optional]		- instead of over-writing, move an old file to the same filename with a .1, .2 etc. postfix
# <allow_partial/>	[optional]		- don't flag an error if some files fail to upload
# <output_url_key>keyname [optional] 	- output a presigned URL to this datastore key, so other methods can 'see' the uploaded file
# <output_public_url/>	[optional]	- output a public URL as opposed to a presigned one
# <output_url_expiry>3600 [optional]	- set the expiry time for generated URLs. defaults to none (unlimited)
#END DOC

require 'aws-sdk-v1'
require 'CDS/Datastore'
require 'CDS/HLSUtils'
require 'awesome_print'

class CustomHeaders

def initialize(store,headerString)
  @datastore = store
  @args = {}
  parts = headerString.split('|')
  parts.each {|hdr|
	  str=store.substitute_string(hdr)
	  strparts = str.match(/^([^=]+)=(.*)$/)
	  if strparts
		@args[strparts[1].downcase()]=strparts[2]
	  end
	}
end #def initialize

def value()
  @args.clone
end


end #class CustomHeaders

class FileExistsException < StandardError
end

def rename_existing_object(s3object, bucket)

n=1
loop do
	new_name=s3object.key+'.'+n.to_s
	break unless(bucket.objects[new_name].exists?)
	n+=1
end
s3object.move(new_name)

end

#START MAIN
#print output synchronously, so progress appears in the log
$stdout.sync = true
$stderr.sync = true
store=Datastore.new('s3_put')

unless(ENV['bucket'])
	puts "-ERROR: You must specify a bucket to upload to, using the <bucket> option"
	exit 1
end

prefix=store.substitute_string(ENV['upload_path'])

if(prefix==nil)
	prefix=""
end

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

files_to_upload=Array.new
if(ENV['cf_media_file'] !="")
	files_to_upload << ENV['cf_media_file']
end
if(ENV['cf_inmeta_file'] != "")
	files_to_upload << ENV['cf_inmeta_file']
end
if(ENV['cf_meta_file'] !="" )
	files_to_upload << ENV['cf_meta_file']
end
if(ENV['cf_xml_file'] !="")
	files_to_upload << ENV['cf_xml_file']
end

if(ENV['extra_files'])
	ENV['extra_files'].split('|').each { |filename|
		files_to_upload << store.substitute_string(filename)
	}
end

m3u_files=Array.new
files_to_upload.each do |filename|
    unless(ENV['recurse_m3u8'])
        break
    end
   if(filename=~/\.m3u8$/)
       basepath=File.dirname(filename)
       if(ENV['m3u8_base_path'])
           basepath=$store.substitute_string(ENV['m3u8_base_path'])
        end
       it=HLSIterator.new(filename,basepath)
       unless(ENV['m3u8_no_rebase'])
           #ensure that the m3u8 files actually point to the path where we're going to upload them 
           it.rebase("HLS/",prefix)
       end #
       it.each do |componentfile,componenturi|
           m3u_files << componentfile
       end #it.each
   end #if(filename=~/\.m3u8$/)
end #files_to_upload.each

m3u_files.each do |f|
    files_to_upload << f
end

puts "INFO: Files to upload:"
ap files_to_upload

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

if(ENV['custom_headers'])
   opts[:metadata] = CustomHeaders.new(store,ENV['custom_headers']).value()
end

if(ENV['debug'])
    puts "debug: upload options:"
    ap opts
end

bucketname=store.substitute_string(ENV['bucket'])
puts "INFO: Attempting to upload to #{bucketname}..."
bucket=$s3.buckets[bucketname]

total_files=files_to_upload.count
n_success=0
n=0

max_retries=10
if(ENV['max_retries'])
	max_retries=store.substitute_string(ENV['max_retries']).to_i
end

urls_to_output=[]
output_url_expiry=nil
if ENV['output_url_expiry']
	output_url_expiry=store.substitute_string(ENV['output_url_expiry']).to_i
end

files_to_upload.each { |filename|
	retries=0
	n+=1
	begin
		objectname=File.join(prefix,File.basename(filename))
		unless(objectname.start_with?("/"))
			objectname=objectname
		end
		
		puts "#{n}/#{total_files}: Will upload #{filename} to s3://#{bucketname}/#{objectname}"
		if(bucket.objects[objectname].exists?)
			puts "\tWARNING: File s3://#{bucketname}/#{objectname} already exists"
			if(ENV['allow_overwrite'])
				puts "\tWARNING: Over-writing existing file s3://#{bucketname}/#{objectname}  as <allow_overwrite/> has been specified"
			elsif(ENV['version_old'])
				#any AWS exceptions this throws should be caught at the end of this block, below
				rename_existing_object(bucket.objects[objectname], bucket)
			else
				raise FileExistsException,"Not uploading s3://#{bucketname}/#{objectname} because it already exists. Use <allow_overwrite/> or <version_old/> to upload anyway"
			end
		end
		
		if(ENV['dry_run'])
			puts "WARNING: Not uploading to s3://#{bucketname}/#{objectname} as <dry_run/> was specified"
		else
			#remove multiple slashes from the object name to prevent blank "directories" appearing
			objectname.gsub!(/\/+/,'/')
			objectname.gsub!(/^\//,'')
			bucket.objects[objectname].write(File.open(filename,"rb"),opts)
			puts "+SUCCESS: s3://#{bucketname}/#{objectname} has been uploaded"
			if ENV['output_url_key']
				if ENV['output_public_url']
					urls_to_output << bucket.objects[objectname].public_url.to_s
				else
					urls_to_output << bucket.objects[objectname].url_for(:read, :expires=>output_url_expiry).to_s
				end
			end
			
		end
		n_success+=1
		
	rescue FileExistsException=>e
		#raised in the code above if the file exists and we don't have instructions to re-version or over-write
		puts "-ERROR: #{e.message}"
		next
		
	rescue AWS::Errors::ServerError=>e
		retries+=1
		puts "\tWARNING: AWS returned a server error '#{e.message}' (attempt #{retries} of #{max_retries})"
		if(retries>=max_retries)
			puts "-ERROR: Giving up attempting to upload s3://#{bucketname}/#{objectname}"
			if(ENV['debug'])
				puts e.backtrace
			end
			next
		end
		retry
		
	rescue AWS::Errors::ClientError=>e
		retries+=1
		puts "\tWARNING: AWS returned a client error '#{e.message}' (attempt #{retries} of #{max_retries})"
		if(retries>=max_retries)
			puts "-ERROR: Giving up attempting to upload s3://#{bucketname}/#{objectname}"
			if(ENV['debug'])
				puts e.backtrace
			end
			next
		end
		retry
		
	rescue IOError=>e
		retries+=1
		puts "\tWARNING: A local IO error '#{e.message}' occurred (attempt #{retries} of #{max_retries})"
		if(retries>=max_retries)
			puts "-ERROR: Giving up attempting to upload s3://#{bucketname}/#{objectname}"
			if(ENV['debug'])
				puts e.backtrace
			end
			next
		end
		retry	
	rescue Net::OpenTimeout=>e
		retries+=1
		puts "\tWARNING: A Net::OpenTimeout error '#{e.message}' occurred (attempt #{retries} of #{max_retries})"
		sleep(5)
		if(retries>=max_retries)
			puts "-ERROR: Giving up attempting to upload s3://#{bucketname}/#{objectname}"
			if(ENV['debug'])
				puts e.backtrace
			end
			next
		end
		retry			
	rescue SystemCallError=>e
		retries+=1
		puts "\tWARNING: A local system error '#{e.message}' occurred (attempt #{retries} of #{max_retries})"
		if(retries>=max_retries)
			puts "-ERROR: Giving up attempting to upload s3://#{bucketname}/#{objectname}"
			if(ENV['debug'])
				puts e.backtrace
			end
			next
		end
		retry	
	end
}

if ENV['output_url_key']
	store.set('meta',ENV['output_url_key'],urls_to_output.join('|'))
end

if(n_success==total_files)
	puts "+SUCCESS: all #{n_success} files are uploaded"
elsif(n_success>1)
	unless(ENV['allow_partial'])
		puts "-ERROR: only #{n_success} out of #{total_files} were uploaded to S3."
		exit 1
	end
	puts "-WARNING: only #{n_success} out of #{total_files} were uploaded to S3."
else
	puts "-ERROR: Unable to upload to S3"
	exit 1
end
