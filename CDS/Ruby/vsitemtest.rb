#!/usr/bin/env ruby


$: << './lib' #add the pwd's lib subdir to module search path, to test dev versions

require './lib/Vidispine/VSApi'
require './lib/Vidispine/VSItem'
require 'awesome_print'
require 'trollop'

opts = Trollop::options do
  opt :host, "Vidispine hostname", :type=>:string, :default=>"localhost"
  opt :port, "Vidispine port", :type=>:integer, :default=>8080
  opt :username, "Vidispine username", :type=>:string
  opt :password, "Vidispine password", :type=>:string
end

item=VSItem.new(opts.host,opts.port,opts.username,opts.password)
item.populate(ARGV[0])

ap item.metadata

item.debug=1
args={"gnm_master_website_uploadlog"=>"test string"}
#don't need to specify the group as it is not stored that way on the item
item.setMetadata(args)  #,"gnm_master_website")
