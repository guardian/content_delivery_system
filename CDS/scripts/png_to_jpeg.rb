#!/usr/bin/env ruby

#This module tests if an image file is a PNG and, if it is, attempts to convert it into a JPEG.
#It depends on ImageMagick being available on the local node (apt-get install ImageMagick or yum install ImageMagick or port install ImageMagick etc.), specifically the 'convert' and 'identify' commands.
#
#Arguments:
# <input_file>file1|/path/to/file2|{meta:FileNameKey} - use the provided image file
# <output_path>/path/to/output/files - put the output files in this place
# <output_key>keyname - output the path of the file into this key in the meta: section of the datastore

#END DOC

require 'CDS/Datastore'

#START MAIN
store=Datastore.new('png_to_jpeg')

input_image=store.substitute_string(ENV['input_file'])

cmdline="identify -format '%m' '#{input_image}'"

command_result = system(cmdline)

if (command_result)
  cmdline="convert '#{input_image}' '#{input_image}'"
  system(cmdline)
else
  puts "The image is already a JPEG."
end

output_path=store.substitute_string(ENV['output_path'])

if(ENV['output_key'])
    keyname=ENV['output_key']
    store.set('meta',keyname,input_image)

else
    puts "-WARNING: No <output_key> specified so not outputting image path to datastore."
end
