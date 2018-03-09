#!/usr/bin/env ruby

#This module attempts to load a metadata key from Vidispine and sets a metadata key to the loaded value
#
#Arguments:
#  <host>hostname [OPTIONAL] - host to communicate with (defaults to localhost)
#  <port>portnum [OPTIONAL] - port to communicate with Vidispine on (defaults to 8080)
#  <user>username- username for Vidispine
#  <passwd>pass - password for Vidispine
#  <read_key>string = Key to read from Vidispine
#  <output_key>string = Key to output to the data store

#END DOC

require 'CDS/Datastore'
require 'Vidispine/VSItem'
require 'Vidispine/VSApi'
require 'awesome_print'

#START MAIN
$store=Datastore.new('get_vidispine_metadata_field')

$debug=ENV['debug']

vsid=$store.get('meta','itemId')
if(ENV['item_id'])
    vsid=$store.substitute_string(ENV['item_id'])
end

if(vsid==nil)
    puts "-ERROR: You need to specify a Vidispine item to update.  Neither the meta:item_id key nor the routefile argument <item_id> was set, so I can't continue."
    exit(1)
end

unless(vsid=~/^[A-Za-z0-9]{2}-\d+$/)
    puts "-ERROR: The given Vidispine ID (#{vsid}) does not look like a valid Vidispine ID (e.g., VX-1234)."
    exit(1)
end

begin
	hostname='localhost'
    if(ENV['host'])
        hostname=$store.substitute_string(ENV['host'])
    end
  
    port = 8080
    if(ENV['port'])
        port=$store.substitute_string(ENV['port']).to_i
    end

    user='admin'
    if(ENV['user'])
        user=$store.substitute_string(ENV['user'])
    end

    passwd=''
    if(ENV['password'])
        passwd=$store.substitute_string(ENV['password'])
    end
    if(ENV['passwd'])
        passwd=$store.substitute_string(ENV['passwd'])
    end
rescue Exception=>e
    puts "-ERROR: Unable to set up Vidispine connection parameters: #{e.message}"
    if($debug)
        puts e.backtrace
    end
    exit(1)
end

item=VSItem.new(hostname,port,user,passwd)

begin
    item.populate(vsid)
rescue VSException=>e
    puts "-ERROR: Unable to look up Vidispine item '#{vsid}'"
    puts e.to_s
    exit(1)
rescue Exception=>e
    puts "-ERROR: Unable to look up Vidispine item '#{vsid}'"
    puts e.message
    puts e.backtrace
    exit(1)
end

if($store.substitute_string(ENV['output_key']))
    keyname=$store.substitute_string(ENV['output_key'])
	readkey=$store.substitute_string(ENV['read_key'])
    new_value=item.get(readkey)

    $store.set('meta',keyname,new_value)
    
else
    puts "-WARNING: No <output_key> specified so not outputting metadata key to datastore."
end
