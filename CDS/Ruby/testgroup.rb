#!/usr/bin/env ruby

require 'trollop'
$: << './lib'
require 'Vidispine/VSMetadataElements'


#START MAIN
opts = Trollop::options do
  opt :password, "Use this password to log into vidispine", :type=>:string
  opt :username, "Use this username to log into vidispine", :type=>:string
  opt :groupname, "Only select values from this group", :type=>:string
  opt :uuid, "Find value for this uuid", :type=>:string
end

globalmeta = VSMetadataElements.new('dc1-vidisapp-01.dc1.gnm.int',8080,opts.username,opts.password)

globalmeta.each {|grp|
  puts "Got group #{grp.name}"
  grp.each {|key,value|
    puts "\t#{key} => #{value}"
  }
}

if opts.groupname
  puts "Values for group #{opts.groupname}:"
  globalmeta.findName(opts.groupname) do |grp|
    puts "uuid is #{grp.uuid}"
    break
  end
  globalmeta.findName(opts.groupname) do |grp|
    puts "uuid is #{grp.uuid}"
    grp.each {|key,value|
      puts "\t#{key} => #{value}"
    }
    puts "\t\tName is #{grp['gnm_subgroup_displayname']}"
    puts "-----------------------------"
  end #globalmeta.findName
end

if opts.uuid
  puts "Values for uuid #{opts.uuid}:"
  globalmeta.findUUID(opts.uuid) do |grp|
    puts "name is #{grp.name}"
    grp.each {|key,value| puts "\t#{key} => #{value}" }
  end
end

#globalmeta.groups.each {|uuid,grp|
#  #puts "Got group id #{uuid}"
#  puts "Group #{grp.name} (#{grp.uuid}):"
#  grp.content.each {|k,v|
#    puts "\t#{k}=>#{v}\n"  
#  }
#}
