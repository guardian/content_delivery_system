#!/usr/bin/env ruby

VERSION = '$Rev: 1223 $ $LastChangedDate: 2015-05-16 12:59:54 +0100 (Sat, 16 May 2015) $'
# This CDS method allows us to look up the metadata associated with a given commission, or the commission associated with a given master
#
# Arguments:
#    <commission_id>blah [OPTIONAL] - look up this commission ID
#    <master_id>blah [OPTIONAL] - look up the commission associated with this master ID
#    <vidispine_host>hostname - talk to Vidispine on this computer
#    <vidispine_port>8080 [OPTIONAL] - talk to Vidispine on this TCP port
#    <vidispine_user>username - log in to Vidispine with this username
#    <vidispine_password>passwd - log in to Vidispine with this password
#    <output_namespace>gnm_commission [OPTIONAL] - apply this as a prefix to all output keys. Default is gnm_commission; any keys that are already having gnm_commission have it replaced by this value.
#END DOC

require 'PLUTO/Entity'
require 'Vidispine/VSItem'
require 'CDS/Datastore'
require 'awesome_print'

def get_commission_reference(item)
  #normally the commission should be the lowest value of __ancestor_collection, and __ancestor_collection should contain two IDs
  #(project ref and commission ref)
  ancestor_collection = item.metadata['__ancestor_collection']
  if ancestor_collection.is_a?(Array)
    ancestor_collection = ancestor_collection.sort { |a,b|
      #sort by the numeric parts of the IDs
      parts = a.match(/[A-Za-z]{2}-(\d+)$/)
      #ap parts
      if not parts
        raise ArgumentError, "#{a} is not a valid Vidispine ID"
      end
      numeric_a = parts[1].to_i
      
      parts = b.match(/[A-Za-z]{2}-(\d+)$/)
      if not parts
        raise ArgumentError, "#{b} is not a valid Vidispine ID"
      end
      numeric_b = parts[1].to_i
      
      #puts "debug: comparing #{numeric_a} to #{numeric_b}"
      numeric_a <=> numeric_b
      }
  else
    ancestor_collection = [ancestor_collection]
  end #if ancestor.collection.is_a?(Array)
  ap ancestor_collection
  
  ancestor_collection.each do |container_id|
    next if not container_id.is_a?(String)
    container = PLUTOCommission.new($vshost,$vsport,$vsuser,$vspass)
    #container.debug = true
    container.populate(container_id)
    puts "Checking metadata for #{container_id}..."
    ap container.metadata
    if not container.metadata['gnm_type']
      puts "-WARNING: container collection #{container_id} is not a PLUTO object (no gnm_type)"
      next
    end
    
    if container.metadata['gnm_type'].downcase == 'commission'
      return container
    end
  end
  raise ArgumentError, "Item #{item.metadata['itemId']} does not appear to belong to a commission"
end

#START MAIN
$store = Datastore.new('pluto_get_commission_info')

$vshost = $store.substitute_string(ENV['vidispine_host'])
$vsport = 8080
if ENV['vidispine_port']
  begin
    $vsport = $store.substitute_string(ENV['vidispine_port']).to_i
  rescue StandardError=>e
    puts "-WARNING: Unable to get a port number from #{$store.substitute_string(ENV['vidispine_port'])}: #{e.message}."
    puts "-WARNING: Using default port of 8080."
  end
end
$vsuser = $store.substitute_string(ENV['vidispine_user'])
$vspass = $store.substitute_string(ENV['vidispine_password'])

output_namespace = "gnm_commission"
if ENV['output_namespace']
  output_namespace = $store.substitute_string(ENV['output_namespace'])
end

if ENV['master_id']
  master_id = $store.substitute_string(ENV['master_id'])
  item = VSItem.new($vshost,$vsport,$vsuser,$vspass)

  begin
    item.populate(master_id)
    commission_ref = get_commission_reference(item)
  rescue VSNotFound=>e
    puts "-ERROR: No collection could be found for commission_id #{commission_id}"
    exit(1)
  rescue VSException=>e
    puts "-ERROR: Vidispine unable to look up collection for #{commission_id}: #{e.message}"
    exit(1)
  rescue ArgumentError=>e
    if ENV['debug']
      puts e.backtrace
    end
    puts "-ERROR: Unable to look up commission references for #{master_id}: #{e.message}"
    exit(1)
  end
  #ap item.metadata
  
  
  
  puts "Got commission reference #{commission_ref.metadata['collectionId']}, #{commission_ref.metadata['title']} for master #{master_id}"
elsif ENV['commission_id']
  commission_ref = PLUTOCommission.new($vshost,$vsport,$vsuser,$vspass)
  commission_id = $store.substitute_string(ENV['commission_id'])
  
  begin
    commission_ref.populate(commission_id)
  rescue VSNotFound=>e
    puts "-ERROR: No collection could be found for commission_id #{commission_id}"
    exit(1)
  rescue VSException=>e
    puts "-ERROR: Vidispine unable to look up collection for #{commission_id}: #{e.message}"
    exit(1)
  end
  
  if not commission_ref.metadata['gnm_type']
    raise ArgumentError, "#{commission_id} is not a PLUTO object (no gnm_type field)"
  end
  
  if commission_ref.metadata['gnm_type'].downcase!='commission'
    raise ArgumentError, "#{commission_ref.metadata['collectionId']} (#{commission_ref.metadata['title']}) is not a commission (type #{commission_ref.metadata['gnm_type']})"
  end
  
  puts "Got commission reference #{commission_ref.metadata['collectionId']}, #{commission_ref.metadata['title']} from direct entity id"
else
  puts "-ERROR: You must specify either <master_id> or <commission_id> in the route file. Normally you would use a substitution like {meta:itemId} to get the relevant information"
  exit(1)
end

to_set = {}
commission_ref.metadata.each {|k,v|
  if not k.match(/^_/)
    #apply namespace to keys if they don't have one already
    #puts "got #{k}"
    if output_namespace != "gnm_commission" and k.match(/^gnm_commission/)
      #puts "changing ns for #{k}"
      k=k.sub(/^gnm_commission/,output_namespace)
    elsif not k.match(/^#{output_namespace}/)
      #puts "applying prefix #{output_namespace} to #{k}"
      k = "#{output_namespace}_#{k}"
    else
      #puts "no change necessary"
    end
    to_set[k] = v
  end #if not k.match
}

puts "Data to set:"
ap(to_set)
$store.set('meta',to_set)
