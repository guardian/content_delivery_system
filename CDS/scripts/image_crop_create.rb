#!/usr/bin/env ruby

#This module creates a crop of a provided image file. This is done as a new filename, and the paths of created files are output to the datastore.
#It depends on ImageMagick being available on the local node (apt-get install ImageMagick or yum install ImageMagick or port install ImageMagick etc.), specifically the 'convert' command
#It also depends on having the xmp and exifr ruby gems available
#
#Arguments:
# <image_files>file1|/path/to/file2|{meta:FileNameKey} - use the provided image file(s)
# <target_width>nnnn - the crop should be this width
# <target_height>nnnn - the crop should be this height
# <strict_crop/> - crop pixels from the top or sides to ensure that the image is target_width and target_height high exactly
# <output_path>/path/to/output/files - put the output files in this place
# <output_key>keyname - output the paths of the cropped files into this key in the meta: section of the datastore
# <no_array/> - do NOT append to an existing value of output_key, but over-write it

#END DOC

require 'xmp'
require 'exifr/jpeg'
#require 'awesome_print'
require 'CDS/Datastore'
require 'fileutils'

class FileError < StandardError
end

def find_available_filename(target_path,original_path,append)

target_filename=File.basename(original_path)

unless(Dir.exists?(target_path))
    FileUtils.mkdir_p(target_path)
end

target_out=""

fileparts=target_filename.match(/^(.*)\.([^\.]+)/)
if(fileparts and fileparts[1])
    filebase=fileparts[1]+append
    filextn="."+fileparts[2]
else
    filebase=target_filename+append
    filextn=".jpg"
end
target_filename=filebase+filextn

n=1
loop do
    target_out=File.join(target_path,target_filename)
    unless(File.exists?(target_out))
        break
    end
    target_filename=filebase+"_#{n}"+filextn
    n+=1
end

return target_out

end

def make_crop(source_file,dest_file,target_width,target_height,strict_crop)

unless(File.exists?(source_file))
    raise FileError,"File #{source_file} does not exist."
end

#ensure that the output directory exists
FileUtils.mkdir_p(File.dirname(dest_file))

exifmeta=EXIFR::JPEG.new(source_file)

#if($debug)
#    puts "make_crop: EXIF data of incoming image:"
#    ap exifmeta
#end

target_scale=target_width.to_f/exifmeta.width.to_f

if(exifmeta.height*target_scale < target_height)
        target_scale=target_height.to_f/exifmeta.height.to_f
end

horiz_crop=(exifmeta.width.to_f*target_scale)-target_width
vert_crop=(exifmeta.height.to_f*target_scale)-target_height

if($debug)
    puts "make_crop: Original size: #{exifmeta.width}x#{exifmeta.height}"
    puts "make_crop: Target size: #{target_width}x#{target_height}"
    puts "make_crop: Scaling factor: #{target_scale}"
    puts "make_crop: Vertical crop amount: #{vert_crop}, Horizontal crop amount: #{horiz_crop}"
end

horiz_crop=(horiz_crop/2).to_i #crop is applied to both sides
vert_crop=(vert_crop/2).to_i

target_scale*=100 #Scale factor needs to be expressed as a percentage
cmdline="convert '#{source_file}' -scale #{target_scale}% -shave #{horiz_crop}x#{vert_crop} '#{dest_file}'"

if($debug)
    puts "I will run #{cmdline}"
end

system(cmdline)

if($?.exitstatus != 0)
    raise StandardError,"ImageMagick returned an error."
end
end

def recrop(source_file,dest_file,horiz_remain,vert_remain)

if($debug)
    puts "recrop: Cropping to #{horiz_remain}x#{vert_remain} from #{source_file} and outputting to #{dest_file}"
end
cmdline = "convert '#{source_file}' -crop #{horiz_remain}x#{vert_remain} '#{dest_file}'"

system(cmdline)
if($?.exitstatus != 0)
    raise StandardError,"ImageMagic returned an error, code #{$?.exitstatus}"
end

end #def recrop

def reshave(source_file,dest_file,horiz_crop,vert_crop)

if($debug)
    puts "reshave: Shaving an extra #{horiz_crop} x #{vert_crop} from #{source_file} and outputting to #{dest_file}"
end
cmdline="convert '#{source_file}' -shave #{horiz_crop}x#{vert_crop} '#{dest_file}'"

if($debug)
    puts "I will run #{cmdline}"
end

system(cmdline)
if($?.exitstatus != 0)
    raise StandardError,"ImageMagick returned an error, code #{$?.exitstatus}"
end
end #def reshave

#START MAIN
store=Datastore.new('image_crop_create')

if(ENV['debug'])
    $debug=true
else
    $debug=false
end

files_to_process=[]
source_file_string=store.substitute_string(ENV['image_files'])
source_file_string.split('|').each do |filename|
    if(File.exists?(filename))
        files_to_process << filename
    else
        puts "-WARNING: File '#{filename}' does not exist or cannot be read"
    end
end

if(files_to_process.length<1)
    puts "-ERROR: No files can be found to crop"
    exit 1
end

begin
    target_width=store.substitute_string(ENV['target_width']).to_i
rescue Exception=>e
    puts "-ERROR: #{ENV['target_width']} is not a valid number."
    exit 1
end
begin
    target_height=store.substitute_string(ENV['target_height']).to_i
rescue Exception=>e
    puts "-ERROR: #{ENV['target_height']} is not a valid number."
    exit 1
end

strict=false
if(ENV['strict_crop'])
    strict=true
end

output_path=store.substitute_string(ENV['output_path'])

puts "image_crop_create version 1.0"
puts
puts "Files to operate on:"
files_to_process.each do |fn|
    puts "\t#{fn}"
end
puts "Strict cropping is #{strict}"
puts "Target image size: #{target_width}x#{target_height}"

filename_list=""

files_to_process.each do |filename|
    begin
        output_file=find_available_filename(output_path,filename,"_"+target_width.to_s)
        make_crop(filename,output_file,target_width,target_height,strict)
        #sometimes ImageMagick is out by 1 pixel when cropping. So, re-run the crop if we're not exactly right...
        exifmeta=EXIFR::JPEG.new(output_file)
	puts "INFO: Resultant crop is #{exifmeta.width}x#{exifmeta.height}"
        if(exifmeta.width != target_width or exifmeta.height != target_height)
            #make_crop(output_file,output_file,target_width,target_height,strict)
            recrop(output_file,output_file,target_width,target_height)
        end
        filename_list+="#{output_file}|"
    rescue Exception=>e
        puts "-WARNING: Unable to create crop of #{filename}: #{e.message}"
        if($debug)
            puts e.backtrace
        end
    end
end

filename_list.chop! #remove the trailing | character

if(ENV['output_key'])
    keyname=ENV['output_key']
    existing_value=""
    unless(ENV['no_array'])
        existing_value=store.get('meta',keyname)
    end
    new_value=""
    if(existing_value.length>0)
        new_value=existing_value+"|"+filename_list
    else
        new_value=filename_list
    end
    store.set('meta',keyname,new_value)

else
    puts "-WARNING: No <output_key> specified so not outputting cropped image paths to datastore."
end
