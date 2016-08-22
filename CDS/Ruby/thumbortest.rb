#!/usr/bin/env ruby

$: << './lib'

require 'Thumbor/Thumbor'
require 'trollop'
require 'fileutils'

test_crops = [
	[ 640, 360 ],
	[ 1280, 720 ],
	[ 140, 84 ],
	[ 108, 108 ],
	[ 480, 360 ]
]

#START MAIN
def doCrop(t,inputFile,sizeArray,basepath,xtn)
	if(not Dir.exists?(basepath))
		FileUtils.mkpath(basepath)
	end
	
	outName = File.join(basepath,"#{sizeArray[0]}x#{sizeArray[1]}.#{xtn}")
	puts "Cropping #{sizeArray[0]}x#{sizeArray[1]} to #{outName}"
	
	t.makeCrop(inputFile,outName,width: sizeArray[0], height: sizeArray[1], smart: true)
	puts "Done.\n------------------------------"
	
end #def doCrop

opts = Trollop::options do
	opt :host, "Hostname for Thumbor service", :type=> :string, :default =>"localhost"
	opt :input, "Input image path, on local system", :type =>:string
	opt :key, "Security key for accessing thumbor server", :type=>:string
end #Trollop::options

if(opts[:input]==nil)
	puts "You need to specify a filename with --input"
	exit(1)
end

t = Thumbor.new(hostname: opts[:host], key: opts[:key])

if(not File.exists?(opts[:input]))
	puts "File '#{opts[:input]}' does not exist"
	exit(1)
end

l = t.uploadImage(opts[:input])

puts "Image uploaded to #{l}\n"

xtn = ".jpg"
parts = opts[:input].match(/\.([^\.]+)/)
if(parts)
	xtn = parts[1]
end

begin
	test_crops.each do |c|
		doCrop(t,l,c,File.basename(opts[:input]),xtn)
	end #test_crops.each
ensure
	puts "\nDeleting uploaded image..."
	t.deleteImage(l)
end


