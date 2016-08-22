#!/usr/bin/env ruby

$version = "v1.0 $Rev: 1272 $ $LastChangedDate: 2015-07-24 10:45:36 +0100 (Fri, 24 Jul 2015) $"

#This CDS method uses the Thumbor image cropping and manipulation service to crop
#an image that has either been previously uploaded via thumbor_upload or to crop a url
#Arguments:
# <image_id>blah|{meta:image_locations} - either list of URLs or image locations returned to the datastore from thumbor_upload
# <width>nnn - width of output image. Can specify a list to get multiple outputs.
# <heigh>nnn - height of output image. Can specify a list to get multiple outputs. Use the value 0 to mean "proportional"
# <no_smart/> - do NOT use "smart cropping"
# <output_basename>blah - [OPTIONAL] use this as the "base name" of the output files. E.g., if this is myImage.jpg, then resulting files will be called myImage_640x360.jpg, etc. If not specified, then use the file part from the image ID
# <output_path>/path/to/output/files - path to save the cropped images under
# <output_key> - datastore key (under meta: section) to output the list of saved images to
# <no_array/> - do NOT append to an existing value of output_key, but over-write it
# <hostname> - hostname to access the Thumbor service
# <key> - secret key to access the Thumbor host. Used for URL signing
# <port>nnn [OPTIONAL] - port to access the Thumbor service on. Defaults to 8888.
#END DOC

require 'CDS/Datastore'
require 'Thumbor/Thumbor'
require 'net/http'
require 'awesome_print'
require 'fileutils'

def makeCrop(thumborService,imgRef,width: 0,height: 0,smart: true, outpath: ".", basename: "", extension: "")
	if(not Dir.exists?(outpath))
		FileUtils.mkpath(outpath)
	end
	
	outName = File.join(outpath,basename + "_#{width}x#{height}.#{extension}")
	puts "INFO: Cropping #{width}x#{height} to #{outName}"
	
	thumborService.makeCrop(imgRef,outName,width: width, height: height, smart: smart)
	puts "INFO: Done."
	
	return outName
end #def makeCrop

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
$store=Datastore.new('thumbor_crop')
#Step one - set up arguments
checkArgs(['width','height','image_id','output_key','output_path','hostname','key'])

#smart cropping flag
useSmart=true
useSmart=false if(ENV['no_smart'])

#widthxheight lists
dimensions = []
widthList = $store.substitute_string(ENV['width']).split(/\|/)
heightList = $store.substitute_string(ENV['height']).split(/\|/)

n = 0
widthList.each do |w|
	begin
		dimensions << [ widthList[n], heightList[n] ]
	rescue Exception=>e
		puts "WARNING: #{e.message} trying to add dimension #{widthList[n]}x#{heightList[n]}"
	end
	n += 1
end #widthList.each

#output basename and extension
default_basename = ""
default_xtn = "jpg"
if(ENV['output_basename'])
	default_basename = $store.substitute_string(ENV['output_basename'])
	default_xtn = "jpg"

	  #if the basename includes a file extension, separate it out.
	parts = default_basename.match(/^(.*)\.([^\.]+)$/)
	if(parts)
		default_basename=parts[1]
		default_xtn=parts[2]
	end
end #if(ENV['output_basename'])

#output path
outPath = $store.substitute_string(ENV['output_path'])
unless(Dir.exists?(outPath))
	puts "INFO: Path #{outPath} does not exist, attempting to create..."
	#This will throw an exception if the path can't be created
	FileUtils.mkpath(outPath)
	puts "INFO: Done"
end

#Server parameters
hostname = $store.substitute_string(ENV['hostname'])
serverKey = $store.substitute_string(ENV['key'])
imageIDList = $store.substitute_string(ENV['image_id']).split(/\|/)

#OK, now print a banner out
puts "INFO: thumbor_crop version #{$version}."
puts "INFO: Contacting server #{hostname} with key #{serverKey}"
puts "INFO: Image references to work on:"
imageIDList.each do |id|
	puts "\t#{id}"
end #imageIDList.each
puts "INFO: Crops to prepare for each image:"
dimensions.each do |d|
	puts "#{d[0]}x#{d[1]}"
end #dimensions.each

puts "INFO: Setting up Thumbor connection"
thumborService = Thumbor.new(hostname: hostname, key: serverKey)

outputsList = []
imageIDList.each do |imageID|
begin #exception handling
	puts "----------------------------------"
	puts "INFO: Processing #{imageID}"
	basename = ""
	if(default_basename=="")
		basename = File.basename(imageID)
		parts = basename.match(/^(.*)\.([^\.]+)$/)
		if(parts)
			basename = parts[1]
			xtn = parts[2]
		else
			puts "-WARNING: Unable to determine a basename from #{imageID}. Falling back to  default extension of #{default_xtn}"
			basename.gsub!(/[^\w\d_\.]/,'_')
			xtn = default_xtn
		end
	else
		basename = default_basename
		xtn = default_xtn
	end#if(default_basename=="")
	
	puts "INFO: Basename is #{basename}, file extension is #{xtn}"
	dimensions.each do |d|
		retries = 0
		max_retries = 5
		retry_delay = 5
	begin
		outputsList << makeCrop(thumborService, imageID,
									width: d[0], height: d[1],
									smart: useSmart,
									outpath: outPath,
									basename: basename,
									extension: xtn)
	rescue Net::HTTPNotFound=>e
		#re-raise the exception to be caught at the outer loop
		raise Net::HTTPNotFound, e

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

	end #exception handling
	end #dimensions.each
rescue Net::HTTPNotFound=>e #catch a re-raised not found error, because it's pointless to retry every image crop if we know that it does not exist. By rescuing here, we go straight on to processing the next image in the list.
	puts "-ERROR: Image id #{imageID} was not found on server."
	puts e.message
	puts e.backtrace
rescue Exception=>e
	puts "-ERROR: #{e.class} (#{e.message}) occurred processing image ID #{imageID}"
	puts e.backtrace
end #exception handling
end #imageIDList.each

puts "-------------------------------------"

if(outputsList.length == 0)
	puts "-ERROR: No crops succeeded!"
	exit(1)
end

#ap outputsList
#ap outputsList.join('|')

puts "INFO: All crops completed"
#$store.debug = true

if(ENV['no_array']) #over-write output_key
	puts "INFO: Outputting cropped image paths to #{ENV['output_key']}, over-writing any existing value"
	$store.set('meta',ENV['output_key'],outputsList.join('|') )
else
	puts "INFO: Outputting cropped image paths to #{ENV['output_key']}, appending to any existing value"
	currentValue = $store.get('meta',ENV['output_key'])
	output = ""
	if(currentValue == nil or currentValue == "")
		output = outputsList.join('|')
	else
		output = currentValue + '|' + outputsList.join('|')
	end
	$store.set('meta',ENV['output_key'],output )
end #if(ENV['no_array'])

puts "+SUCCESS: Image crops created and output to meta:#{ENV['output_key']}"

