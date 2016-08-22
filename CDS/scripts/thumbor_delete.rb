#!/usr/bin/env ruby

#This CDS method deletes an image that has either been previously uploaded to Thumbor
#via thumbor_upload
#Arguments:
# <image_id>blah|{meta:image_locations} - either list of URLs or image locations returned to the datastore from thumbor_upload
# <hostname> - hostname to access the Thumbor service
# <key> - secret key to access the Thumbor host. Used for URL signing
# <port>nnn [OPTIONAL] - port to access the Thumbor service on. Defaults to 8888.
#END DOC

require 'CDS/Datastore'
require 'Thumbor/Thumbor'
require 'net/http'

class MissingArgument < StandardError
end

class ArgumentError < StandardError
end

def checkArgs(argList)
	argList.each do |a|
		raise MissingArgument,a if(not ENV[a])
	end #argList.each
end #def checkArgs

#START MAIN
$store=Datastore.new('thumbor_delete')

checkArgs(['image_id','hostname','key'])

port = 8888
if(ENV['port'])
begin
	port = $store.substitute_string(ENV['port']).to_i
rescue Exception=>e
	puts "-WARNING: Unable to set port number. Continuing with default of 8888."
end
end

imageIDList = $store.substitute_string(ENV['image_id']).split(/\|/)
hostname = $store.substitute_string(ENV['hostname'])
serverKey = $store.substitute_string(ENV['key'])

puts "INFO: Connecting to Thumbor service at #{hostname}:#{port}..."
thumborService = Thumbor.new(hostname: hostname, key: serverKey, port: port)

successes = 0

imageIDList.each do |imageID|
	retries = 0
	retry_max = 5
	retry_delay = 5
begin
	puts "INFO: Attempting to delete image with ID #{imageID}..."
	thumborService.deleteImage(imageID)
	successes += 1
	
rescue Net::HTTPNotFound=>e
	puts "-ERROR: Unable to find image on server (server responded with 404, resource not found)"

rescue Net::HTTPClientError=>e
	puts "-WARNING: #{e.message} when attempting to delete"
	
	unless(retries==retry_max)
		sleep(retry_delay)
		retries += 1
		retry
	end
rescue Net::HTTPServerError=>e
	puts "-WARNING: #{e.message} when attempting to delete"
	
	unless(retries==retry_max)
		sleep(retry_delay)
		retries += 1
		retry
	end	
end #exception handling
end #imageIDList.each

if(successes==0)
	puts "-ERROR: No image deletes succeeded!"
	exit(1)
end

if(successes < imageIDList.length)
	puts "-ERROR: Not all image deletes succeeded. Check the log above for more details."
	exit(1)
end

puts "+SUCCESS: Deleted #{successes} images from #{hostname}:#{port}"
