#!/usr/bin/env ruby

#This CDS method performs an upload to an instance of the Thumbor image cropping and resizing
#service.  For actual crops, see the thumbor_crop method. To complete processing, use thumbor_delete
#to delete the server-side cached image.
#
#Arguments:
#  <take-files>media [OPTIONAL] - use the media file as an image to crop. Leave this out if main media is e.g. a video
#  <extra_files>file1|file2|{meta:file3}... - upload these files
#  <output_key>keyname  - output the uploaded location IDs of the images to this key, under the {meta:} section.
#  <hostname>host - hostname or IP address of Thumbor server (could be 'localhost')
#  <port>nnn [OPTIONAL] - port to access Thumbor on. Defaults to 8888
#  <key>blah - access key for Thumbor server
#END DOC

require 'Thumbor/Thumbor'
require 'CDS/Datastore'
require 'net/http'	#for exceptions

class FileDoesNotExist < StandardError
end

class ConvertError < StandardError
end

$typesToConvert = [ 'image/tiff', 'image/tif' ]
$scratchOutputFolder = "/tmp"
$convertArgs = ""

#Thumbor does not appear to support TIFFs. So let's convert to jpeg here.
def checkForTiff(imagePath)
	mimeType=MimeMagic.by_magic(File.open(imagePath)).type
	puts "checkForTiff: got mime type #{mimeType}"
	$typesToConvert.each do |t|
		puts "checkForTiff: comparing #{mimeType} to #{t}"
		if(mimeType == t)
			outputName = File.join($scratchOutputFolder, File.basename(imagePath) + '.jpg' )
			result = `convert '#{imagePath}' '#{outputName}' #{$convertArgs}`
			if($? != 0)
				raise ConvertError,"-ERROR: Unable to convert image #{imagePath}: #{result}"
			end
			return outputName
		end #if(mimeType == t)
	end #typesToConvert.each
	return imagePath
end #checkForTiff

#START MAIN
$store = Datastore.new('thumbor_upload')

files_to_process = []

if(ENV['cf_media_file'])
	files_to_process << ENV['cf_media_file']
end

if(ENV['extra_files'])
	ENV['extra_files'].split(/\|/).each do |f|
		files_to_process << $store.substitute_string(f)
	end
end

if(files_to_process.length <1)
	puts "-ERROR: No files to process.  You need to either specify <take-files>media or <extra_files> in the route configuration"
	exit(1)
end

portnum = 8888
if(ENV['port'])
	begin
		portnum = $store.substitute_string(ENV['port']).to_i
	rescue Exception=>e
		puts "-WARNING: #{e.message} converting port number to integer. Using default value of 8888"
	end
end

t=Thumbor.new(hostname: $store.substitute_string(ENV['hostname']),
			port: portnum,
			key: $store.substitute_string(ENV['key']))

locationKeys = ""
successful = 0
max_retries = 5
retry_delay = 5

files_to_process.each do |f|
	retries = 0
	begin
		if(not File.exists?(f))
			raise FileDoesNotExist, f
		end
		
		f = checkForTiff(f)
		
		puts "INFO: Uploading image #{f}..."
		location = t.uploadImage(f)
		puts "INFO: Uploaded #{f} to #{location}"
		
		locationKeys += location + '|'
		
		successful += 1
	rescue ConvertError=>e
		puts "-ERROR: #{e.message}"
		
	rescue Net::HTTPClientError=>e
		puts "-WARNING: #{e.message} on attempt #{retries} of #{max_retries}"
		sleep(retry_delay)
		retries += 1
		retry
	
	rescue Net::HTTPServerError=>e
		puts "-WARNING: #{e.message} on attempt #{retries} of #{max_retries}"
		sleep(retry_delay)
		retries += 1
		retry
			
	rescue FileDoesNotExist=>e
		puts "-WARNING: File #{e.message} does not exist, so I can't upload."
	
	end
	
end #files_to_process.each

if(successful==0)
	puts "-ERROR: Could not upload any images!"
	exit(1)
end

$store.set('meta',ENV['output_key'],locationKeys.chop())

puts "+SUCCESS: Uploaded #{successful} images and output their location keys to #{ENV['output_key']}"
