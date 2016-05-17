#!/usr/bin/env ruby

#This method will update metadata on a Vidispine item by either over-writing or appending/prepending values on a set of field(s)
#
#Arguments:
# <fields>field1|field2|{meta:key_for_field3} etc. - Names of fields to set. Note that these must be the _INTERNAL VIDISPINE FIELD NAME_, not the "display name" that you see in the Cantemo UI.  To find the field name, go to Manage Metadata, open the group, and find the field
# <values>value1|value2|{meta:key_for_value3} etc. - Values to set.  To set multiple fields, specify a list
# <host>vidispine.hostname - Contact this server
# <port>nnnn [OPTIONAL] - contact Vidispine on this port (defaults to 8080)
# <user>username [OPTIONAL] - contact Vidispine with this user name (defaults to admin)
# <passwd>password [OPTIONAL] - contact Vidispine with this password
# <item_id>{meta:itemId} [OPTIONAL] - set metadata for this Vidispine item (substitutions encouraged). Defaults to the value of the key {meta:itemId}.
# <prepend/> [OPTIONAL] - pre-pend the value as opposed to appending or over-writing
# <overwrite/> [OPTIONAL] - over-write the values of the fields as opposed to appending to them
# <groupname>name [OPTIONAL] - over-ride the metadata group name detected on the item to another value. Use with caution.
# <delimiter>c [OPTIONAL] - when appending to fields as a text string, use this character as a delimiter. Defaults to Newline.
# <multiple_values>c [OPTIONAL] - split the provided values data into multiple values on the given character. Allows multi-value keyword fields to be set.
# <retry_attempts>n [OPTIONAL] - number of times to retry setting metadata fields on Vidispine a item. Defaults to ten if not set. 
#END DOC

require 'CDS/Datastore'
require 'Vidispine/VSItem'
require 'Vidispine/VSApi'
require 'awesome_print'

#START MAIN
$store=Datastore.new('vidispine_notify')

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

unless(ENV['fields'])
    puts "-ERROR: You need to specify fields to set using the <fields> option in the routefile"
    exit(1)
end

unless(ENV['values'])
    puts "-ERROR: You need to specify values to set using the <values> option in the routefile"
end

begin
    hostname=$store.substitute_string(ENV['host'])
    
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

fieldnames=Array.new
values=Array.new
ENV['fields'].split('|').each do |f|
    fieldnames << $store.substitute_string(f)
end #ENV['fields'].split

ENV['values'].split('|').each do |v|
    values << $store.substitute_string(v).force_encoding('UTF-8')
end #ENV['values'].split

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

if($debug)
    puts "DEBUG: Item information:"
    ap item
end

delim="\n"
if(ENV['delimiter'])
    delim=$store.substitute_string(ENV['delimiter'])
end

mdhash=Hash.new
n=0

fieldnames.each do |f|
	if(ENV['multiple_values'])
		if(values[n].include?(ENV['multiple_values']))
			values[n]=values[n].split(ENV['multiple_values'])
		end
	end
    if(ENV['overwrite'])
        mdhash[f]=values[n]
    else
        existing_value=item.metadata[f]
        if(existing_value==nil)
            existing_value=""
        end
        if(delim==nil)
            delim=""
        end
        if(ENV['prepend'])
            mdhash[f]=values[n]+delim+existing_value
        else
            mdhash[f]=existing_value+delim+values[n]
        end
    end
    n+=1
end

puts "INFO: Values to set:"
ap mdhash
changeme=1
retrydelay=1
rattempts = 10

if(ENV['retry_attempts'])
    rattempts=$store.substitute_string(ENV['retry_attempts'])
end

begin
    if ENV['groupname']
        groupname = $store.substitute_string(ENV['groupname'])
        puts "DEBUG: setting into group name #{groupname}"
    else
        puts "DEBUG: setting with no group name"
        groupname = nil
    end

    item.setMetadata(mdhash, groupname: groupname)
rescue VSException=>e
    puts "-ERROR: Unable to set metadata fields on Vidispine item"
    puts e.to_s
    exit(1)
rescue StandardError=>e
    puts "-ERROR: Unable to set metadata fields on Vidispine item: #{e.message}"
    puts e.backtrace
    puts "-DEBUG: Retrying to set metadata fields on Vidispine item. Attempt: #{changeme}"
    changeme+=1
    sleep(retrydelay)
    retrydelay = retrydelay * 2
    retry if (rattempts <= changeme)
end

puts "+SUCCESS: Values set onto item #{vsid}"
