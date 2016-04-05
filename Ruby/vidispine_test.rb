#!/usr/bin/env ruby

$: << './lib' #add the pwd's lib subdir to module search path, to test dev versions

require './lib/Vidispine/VSApi'
require './lib/Vidispine/VSFieldCache'
require 'awesome_print'
require 'trollop'

opts = Trollop::options do
  opt :host, "Vidispine hostname", :type=>:string, :default=>"localhost"
  opt :port, "Vidispine port", :type=>:integer, :default=>8080
  opt :username, "Vidispine username", :type=>:string
  opt :password, "Vidispine password", :type=>:string
end

#START MAIN
$vs=VSApi.new(opts.host,opts.port,opts.username,opts.password)

#data=$vs.get_metadata("/item/VX-2565")

#ap data

fc=VSFieldCache.new(opts.host,opts.port,opts.username,opts.password)

fc.refresh

puts "---------------------------------------------\n\n"

#field_data=fc.lookupByPortalName("Category")
#ap field_data

#field_data=fc.lookupByPortalName("YouTube channel")
#ap field_data

field_data=fc.lookupByVSName("portal_mf662085")

fc.each do |field|
	ap field
end

puts "portal_mf662085 => #{field_data['portal_name']}"