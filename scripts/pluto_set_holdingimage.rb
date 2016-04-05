#!/usr/bin/env ruby

require 'CDS/Datastore'
require 'PLUTO/Entity'
require 'Vidispine/VSItem'

#This method sets the holding image on a master, based on either an item ID or a URI provided
# Arguments:
# <vidispine_host>hostname [OPTIONAL] - Connect to Vidispine running on this server. Defaults to 'localhost'
# <vidispine_port>nnnn [OPTIONAL] - Connect to Vidispine API on this port. Defaults to 8080.
# <vidispine_user>username [OPTIONAL] - Connect to Vidispine using this username. Defaults to admin
# <vidispine_passwd>password - Connect to Vidispine using this password
# <master_id>VX-nnnnn - Vidispine ID of the master in question
# <master_fieldname> [OPTIONAL] - sets the Pluto image identifier JSON on this VS field.  Defaults to gnm_master_generic_holdingimage_16x9.
# <no_strict/> [OPTIONAL] - don't check whether master_id is actually a master
# <image_uri>{file|http|https|...}://xxxx [OPTIONAL] - Despite the name, a (local) path to the image file to import.  You must either specify this or image_id
# <image_sidecar>/path/to/sidecar [OPTIONAL] - sidecar XML file for image_uri, relative to the CDS server.
# <image_sidecar_projection> [OPTIONAL] - projection to use when importing image_sidecar.
# <image_id>VX-nnnnn [OPTIONAL] - Vidispine ID of an already existing image to associate. You must either specify this or image_uri
#END DOC

def import_from_uri(image_uri,sidecar,projection_name,gnm_type)
  item = VSItem.new($vshost,$vsport,$vsuser,$vspass)
  item.debug=true
  #this will wait until the import is done and throw an exception if it fails
  puts "Attempting to import #{image_uri} into Vidispine at #{$vshost}"
  #item.import_uri(image_uri,shape_tags: ['lowimage'],initial_metadata: {'title'=>File.basename(image_uri),'gnm_type'=>'HoldingImage'})
  File.open(image_uri) do |f|
    item.import_raw(f.read, File.basename(image_uri), shape_tags: ['lowimage'])
  end
  
  puts "+SUCCESS: Import completed."
  
  begin
    puts "Attempting to import data from #{sidecar} with projection #{projection_name}"
    if sidecar!=nil
      open(sidecar){ |f|
        item.importMetadata(f.read(),projection: projection_name)
      }
      item.setMetadata({'gnm_type'=> gnm_type}, groupname: nil)
    end
    puts "+SUCCESS: Sidecar import completed"
  rescue StandardError=>e
    puts "-ERROR: Unable to import metadata sidecar: #{e.message}"
    puts e.backtrace
  end
  
  return item
end


#START MAIN
#connect to the datastore
$store=Datastore.new('pluto_set_holdingimage')

$vshost='localhost'
if(ENV['vidispine_host'])
    $vshost=$store.substitute_string(ENV['vidispine_host'])
end
$vsport=8080
if(ENV['vidispine_port'])
    $vsport=$store.substitute_string(ENV['vidispine_port']).to_i
end
$vsuser='admin'
if(ENV['vidispine_user'])
    $vsuser=$store.substitute_string(ENV['vidispine_user'])
end
if(ENV['vidispine_passwd'])
    $vspass=$store.substitute_string(ENV['vidispine_passwd'])
elsif(ENV['vidispine_password'])
    $vspass=$store.substitute_string(ENV['vidispine_password'])
end

master_id = $store.substitute_string(ENV['master_id'])

if master_id==nil
  puts "-ERROR: You must specify <master_id>"
  exit(1)
end

if not master_id.match(/^\w{2}-\d+$/)
  puts "-ERROR: '#{master_id}' doesn't look like a Vidispine ID (not in the form NN-nnnnnn)"
  exit(1)
end

pluto_master = PLUTOMaster.new($vshost,$vsport,$vsuser,$vspass)
pluto_master.populate(master_id)
master_metadata = pluto_master.getMetadata()
if not ENV['no_strict']
  begin
    if master_metadata['gnm_type'].downcase != 'master'
      puts "-ERROR: #{master_id} does not appear to be a PLUTO master (gnm_type was #{master_metadata['gnm_type']})"
      exit(1)
    end
  rescue StandardError=>e
    puts "-ERROR: Unable to verify if #{master_id} is a PLUTO master: #{e.message}"
    puts e.backtrace
    exit(1)
  end
end

image_item = nil

output_fieldnames = ['gnm_master_generic_holdingimage_16x9']
if ENV['master_fieldname']
  output_fieldnames = $store.substitute_string(ENV['output_fieldname']).split(/\|/)
end

if ENV['image_uri']
  image_uri = $store.substitute_string(ENV['image_uri'])
  image_sidecar = nil
  if ENV['image_sidecar']
    image_sidecar = $store.substitute_string(ENV['image_sidecar'])
  end
  sidecar_projection = nil
  if ENV['image_sidecar_projection']
    sidecar_projection = $store.substitute_string(ENV['image_sidecar_projection'])
  end
  
  image_item = import_from_uri(image_uri,image_sidecar,sidecar_projection,'CroppedImage')
  image_item_master = import_from_uri(image_uri, image_sidecar,sidecar_projection,'HoldingImage')
  
elsif ENV['image_id']
  image_id = store.substitute_string(ENV['image_id'])
  if not image_id.match(/^\w{2}-\d+$/)
    puts "-ERROR: image ID #{image_id} doesn't look like a Vidispine ID (not in the form NN-nnnnnn)"
    exit(1)
  end
  
  image_item = VSItem.new($vshost,$vsport,$vsuser,$vspass)
  image_item.populate(image_id)
else
  puts "-ERROR: You must either specify <image_uri> or <image_id> in the method configuration"
  exit(1)
end

puts "INFO: Adding holding image to parent project #{pluto_master.project}"
pluto_master.debug=true
pluto_master.project.addChild(image_item,type: 'item')
pluto_master.project.addChild(image_item_master,type: 'item')
puts "+SUCCESS: Added."

puts "INFO: Adding holding image information to master record #{pluto_master.id}"
output_fieldnames.each do |output_fieldname|
  pluto_master.add_holding_image(output_fieldname,image_item)
end

puts "+SUCCESS: Completed"

