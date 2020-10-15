#!/usr/bin/env ruby

#This module tests if an image file is a PNG and, if it is, attempts to convert it into a JPEG.
#It depends on ImageMagick being available on the local node (apt-get install ImageMagick or yum install ImageMagick or port install ImageMagick etc.), specifically the 'convert' and 'identify' commands.
#
#----
#NOTE
#----
#
#Unlike other CDS methods, this method will overwrite the input file with the output file.
#
#Arguments:
# <input_key>{meta:FileNameKey} - use the provided key as an input
# <output_key>keyname - output the path of the file into this key in the meta: section of the datastore

#END DOC

require 'CDS/Datastore'

#START MAIN
store=Datastore.new('png_to_jpeg')

input_image=store.substitute_string(ENV['input_key'])

if input_image==""
  puts "-ERROR No input image provided in 'input_key', can't continue"
  exit(1)
end

unless File.exist?(input_image)
  puts "-ERROR File '#{input_image}' does not exist, can't continue"
  exit(1)
end

cmdline="identify -format '%m' '#{input_image}'"

command_result = system(cmdline)

if command_result
  cmdline="convert '#{input_image}' '#{input_image}'"
  system(cmdline)
else
  puts "The image is already a JPEG."
end

output_path=store.substitute_string(ENV['output_path'])

if ENV['output_key']
  keyname=ENV['output_key']
  store.set('meta',keyname,input_image)
else
  puts "-WARNING: No <output_key> specified so not outputting image path to datastore."
end
