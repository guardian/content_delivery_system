#!/usr/bin/env ruby

#This method downloads the given file from S3, and sets the current media file to the location of the downloaded file.
#
#Arguments (all take substitutions unless noted):
#  <bucket>{name} - download from this bucket name
#  <filepath>/path/to/file - path to the file to download, within the bucket
#  <cachepath>/path/to/localfile - path on the local machine to download to
#  <access_key>{key} - your AWS API access key.  If not specified, will try to use an AWS Role associated to the current instance to gain permissions. Does not support substitutions.
#  <secret_key>{secret} - your AWS API secret key ('password').  If not specified, will try to use an AWS Role associated to the current instance to gain permissions. Does not support substitutions.
#END DOC

require 'aws-sdk-v1'
require 'fileutils'

def substitute_string(string)
`/usr/local/bin/cds_datastore.pl subst "#{string}"`
end

#START MAIN
begin

unless ENV['bucket']
	raise "You need to specify a bucket to download from in the <bucket> argument"
end

unless ENV['filepath']
	raise "You need to specify a file path to download in the <filepath> argument"
end

if ENV['cachepath']
	cachepath=substitute_string(ENV['cachepath']).chomp
else
	cachepath=ENV['pwd']
end

if ENV['access_key'] and ENV['secret_key']
	AWS.config(:access_key_id=>ENV['access_key'],:secret_access_key=>ENV['secret_key'])
end

if not Dir.exists?(cachepath)
	puts "#{cachepath} does not exist, attempting to create..."
	begin
		FileUtils.mkpath(cachepath)
	rescue StandardError=>e
		puts "-ERROR: Unable to create directory #{cachepath}: #{e}"
		exit(1)
	end
end

$s3=AWS::S3.new

bucketname=substitute_string(ENV['bucket']).chomp
bucket=$s3.buckets[bucketname]

unless bucket.exists?
	raise "Unable to connect to the bucket #{bucketname}"
end

filepath=substitute_string(ENV['filepath']).chomp
fn=File.basename(filepath)

puts "Downloading the file #{filepath} from #{bucketname}..."
obj=bucket.objects[filepath]

unless obj.exists?
	raise "Unable to open the object '#{filepath}'"
end

localfile=cachepath + '/' + fn
parts = fn.match(/^(?<Name>.*)\.(?<Xtn>[^\.]+)$/x)
n=0
while File.exists?(localfile) do
	n+=1
	localfile=cachepath + '/' + parts['Name'] + '-' + n.to_s + '.' + parts['Xtn']
end

puts "INFO: Outputting to #{localfile}"

File.open(localfile,'wb') do |file|
	obj.read do |chunk|
		file.write(chunk)
	end
end

tempfile = ENV['cf_temp_file']
if tempfile
	puts "INFO: Outputting to route as new media file..."
	File.open(tempfile,"w") do |file|
		file.write("cf_media_file=" + localfile)
	end
end

print "+SUCCESS: Downloaded file to #{localfile}"

rescue Exception=>e
	puts "-ERROR: #{e.message}\n"
	exit 1
ensure

end
