#!/usr/bin/env ruby

require './lib/Vidispine/VSField'
require 'awesome_print'
require 'trollop'

opts = Trollop::options do
  opt :host, "Vidispine hostname", :type=>:string, :default=>"localhost"
  opt :port, "Vidispine port", :type=>:integer, :default=>8080
  opt :username, "Vidispine username", :type=>:string
  opt :password, "Vidispine password", :type=>:string
end

f=VSField.new(opts.host,opts.port,opts.username,opts.password)

f.populate("gnm_master_website_previous_standfirst")
ap f

f.copyTo("temp_field")

